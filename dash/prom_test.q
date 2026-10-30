import "prom.q" as p

fun text() -> string
  "# HELP http_requests_total Requests\n# TYPE http_requests_total counter\nhttp_requests_total\{method=\"GET\",route=\"/\",status=\"2xx\"} 90\nhttp_requests_total\{method=\"GET\",route=\"/\",status=\"5xx\"} 10\nhttp_requests_total\{method=\"GET\",route=\"/users/:id\",status=\"2xx\"} 400\nhttp_request_duration_ms_bucket\{route=\"/\",le=\"10\"} 50\nhttp_request_duration_ms_bucket\{route=\"/\",le=\"50\"} 95\nhttp_request_duration_ms_bucket\{route=\"/\",le=\"+Inf\"} 100\nhttp_request_duration_ms_count\{route=\"/\"} 100\nqueue_jobs_pending 7\nbroken line\n"
end

fun test_lines_are_read_with_their_labels_and_comments_are_skipped()
  let samples = p.parse(text())
  assert_eq(samples.len(), 8)
  assert_eq(samples[0].name, "http_requests_total")
  assert_eq(samples[0].labels["route"], "/")
  assert_eq(samples[0].labels["status"], "2xx")
  assert_eq(samples[0].value, 90.0)
end

fun test_routes_are_summed_and_the_busiest_comes_first()
  let stats = p.route_stats(p.parse(text()))
  assert_eq(stats.len(), 2)
  assert_eq(stats[0].route, "/users/:id")
  assert_eq(stats[0].requests, 400)
  assert_eq(stats[1].requests, 100)
  assert_eq(stats[1].errors, 10)
end

fun test_the_quantiles_come_from_the_buckets()
  let stats = p.route_stats(p.parse(text()))
  assert_eq(stats[1].p50, 10.0)
  assert_eq(stats[1].p95, 50.0)
  assert_eq(stats[0].p95, 0.0)
end

fun test_a_gauge_without_labels_is_found()
  let samples = p.parse(text())
  assert_eq(p.gauge(samples, "queue_jobs_pending"), 7.0)
  assert_eq(p.gauge(samples, "missing"), 0.0)
end

fun test_empty_text_gives_nothing()
  assert_eq(p.parse("").len(), 0)
  assert_eq(p.route_stats([]).len(), 0)
end
