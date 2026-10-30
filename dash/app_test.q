import "../tui/testing.q" as t
import "app.q" as d

fun metrics() -> string
  "http_requests_total\{route=\"/\",status=\"2xx\"} 90\nhttp_requests_total\{route=\"/\",status=\"5xx\"} 10\nhttp_requests_total\{route=\"/users\",status=\"2xx\"} 400\nhttp_request_duration_ms_bucket\{route=\"/\",le=\"10\"} 50\nhttp_request_duration_ms_bucket\{route=\"/\",le=\"50\"} 95\nhttp_request_duration_ms_bucket\{route=\"/\",le=\"+Inf\"} 100\nhttp_request_duration_ms_count\{route=\"/\"} 100\nqueue_jobs_pending 3\n"
end

fun spec() -> string
  "\{\"paths\":\{\"/users\":\{\"get\":\{\"summary\":\"List users\"},\"post\":\{\"summary\":\"Create user\"}},\"/\":\{\"get\":\{\"summary\":\"Home\"}}}}"
end

fun log() -> string
  "\{\"time\":\"2026-10-30T10:00:01Z\",\"level\":\"info\",\"message\":\"started\"}\n\{\"time\":\"2026-10-30T10:00:02Z\",\"level\":\"warn\",\"message\":\"N+1? GET /users ran the same statement 12 times\"}\n\{\"time\":\"2026-10-30T10:00:03Z\",\"level\":\"error\",\"message\":\"boom in /\"}\n"
end

fun sources(up: bool) -> d.Sources
  let get = fun(path: string) -> Result<string, Error>
    if not up then
      return Result<string, Error>.Err(Error { message: "connection refused" })
    end
    if path == "/health" then
      return Result<string, Error>.Ok("ok")
    end
    if path == "/metrics" then
      return Result<string, Error>.Ok(metrics())
    end
    if path == "/openapi.json" then
      return Result<string, Error>.Ok(spec())
    end
    Result<string, Error>.Err(Error { message: "{path} answered 404" })
  end
  d.Sources { get: get, log: fun() -> string log() end }
end

fun start(up: bool) -> t.Harness
  t.Harness.start(100, 30, d.create(sources(up)))
end

fun test_the_overview_shows_health_totals_busiest_routes_and_errors()
  let app = start(true)
  assert(app.contains("app is up"))
  assert(app.contains("requests 500   errors 10   jobs pending 3"))
  assert(app.contains("/users"))
  assert(app.contains("boom in /"))
end

fun test_a_down_app_is_reported_and_the_log_still_shows()
  let app = start(false)
  assert(app.contains("app is down"))
  assert(app.contains("! health: connection refused"))
  assert(app.contains("boom in /"))
end

fun test_the_routes_tab_lists_the_operations_and_filters()
  let app = start(true)
  app.key("Right")
  assert(app.contains("GET     /users"))
  assert(app.contains("Create user"))
  app.key("/")
  app.text("create")
  app.key("Enter")
  assert(app.contains("Create user"))
  assert(not app.contains("List users"))
end

fun test_the_requests_tab_shows_counts_and_quantiles()
  let app = start(true)
  app.key("3")
  assert(app.contains("Requests"))
  assert(app.contains("400"))
  assert(app.contains("50"))
end

fun test_the_logs_tab_filters_by_level_and_opens_a_line()
  let app = start(true)
  app.key("4")
  assert(app.contains("started"))
  app.key("l")
  app.key("l")
  assert(not app.contains("started"))
  assert(app.contains("N+1?"))
  app.key("Enter")
  assert(app.contains("Log line"))
  app.key("Enter")
  assert(not app.contains("Log line"))
end

fun test_the_queries_tab_has_the_n_plus_one_warnings()
  let app = start(true)
  app.key("5")
  assert(app.contains("N+1 warnings"))
  assert(app.contains("ran the same statement 12 times"))
  assert(not app.contains("boom"))
end

fun test_it_refreshes_every_two_seconds_when_a_timer_is_set()
  let app = start(true)
  app.context().every("refresh", 2000)
  app.advance(2000)
  assert(app.contains("app is up"))
end

fun test_q_quits()
  let app = start(true)
  app.key("q")
  assert(app.finished())
end
