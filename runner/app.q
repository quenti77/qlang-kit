--" # The test runner

`kit test` runs `qlang test` and shows the result as a screen: every test with its verdict, and for a failure the
message and the source around the line where it happened. It **watches** the `.q` files of the project and runs
again when one changes.

| Key | Does |
| --- | --- |
| `r` | runs all the tests again |
| `Enter` | runs the selected test only |
| `w` | watching on / off |
| `f` | only the failures / all |
| `↑` `↓` | moves in the list, `PageUp` `PageDown` scroll the failure |
| `q` | quits |

It starts `qlang`, which a program may only do with permission: `qlang run --allow-process main.q -- test`.
--"
import "../tui/app.q" as ap
import "../tui/block.q" as bk
import "../tui/buffer.q" as b
import "../tui/help.q" as hp
import "../tui/layout.q" as l
import "../tui/list.q" as li
import "../tui/style.q" as st
import "../tui/text.q" as tx
import "parse.q" as ps

--" Where things come from: the files to watch, how to read one, how to run `qlang test`, the time. --"
struct Source
  public files: fun() -> array<string>
  public read: fun(string) -> Result<string, Error>
  public exec: fun(array<string>) -> Result<string, Error>
  public clock: fun() -> int
end

--" The project on disk and the `qlang` command. --"
fun live_source() -> Source
  let files = fun() -> array<string>
    let found = fs.glob("**/*.q")
    if found.is_err() then
      return []
    end
    found.unwrap().filter(fun(p: string) -> bool not p.starts_with(".qlang/") and not p.starts_with("target/") end)
  end
  let read = fun(path: string) -> Result<string, Error>
    fs.read(path)
  end
  let exec = fun(args: array<string>) -> Result<string, Error>
    let ran = Process.run("qlang", args)
    if ran.is_err() then
      return Result<string, Error>.Err(ran.unwrap_err())
    end
    Result<string, Error>.Ok(ran.unwrap().stdout + "\n" + ran.unwrap().stderr)
  end
  Source { files: files, read: read, exec: exec, clock: fun() -> int time.now() end }
end

--" The state of the runner. --"
struct TestRunner
  public src: Source
  public report: ps.Report
  public cases: li.List
  public shown: array<ps.Case>
  public only_failures: bool
  public watching: bool
  public running: bool
  public args: array<string>
  public snapshot: map<string, string>
  public took: int
  public runs: int
  public scroll: int
  public message: string
end

fun create(src: Source) -> TestRunner
  TestRunner {
    src: src,
    report: ps.Report { cases: [], passed: 0, failed: 0, other: [] },
    cases: li.List.create([]),
    shown: [],
    only_failures: false,
    watching: true,
    running: true,
    args: ["test"],
    snapshot: {},
    took: 0,
    runs: 0,
    scroll: 0,
    message: "",
  }
end

fun take_snapshot(r: TestRunner) -> map<string, string>
  let out: map<string, string> = {}
  for path in r.src.files() do
    let read = r.src.read(path)
    if read.is_ok() then
      out[path] = read.unwrap()
    end
  end
  out
end

fun changed(a: map<string, string>, b: map<string, string>) -> bool
  if a.len() != b.len() then
    return true
  end
  for key in a.keys() do
    if a[key] != b[key] then
      return true
    end
  end
  false
end

fun mark(c: ps.Case) -> string
  (if c.ok then "✓ " else "✗ " end) + c.file + (if c.name == "" then "" else "::" + c.name end)
end

--" Rebuilds the list from the report (and the failures-only switch). --"
fun refresh_list(r: TestRunner)
  r.shown = r.report.cases.filter(fun(c: ps.Case) -> bool not r.only_failures or not c.ok end)
  r.cases.set_items(r.shown.map(fun(c: ps.Case) -> string mark(c) end))
  r.scroll = 0
end

fun count_of(cases: array<ps.Case>, ok: bool) -> int
  cases.filter(fun(c: ps.Case) -> bool c.ok == ok end).len()
end

--" Runs `qlang test` with `args` and keeps the result. A run of one test replaces that test in the report. --"
fun run_tests(r: TestRunner)
  let started = r.src.clock()
  let out = r.src.exec(r.args)
  r.took = r.src.clock() - started
  r.running = false
  r.runs += 1
  if out.is_err() then
    r.message = "could not run qlang: " + out.unwrap_err().message
    return
  end
  r.message = ""
  let fresh = ps.parse(out.unwrap())
  if r.args.len() > 1 and fresh.cases.len() > 0 then
    -- one test again: it takes the place of the old one
    let merged: array<ps.Case> = []
    for old in r.report.cases do
      let replaced = false
      for c in fresh.cases do
        if c.file == old.file and c.name == old.name then
          merged.push(c)
          replaced = true
        end
      end
      if not replaced then
        merged.push(old)
      end
    end
    r.report = ps.Report { cases: merged, passed: count_of(merged, true), failed: count_of(merged, false), other: fresh.other }
  else
    r.report = fresh
  end
  r.snapshot = take_snapshot(r)
  refresh_list(r)
end

