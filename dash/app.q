--" # The dashboard of a running app

A terminal screen that shows an app while it runs: its health, its routes, how busy and how slow each route
is, and its log. It reads what the app already serves (`/health`, `/metrics`, `/openapi.json` of `qlang-std`)
and the log file written with `qlang serve --log-format json`, so the app needs nothing more than those routes.

| Tab | Shows |
| --- | --- |
| Overview | health, totals, the busiest routes, the latest errors |
| Routes | method, path and summary of every operation (`/` filters) |
| Requests | per route: requests, errors, p50 and p95 in ms (sorted by the busiest) |
| Logs | the log, newest last (`l` changes the level, `/` filters, `Enter` opens a line) |
| Queries | the `N+1?` warnings of `--dev` |

Keys: `←` `→` change tab, `↑` `↓` move, `r` refreshes (it also does every 2 seconds), `q` quits.
--"
import "../tui/app.q" as ap
import "../tui/block.q" as bk
import "../tui/buffer.q" as b
import "../tui/help.q" as hp
import "../tui/input.q" as inp
import "../tui/layout.q" as l
import "../tui/list.q" as li
import "../tui/modal.q" as md
import "../tui/style.q" as st
import "../tui/table.q" as tb
import "../tui/tabs.q" as ts
import "../tui/text.q" as tx
import "logs.q" as lg
import "prom.q" as pm
import "routes.q" as rt

--" Where the data comes from: `get(path)` fetches a page of the app, `log()` gives the text of its log. --"
struct Sources
  public get: fun(string) -> Result<string, Error>
  public log: fun() -> string
end

--" Sources for an app at `base` (`http://localhost:8000`) and a log file (`""` for none). --"
fun live_sources(base: string, log_file: string) -> Sources
  let get = fun(path: string) -> Result<string, Error>
    let sent = http.send(Request { method: "GET", url: base + path })
    if sent.is_err() then
      return Result<string, Error>.Err(sent.unwrap_err())
    end
    let res = sent.unwrap()
    if res.status != 200 then
      return Result<string, Error>.Err(Error { message: "{path} answered {res.status}" })
    end
    Result<string, Error>.Ok(res.body)
  end
  let log = fun() -> string
    if log_file == "" then
      return ""
    end
    let read = fs.read(log_file)
    if read.is_err() then
      return ""
    end
    -- the end of a big file is what matters
    let lines = read.unwrap().split("\n")
    let from_line = if lines.len() > 2000 then lines.len() - 2000 else 0 end
    lines.slice(from_line, lines.len()).join("\n")
  end
  Sources { get: get, log: log }
end

--" The state of the dashboard. --"
struct Dashboard
  public sources: Sources
  public tabs: ts.Tabs
  public health: string
  public samples: array<pm.Sample>
  public routes: array<rt.Route>
  public entries: array<lg.Entry>
  public problems: array<string>
  public route_table: tb.Table
  public request_table: tb.Table
  public logs: li.List
  public queries: li.List
  public search: inp.TextInput
  public searching: bool
  public level: string
  public detail: md.Dialog
  public detail_shown: bool
  public refreshed: int
end

fun create(sources: Sources) -> Dashboard
  let d = Dashboard {
    sources: sources,
    tabs: ts.Tabs.create(["Overview", "Routes", "Requests", "Logs", "Queries"]),
    health: "?",
    samples: [],
    routes: [],
    entries: [],
    problems: [],
    route_table: tb.Table.create([tb.Column.create("Method", l.Size.fixed(7)), tb.Column.create("Path", l.Size.fill(2)), tb.Column.create("Summary", l.Size.fill(3))]),
    request_table: tb.Table.create([tb.Column.create("Route", l.Size.fill(1)), tb.Column.create("Requests", l.Size.fixed(9)).align("right"), tb.Column.create("Errors", l.Size.fixed(7)).align("right"), tb.Column.create("p50 ms", l.Size.fixed(8)).align("right"), tb.Column.create("p95 ms", l.Size.fixed(8)).align("right")]),
    logs: li.List.create([]),
    queries: li.List.create([]),
    search: inp.TextInput.create("filter"),
    searching: false,
    level: "",
    detail: md.Dialog.notice("Log line", ""),
    detail_shown: false,
    refreshed: 0,
  }
  refresh(d)
  d
end

fun line_of(e: lg.Entry) -> string
  let time = if e.time.len() >= 19 then e.time.substring(11, 19) else e.time end
  tx.fit(time, 8, "left") + " " + tx.fit(e.level.upper(), 5, "left") + " " + e.message
