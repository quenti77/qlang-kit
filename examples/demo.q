-- A small TUI: tabs, a list, a search field and a dialog. Run it in a terminal: qlang run examples/demo.q
import "../tui/app.q" as ap
import "../tui/block.q" as bk
import "../tui/buffer.q" as b
import "../tui/help.q" as hp
import "../tui/input.q" as inp
import "../tui/keys.q" as k
import "../tui/layout.q" as l
import "../tui/list.q" as li
import "../tui/modal.q" as md
import "../tui/style.q" as st
import "../tui/tabs.q" as tb

struct Demo
  public tabs: tb.Tabs
  public list: li.List
  public search: inp.TextInput
  public focus: k.FocusRing
  public ask: md.Dialog
  public all: array<string>
  public ticks: int
  public shown: bool
end

fun demo() -> Demo
  let routes = ["GET /", "GET /users", "POST /users", "GET /users/:id", "DELETE /users/:id", "GET /health"]
  Demo {
    tabs: tb.Tabs.create(["Routes", "About"]),
    list: li.List.create(routes),
    search: inp.TextInput.create("filter..."),
    focus: k.FocusRing.create(["list", "search"]),
    ask: md.Dialog.confirm("Quit", "Leave the demo?"),
    all: routes,
    ticks: 0,
    shown: false,
  }
end

fun narrowed(all: array<string>, text: string) -> array<string>
  all.filter(fun(r: string) -> bool r.lower().contains(text.lower()) end)
end

impl ap.Program for Demo
  public fun update(self, ev: Event, ctx: ap.Context)
    if ev.kind == "timer" then
      self.ticks += 1
      return
    end
    if self.shown then
      self.ask.handle(ev)
      if not self.ask.is_open() then
        self.shown = false
        if self.ask.result() == "Yes" then
          ctx.quit()
        end
      end
      return
    end
    if k.quit_pressed(ev) and self.focus.has("list") then
      self.ask.reopen()
      self.shown = true
      return
    end
    if self.focus.handle(ev) or self.tabs.handle(ev) then
      return
    end
    if self.focus.has("search") then
      if self.search.handle(ev) then
        self.list.set_items(narrowed(self.all, self.search.value))
      end
    else
      self.list.handle(ev)
    end
  end

  public fun view(self, screen: b.Buffer, area: l.Rect) -> array<int>
    let rows = area.split_column([l.Size.fixed(1), l.Size.fill(1), l.Size.fixed(1)], 0)
    self.tabs.render(screen, rows[0])
    let cursor: array<int> = []
    if self.tabs.active == 0 then
      let parts = rows[1].split_column([l.Size.fixed(3), l.Size.fill(1)], 0)
      let box = bk.Block.create().rounded().title("Search").render(screen, parts[0])
      let at = self.search.render(screen, box, self.focus.has("search"))
      if at.len() == 2 then
        cursor.push(at[0])
        cursor.push(at[1])
      end
      let inside = bk.Block.create().rounded().title("Routes").render(screen, parts[1])
      self.list.render(screen, inside, self.focus.has("list"))
    else
      screen.put(2, 3, "qlang-kit demo, {self.ticks} seconds", st.Style.create())
    end
    hp.HelpBar.create([["tab", "focus"], ["←→", "tabs"], ["↑↓", "move"], ["q", "quit"]]).render(screen, rows[2])
    if self.shown then
      self.ask.render(screen, area)
      return []
    end
    cursor
  end
end

let program = demo()
let ran = ap.run_in_terminal_with(program, fun(ctx: ap.Context) -> bool
  ctx.every("second", 1000)
  true
end)
if ran.is_err() then
  print(ran.unwrap_err().message)
end
