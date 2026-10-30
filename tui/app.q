--" # The event loop

A program is a value with two methods: `update` receives what happened (a key, a click, a resize, a
timer) and changes its state; `view` draws that state into a screen buffer. The `Runner` calls them, and
writes to the terminal only what changed since the last picture.

```
struct Counter
    public n: int
end

impl Program for Counter
    public fun update(self, ev: Event, ctx: Context)
        if ev.kind == "key" and ev.key == "+" then
            self.n += 1
        elseif ev.kind == "key" and ev.key == "q" then
            ctx.quit()
        end
    end

    public fun view(self, screen: Buffer, area: Rect) -> array<int>
        screen.put(2, 1, "count: {self.n}", Style.create())
        []                                  -- where to put the terminal cursor, or nothing
    end
end

run_in_terminal(Counter { n: 0 })           -- takes the terminal, gives it back at the end
```

The runner never talks to the terminal itself: it takes a function that gives the next event, one that
writes, and one that gives the time. In a terminal they are `Term.event`, `Term.frame` and `time.now`; in a
test they are scripted (see `testing.q`), so a whole screen can be driven and read without any terminal.

Events a program receives are those of `Term.event` (`"key"`, `"mouse"`, `"resize"`, `"paste"`, `"focus"`) and
`"timer"` (`ev.text` is the name given to `ctx.every` or `ctx.after`). `Ctrl+C` ends the program unless
`runner.keep_ctrl_c()` is called.
--"
import "buffer.q" as b
import "layout.q" as l
import "style.q" as st

--" Something to do again, or once, after a delay. --"
struct Timer
  public name: string
  public interval: int
  public due: int
  public repeat: bool
end

--" What a program can ask of the runner. --"
struct Context
  --" The size of the screen. --"
  public cols: int
  public rows: int
  public running: bool
  public timers: array<Timer>
  public clock: int
  public heading: string
end

impl Context
  --" Ends the program after this event. --"
  public fun quit(self)
    self.running = false
  end

  public fun is_running(self) -> bool
    self.running
  end

  --" The time of the event being handled, in milliseconds. --"
  public fun now(self) -> int
    self.clock
  end

  --" Delivers a `"timer"` event named `name` every `ms` milliseconds (replaces a timer of the same name). --"
  public fun every(self, name: string, ms: int)
    self.cancel(name)
    let interval = if ms < 1 then 1 else ms end
    self.timers.push(Timer { name: name, interval: interval, due: self.clock + interval, repeat: true })
  end

  --" Delivers a `"timer"` event named `name` once, after `ms` milliseconds. --"
  public fun after(self, name: string, ms: int)
    self.cancel(name)
    let delay = if ms < 0 then 0 else ms end
    self.timers.push(Timer { name: name, interval: delay, due: self.clock + delay, repeat: false })
  end

  --" Stops the timers called `name`. --"
  public fun cancel(self, name: string)
    let kept: array<Timer> = []
    for t in self.timers do
      if t.name != name then
        kept.push(t)
      end
    end
    self.timers = kept
  end

  --" The title of the window, written on the next picture. --"
  public fun title(self, text: string)
    self.heading = text
  end
end

--" What a TUI program is. --"
trait Program
  fun update(self, ev: Event, ctx: Context)
  fun view(self, screen: b.Buffer, area: l.Rect) -> array<int>
end

--" Runs a program: asks for events, calls it and draws what changed. --"
struct Runner
  ctx: Context
  previous: b.Buffer?
  depth: int
  longest_wait: int
  next: fun(int) -> Event
  out: fun(string) -> bool
  clock: fun() -> int
  ctrl_c: bool
  cursor: array<int>
  shown_title: string
  drawn: int
end

