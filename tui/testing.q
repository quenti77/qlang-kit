--" # Testing a TUI program

A `Harness` runs a program with no terminal: you send it keys, clicks, resizes and the passing of time, and
read the screen as plain lines. The same `Runner` drives it as in a terminal, so what a test sees is what the
terminal would show.

```
let app = Harness.start(80, 24, MyProgram.create())
app.key("Down")
app.text("hello")                       -- one key for each character
app.click(10, 3)
app.advance(1000)                       -- a second goes by: timers fire
assert(app.contains("hello"))
assert_eq(app.line(0), "Routes")
```
--"
import "app.q" as ap
import "buffer.q" as b

--" The time of a test: it only moves when the test says so. --"
struct Clock
  public ms: int
end

--" A program running in memory. --"
struct Harness
  program: ap.Program
  runner: ap.Runner
  clock: Clock
  written: array<string>
end

impl Harness
  --" Starts the program on a screen of `cols` by `rows` (16 colours) and draws the first picture. --"
  public fun start(cols: int, rows: int, program: ap.Program) -> Harness
    let clock = Clock { ms: 0 }
    let written: array<string> = []
    let next = fun(wait: int) -> Event
      Event { kind: "timeout" }
    end
    let out = fun(text: string) -> bool
      written.push(text)
      true
    end
    let runner = ap.Runner.create(cols, rows, 16, next, out, fun() -> int clock.ms end)
    runner.start(program)
    Harness { program: program, runner: runner, clock: clock, written: written }
  end

  --" Sends any event. --"
  public fun send(self, ev: Event)
    self.runner.feed(self.program, ev)
  end

  --" Presses a key by its name (`"a"`, `"Enter"`, `"Down"`, `"F5"`). --"
  public fun key(self, name: string)
    self.send(Event { kind: "key", key: name })
  end

  --" Presses a key with Ctrl. --"
  public fun ctrl(self, name: string)
    self.send(Event { kind: "key", key: name, ctrl: true })
  end

  --" Presses a key with Shift. --"
  public fun shift(self, name: string)
    self.send(Event { kind: "key", key: name, shift: true })
  end

  --" Types a text: one key for each character. --"
  public fun text(self, text: string)
    for ch in text.chars() do
      self.key(ch)
    end
  end

  --" Pastes a text. --"
  public fun paste(self, text: string)
    self.send(Event { kind: "paste", text: text })
  end

  --" A left click at a column and a row. --"
  public fun click(self, x: int, y: int)
    self.send(Event { kind: "mouse", action: "down", button: "left", x: x, y: y })
  end

  --" A turn of the wheel at a column and a row (`up` or not). --"
  public fun wheel(self, x: int, y: int, up: bool)
    self.send(Event { kind: "mouse", action: if up then "scroll_up" else "scroll_down" end, x: x, y: y })
  end

  --" The terminal is resized. --"
  public fun resize(self, cols: int, rows: int)
    self.send(Event { kind: "resize", x: cols, y: rows })
  end

  --" `ms` milliseconds go by: the timers that are due fire. --"
  public fun advance(self, ms: int)
    self.clock.ms += ms
    self.send(Event { kind: "timeout" })
  end

  --" The screen as plain lines (trailing spaces cut). --"
  public fun lines(self) -> array<string>
    self.runner.lines()
  end

  --" One line of the screen (`""` outside). --"
  public fun line(self, row: int) -> string
    let all = self.lines()
    if row < 0 or row >= all.len() then
      return ""
    end
    all[row]
  end

  --" Whether the text is somewhere on the screen. --"
  public fun contains(self, text: string) -> bool
    for line in self.lines() do
      if line.contains(text) then
        return true
      end
    end
    false
  end

  --" The screen as one text with a line break after each line, for comparing with a whole expected picture. --"
  public fun snapshot(self) -> string
    self.lines().join("\n")
  end

  --" The screen buffer, for the styles. --"
  public fun buffer(self) -> b.Buffer
    self.runner.screen() ?? b.Buffer.create(0, 0)
  end

  --" Everything the program wrote to the terminal, one text for each picture. --"
  public fun output(self) -> array<string>
    self.written
  end

  --" Whether the program asked to stop. --"
  public fun finished(self) -> bool
    not self.runner.context().is_running()
  end

  public fun context(self) -> ap.Context
    self.runner.context()
  end
end

export Harness