fun selected(r: TestRunner) -> ps.Case?
  if r.shown.is_empty() then
    return none
  end
  r.shown[r.cases.selected]
end

-- the lines around `line` of a file, numbered, with an arrow on the one that failed
fun excerpt(r: TestRunner, path: string, line: int) -> array<string>
  let read = r.src.read(path)
  if read.is_err() or line < 1 then
    return []
  end
  let lines = read.unwrap().split("\n")
  let out: array<string> = []
  let first = if line - 3 < 1 then 1 else line - 3 end
  let last = if line + 3 > lines.len() then lines.len() else line + 3 end
  for n in first..(last + 1) do
    out.push((if n == line then "> " else "  " end) + tx.fit("{n}", 4, "right") + " | " + lines[n - 1])
  end
  out
end

impl ap.Program for TestRunner
  public fun update(self, ev: Event, ctx: ap.Context)
    if ev.kind == "timer" then
      if ev.text == "go" then
        run_tests(self)
      elseif ev.text == "poll" and self.watching and not self.running then
        if changed(self.snapshot, take_snapshot(self)) then
          self.args = ["test"]
          self.running = true
          ctx.after("go", 10)
        end
      end
      return
    end
    if ev.kind != "key" or ev.ctrl or ev.alt then
      self.cases.handle(ev)
      return
    end
    if ev.key == "q" then
      ctx.quit()
    elseif ev.key == "r" and not self.running then
      self.args = ["test"]
      self.running = true
      ctx.after("go", 10)
    elseif ev.key == "Enter" and not self.running then
      let c = selected(self)
      if c != none and c.name != "" then
        self.args = ["test", c.file, "--filter", c.name]
        self.running = true
        ctx.after("go", 10)
      end
    elseif ev.key == "w" then
      self.watching = not self.watching
    elseif ev.key == "f" then
      self.only_failures = not self.only_failures
      refresh_list(self)
    elseif ev.key == "PageDown" then
      self.scroll += 8
    elseif ev.key == "PageUp" then
      self.scroll = if self.scroll > 8 then self.scroll - 8 else 0 end
    else
      let before = self.cases.selected
      self.cases.handle(ev)
      if self.cases.selected != before then
        self.scroll = 0
      end
    end
  end

  public fun view(self, screen: b.Buffer, area: l.Rect) -> array<int>
    let rows = area.split_column([l.Size.fixed(1), l.Size.fill(1), l.Size.fixed(1)], 0)
    let green = st.Style.create().fg(st.Color.ansi(2)).bold()
    let red = st.Style.create().fg(st.Color.ansi(1)).bold()
    let x = rows[0].x + 1
    if self.running then
      screen.put(x, rows[0].y, "running...", st.Style.create().fg(st.Color.ansi(3)).bold())
      x += 12
    end
    let passed = "✓ {self.report.passed} passed"
    screen.put(x, rows[0].y, passed, green)
    let failed = "✗ {self.report.failed} failed"
    screen.put(x + passed.chars().len() + 2, rows[0].y, failed, if self.report.failed > 0 then red else st.Style.create().dim() end)
    let tail = (if self.watching then "watching" else "not watching" end) + " · {self.took} ms · run {self.runs}"
    screen.put(rows[0].right() - tail.chars().len() - 1, rows[0].y, tail, st.Style.create().dim())
    let cols = rows[1].split_row([l.Size.fill(2), l.Size.fill(3)], 0)
    self.cases.render(screen, bk.Block.create().rounded().title(if self.only_failures then "Failures" else "Tests" end).render(screen, cols[0]), true)
    let pane = bk.Block.create().rounded().title("Details").render(screen, cols[1])
    let lines: array<string> = []
    let c = selected(self)
    if self.message != "" then
      lines.push(self.message)
    elseif c == none then
      for line in self.report.other do
        lines.push(line)
      end
      if lines.is_empty() then
        lines.push("no tests yet")
      end
    elseif c != none then
      if c.ok then
        lines.push("passed")
      else
        for line in c.detail do
          lines.push(line)
        end
        if c.at_file != "" then
          lines.push("")
          lines.push(c.at_file + ":{c.at_line}")
          for line in excerpt(self, c.at_file, c.at_line) do
            lines.push(line)
          end
        end
      end
    end
    let start = if self.scroll > lines.len() - 1 then lines.len() - 1 else self.scroll end
    for i in 0..pane.h do
      let n = start + i
      if n >= lines.len() then
        break
      end
      let style = if lines[n].starts_with("> ") then red else st.Style.create() end
      screen.put(pane.x, pane.y + i, tx.truncate(lines[n], pane.w), style)
    end
    hp.HelpBar.create([["r", "run all"], ["enter", "run this"], ["w", "watch"], ["f", "failures"], ["q", "quit"]]).render(screen, rows[2])
    []
  end
end

--" Runs the test runner in the terminal on the current project. --"
fun run() -> Result<bool, Error>
  let runner = create(live_source())
  ap.run_in_terminal_with(runner, fun(ctx: ap.Context) -> bool
    ctx.after("go", 10)
    ctx.every("poll", 1000)
    true
  end)
end

export Source, TestRunner, create, live_source, run