end

--" Reads everything again from the sources and rebuilds the tables and lists. A source that fails is
reported in `problems`; the others still show. --"
fun refresh(d: Dashboard)
  let problems: array<string> = []
  let health = d.sources.get("/health")
  d.health = if health.is_ok() then "up" else "down" end
  if health.is_err() then
    problems.push("health: " + health.unwrap_err().message)
  end
  let metrics = d.sources.get("/metrics")
  if metrics.is_ok() then
    d.samples = pm.parse(metrics.unwrap())
  else
    problems.push("metrics: " + metrics.unwrap_err().message)
  end
  let spec = d.sources.get("/openapi.json")
  if spec.is_ok() then
    let parsed = rt.parse(spec.unwrap())
    if parsed.is_ok() then
      d.routes = parsed.unwrap()
    else
      problems.push("routes: " + parsed.unwrap_err().message)
    end
  else
    problems.push("routes: " + spec.unwrap_err().message)
  end
  d.entries = lg.parse_all(d.sources.log())
  d.problems = problems
  rebuild(d)
end

--" Applies the filter and the level to the tables and lists. --"
fun rebuild(d: Dashboard)
  let needle = d.search.value.lower()
  let rows: array<array<string>> = []
  for r in d.routes do
    if needle == "" or (r.method + " " + r.path + " " + r.summary).lower().contains(needle) then
      rows.push([r.method, r.path, r.summary])
    end
  end
  d.route_table.set_rows(rows)
  let stats: array<array<string>> = []
  for s in pm.route_stats(d.samples) do
    stats.push([s.route, "{s.requests}", "{s.errors}", Format.number(s.p50, 0), Format.number(s.p95, 0)])
  end
  d.request_table.set_rows(stats)
  let shown = lg.filter(d.entries, d.level, needle)
  let before = d.logs.len()
  let was_last = d.logs.selected >= before - 1
  d.logs.set_items(shown.map(fun(e: lg.Entry) -> string line_of(e) end))
  if was_last then
    d.logs.move_to(shown.len() - 1)
  end
  d.queries.set_items(d.entries.filter(fun(e: lg.Entry) -> bool lg.is_n_plus_one(e) end).map(fun(e: lg.Entry) -> string line_of(e) end))
end

fun next_level(level: string) -> string
  if level == "" then
    "info"
  elseif level == "info" then
    "warn"
  elseif level == "warn" then
    "error"
  else
    ""
  end
end

fun total_requests(d: Dashboard) -> int
  let n = 0
  for s in pm.route_stats(d.samples) do
    n += s.requests
  end
  n
end

fun total_errors(d: Dashboard) -> int
  let n = 0
  for s in pm.route_stats(d.samples) do
    n += s.errors
  end
  n
end

fun draw_overview(d: Dashboard, screen: b.Buffer, area: l.Rect)
  let inside = bk.Block.create().rounded().title("Overview").render(screen, area)
  let ok = d.health == "up"
  let dot = st.Style.create().fg(st.Color.ansi(if ok then 2 else 1 end)).bold()
  screen.put(inside.x + 1, inside.y, "●", dot)
  screen.put(inside.x + 3, inside.y, "app is " + d.health, st.Style.create().bold())
  let requests = total_requests(d)
  let errors = total_errors(d)
  screen.put(inside.x + 1, inside.y + 2, "requests {requests}   errors {errors}   jobs pending " + Format.number(pm.gauge(d.samples, "queue_jobs_pending"), 0) + "   failed " + Format.number(pm.gauge(d.samples, "queue_jobs_failed"), 0), st.Style.create())
  screen.put(inside.x + 1, inside.y + 4, "Busiest routes", st.Style.create().bold().underline())
  let stats = pm.route_stats(d.samples)
  for i in 0..stats.len() do
    if i >= 5 then
      break
    end
    screen.put(inside.x + 1, inside.y + 5 + i, tx.fit(stats[i].route, 30, "left") + " {stats[i].requests} req, p95 " + Format.number(stats[i].p95, 0) + " ms", st.Style.create())
  end
  screen.put(inside.x + 1, inside.y + 11, "Latest errors", st.Style.create().bold().underline())
  let shown = 0
  let at = d.entries.len() - 1
  while at >= 0 and shown < 5 do
    let e = d.entries[at]
    if lg.level_rank(e.level) >= 3 then
      screen.put(inside.x + 1, inside.y + 12 + shown, tx.truncate(line_of(e), inside.w - 2), st.Style.create().fg(st.Color.ansi(1)))
      shown += 1
    end
    at -= 1
  end
  let row = inside.y + 18
  for p in d.problems do
    if row < inside.bottom() then
      screen.put(inside.x + 1, row, tx.truncate("! " + p, inside.w - 2), st.Style.create().fg(st.Color.ansi(3)))
      row += 1
    end
  end