impl Runner
  --" A runner for a screen of `cols` by `rows`, with `depth` colours (`Term.colors()`). `next(wait_ms)` gives the
    next event (an event of kind `"timeout"` if nothing came in time), `out(text)` writes, `clock()` gives the time in
    milliseconds. --"
  public fun create(cols: int, rows: int, depth: int, next: fun(int) -> Event, out: fun(string) -> bool, clock: fun() -> int) -> Runner
    let ctx = Context { cols: cols, rows: rows, running: true, timers: [], clock: clock(), heading: "" }
    Runner { ctx: ctx, previous: none, depth: depth, longest_wait: 250, next: next, out: out, clock: clock, ctrl_c: true, cursor: [], shown_title: "", drawn: 0 }
  end

  --" `Ctrl+C` is given to the program instead of ending it. --"
  public fun keep_ctrl_c(self)
    self.ctrl_c = false
  end

  --" The longest wait for an event, in milliseconds (250 by default): how often timers are looked at. --"
  public fun max_wait(self, ms: int)
    self.longest_wait = if ms < 1 then 1 else ms end
  end

  public fun context(self) -> Context
    self.ctx
  end

  --" How many pictures were written. --"
  public fun frames(self) -> int
    self.drawn
  end

  --" The last picture, as plain lines (what a test reads). --"
  public fun lines(self) -> array<string>
    let last = self.previous
    if last == none then
      return []
    end
    last.lines()
  end

  --" The last picture. --"
  public fun screen(self) -> b.Buffer?
    self.previous
  end

  -- the picture of the program now, written as a difference from the last one
  fun draw(self, program: Program)
    let screen = b.Buffer.create(self.ctx.cols, self.ctx.rows)
    let cursor = program.view(screen, l.Rect.create(0, 0, self.ctx.cols, self.ctx.rows))
    let text = screen.diff(self.previous, self.depth)
    if self.ctx.heading != self.shown_title then
      text = "\e]0;" + self.ctx.heading + "\e\\" + text
      self.shown_title = self.ctx.heading
    end
    if cursor != self.cursor or text != "" then
      if cursor.len() == 2 then
        text += "\e[{cursor[1] + 1};{cursor[0] + 1}H\e[?25h"
      else
        text += "\e[?25l"
      end
      self.cursor = cursor
    end
    if text != "" then
      self.out(text)
      self.drawn += 1
    end
    self.previous = screen
  end

  --" Draws the first picture. --"
  public fun start(self, program: Program)
    self.ctx.clock = self.clock()
    self.draw(program)
  end

  -- how long to wait for the next event
  fun wait(self) -> int
    let now = self.clock()
    let wait = self.longest_wait
    for t in self.ctx.timers do
      let left = t.due - now
      if left < wait then
        wait = left
      end
    end
    if wait < 0 then 0 else wait end
  end

  fun fire_timers(self, program: Program)
    let now = self.ctx.clock
    let due: array<Timer> = []
    for t in self.ctx.timers do
      if t.due <= now then
        due.push(t)
      end
    end
    for t in due do
      if t.repeat then
        t.due = now + t.interval
      else
        self.ctx.cancel(t.name)
      end
      if self.ctx.running then
        program.update(Event { kind: "timer", text: t.name }, self.ctx)
      end
    end
  end

  --" Handles one event (and the timers that are due) and draws the result. A `"timeout"` event only lets the
    timers run. --"
  public fun feed(self, program: Program, ev: Event)
    self.ctx.clock = self.clock()
    if ev.kind == "resize" then
      self.ctx.cols = ev.x
      self.ctx.rows = ev.y
      self.previous = none
    end
    if ev.kind == "key" and ev.key == "c" and ev.ctrl and self.ctrl_c then
      self.ctx.quit()
      return
    end
    if ev.kind != "timeout" then
      program.update(ev, self.ctx)
    end
    self.fire_timers(program)
    if self.ctx.running then
      self.draw(program)
    end
  end

  --" Runs until the program calls `ctx.quit()` or `Ctrl+C` is pressed. --"
  public fun run(self, program: Program)
    self.start(program)
    while self.ctx.running do
      let ev = self.next(self.wait())
      self.feed(program, ev)
    end
  end
end

--" Runs the program in the terminal: raw mode, the alternate screen, the mouse and pastes reported, and
everything put back at the end. `Err` if the input or the output is not a terminal. --"
fun run_in_terminal(program: Program) -> Result<bool, Error>
  run_in_terminal_with(program, fun(ctx: Context) -> bool true end)
end

--" Like `run_in_terminal`, after calling `setup` with the context (to start timers before the first event). --"
fun run_in_terminal_with(program: Program, setup: fun(Context) -> bool) -> Result<bool, Error>
  let size = Term.size()
  let next = fun(wait: int) -> Event
    let got = Term.event(wait)
    if got.is_err() then
      return Event { kind: "key", key: "c", ctrl: true }
    end
    got.unwrap()
  end
  let out = fun(text: string) -> bool
    Term.write(text).is_ok()
  end
  let runner = Runner.create(size.cols, size.rows, Term.colors(), next, out, fun() -> int time.now() end)
  let ran = Term.session(fun() -> bool
    Term.mouse(true)
    Term.paste(true)
    setup(runner.context())
    runner.run(program)
    true
  end)
  if ran.is_err() then
    return Result<bool, Error>.Err(ran.unwrap_err())
  end
  Result<bool, Error>.Ok(true)
end

export Context, Program, Runner, run_in_terminal, run_in_terminal_with