end

impl ap.Program for Dashboard
  public fun update(self, ev: Event, ctx: ap.Context)
    if ev.kind == "timer" then
      refresh(self)
      return
    end
    if self.detail_shown then
      self.detail.handle(ev)
      if not self.detail.is_open() then
        self.detail_shown = false
      end
      return
    end
    if self.searching then
      if ev.kind == "key" and (ev.key == "Enter" or ev.key == "Esc") then
        if ev.key == "Esc" then
          self.search.clear()
          rebuild(self)
        end
        self.searching = false
        return
      end
      if self.search.handle(ev) then
        rebuild(self)
      end
      return
    end
    if ev.kind == "key" and not ev.ctrl and not ev.alt then
      if ev.key == "q" then
        ctx.quit()
        return
      end
      if ev.key == "r" then
        refresh(self)
        return
      end
      if ev.key == "/" then
        self.searching = true
        return
      end
      if ev.key == "l" then
        self.level = next_level(self.level)
        rebuild(self)
        return
      end
      if ev.key == "Esc" and self.search.value != "" then
        self.search.clear()
        rebuild(self)
        return
      end
      if ev.key == "Enter" and self.tabs.active_title() == "Logs" then
        let line = self.logs.selected_item()
        if line != none then
          self.detail = md.Dialog.notice("Log line", line)
          self.detail_shown = true
        end
        return
      end
    end
    if self.tabs.handle(ev) then
      return
    end
    let tab = self.tabs.active_title()
    if tab == "Routes" then
      self.route_table.handle(ev)
    elseif tab == "Requests" then
      self.request_table.handle(ev)
    elseif tab == "Logs" then
      self.logs.handle(ev)
    elseif tab == "Queries" then
      self.queries.handle(ev)
    end
  end

  public fun view(self, screen: b.Buffer, area: l.Rect) -> array<int>
    let rows = area.split_column([l.Size.fixed(1), l.Size.fill(1), l.Size.fixed(1)], 0)
    self.tabs.render(screen, rows[0])
    let tab = self.tabs.active_title()
    let cursor: array<int> = []
    let body = rows[1]
    if tab == "Routes" or tab == "Logs" then
      let parts = body.split_column([l.Size.fixed(3), l.Size.fill(1)], 0)
      let title = if tab == "Logs" and self.level != "" then "Filter (level " + self.level + ")" else "Filter (/)" end
      let box = bk.Block.create().rounded().title(title).render(screen, parts[0])
      let at = self.search.render(screen, box, self.searching)
      if at.len() == 2 then
        cursor.push(at[0])
        cursor.push(at[1])
      end
      body = parts[1]
    end
    if tab == "Overview" then
      draw_overview(self, screen, body)
    elseif tab == "Routes" then
      self.route_table.render(screen, bk.Block.create().rounded().title("Routes").render(screen, body), not self.searching)
    elseif tab == "Requests" then
      self.request_table.render(screen, bk.Block.create().rounded().title("Requests").render(screen, body), true)
    elseif tab == "Logs" then
      self.logs.render(screen, bk.Block.create().rounded().title("Logs").render(screen, body), not self.searching)
    else
      self.queries.render(screen, bk.Block.create().rounded().title("N+1 warnings").render(screen, body), true)
    end
    let hints = if self.searching then [["enter", "apply"], ["esc", "clear"]] else [["←→", "tab"], ["↑↓", "move"], ["/", "filter"], ["l", "level"], ["r", "refresh"], ["q", "quit"]] end
    hp.HelpBar.create(hints).render(screen, rows[2])
    if self.detail_shown then
      self.detail.render(screen, area)
      return []
    end
    cursor
  end

end

--" Runs the dashboard in the terminal for an app at `base`, reading `log_file` (`""` for none). --"
fun run(base: string, log_file: string) -> Result<bool, Error>
  let dashboard = create(live_sources(base, log_file))
  ap.run_in_terminal_with(dashboard, fun(ctx: ap.Context) -> bool
    ctx.every("refresh", 2000)
    true
  end)
end

export Sources, Dashboard, create, refresh, live_sources, run
