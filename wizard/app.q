--" # The generation wizard

`kit wizard` is `kit make` as a full screen: pick what to make, type its name, and see **before anything is
written** which files would be created or changed and what they contain.

```
┌ Kind ────────┐ ┌ Files ─────────────────────────┐
│ › controller │ │ create controllers/posts.q     │
│   model      │ │ create tests/posts_test.q      │
│   migration  │ │ update app.q                   │
└──────────────┘ ├ Preview ───────────────────────┤
┌ Name ────────┐ │ -- Post controller: ...        │
│ Post         │ │ import "@std/web/app.q" as web │
└──────────────┘ └────────────────────────────────┘
```

| Key | Does |
| --- | --- |
| `Tab` / `Shift+Tab` | moves between the kinds, the name, the files and the preview |
| `↑` `↓` | moves in the list that has the focus (`PageUp` / `PageDown` scroll the preview) |
| `t` `r` `f` | with / without the test, with / without the registration, replace existing files |
| `Ctrl+S` | writes the files |
| `q` or `Esc` | quits (when the name is not being typed) |
--"
import "../make/make.q" as mk
import "../tui/app.q" as ap
import "../tui/block.q" as bk
import "../tui/buffer.q" as b
import "../tui/help.q" as hp
import "../tui/input.q" as inp
import "../tui/keys.q" as k
import "../tui/layout.q" as l
import "../tui/list.q" as li
import "../tui/style.q" as st
import "../tui/text.q" as tx

--" The state of the wizard. --"
struct Wizard
  public files: mk.Files
  public clock: fun() -> int
  public kinds: li.List
  public name: inp.TextInput
  public paths: li.List
  public focus: k.FocusRing
  public with_test: bool
  public register: bool
  public force: bool
  public changes: array<mk.Change>
  public problem: string
  public status: string
  public scroll: int
  public written: bool
end

fun create(files: mk.Files, clock: fun() -> int) -> Wizard
  let w = Wizard {
    files: files,
    clock: clock,
    kinds: li.List.create(mk.kinds()),
    name: inp.TextInput.create("name, e.g. BlogPost"),
    paths: li.List.create([]),
    focus: k.FocusRing.create(["kind", "name", "files", "preview"]),
    with_test: true,
    register: true,
    force: false,
    changes: [],
    problem: "",
    status: "",
    scroll: 0,
    written: false,
  }
  replan(w)
  w
end

fun kind_of(w: Wizard) -> string
  w.kinds.selected_item() ?? ""
end

--" Works out the files again from the kind, the name and the options. --"
fun replan(w: Wizard)
  w.scroll = 0
  w.changes = []
  w.problem = ""
  if w.name.value.trim() == "" then
    w.problem = "type a name to see the files"
    w.paths.set_items([])
    return
  end
  let options = mk.Options { force: w.force, register: w.register, with_test: w.with_test, now: w.clock() }
  let planned = mk.plan(kind_of(w), w.name.value, w.files, options)
  if planned.is_err() then
    w.problem = planned.unwrap_err().message
    w.paths.set_items([])
    return
  end
  w.changes = planned.unwrap()
  w.paths.set_items(w.changes.map(fun(c: mk.Change) -> string tx.fit(c.action, 7, "left") + " " + c.path end))
end

fun selected_change(w: Wizard) -> mk.Change?
  if w.changes.is_empty() then
    return none
  end
  w.changes[w.paths.selected]
end

fun write_all(w: Wizard)
  if w.changes.is_empty() then
    w.status = "nothing to write"
    return
  end
  let done = mk.apply(w.changes, w.files)
  if done.is_err() then
    w.status = "error: " + done.unwrap_err().message
    return
  end
  let count = w.changes.filter(fun(c: mk.Change) -> bool c.action != "skip" end).len()
  w.status = "wrote {count} file(s)"
  w.written = true
  w.name.clear()
  replan(w)
end

impl ap.Program for Wizard
  public fun update(self, ev: Event, ctx: ap.Context)
    if ev.kind == "key" and ev.ctrl and ev.key == "s" then
      write_all(self)
      return
    end
    let typing = self.focus.has("name")
    if ev.kind == "key" and not typing and not ev.ctrl and not ev.alt then
      if ev.key == "q" or ev.key == "Esc" then
        ctx.quit()
        return
      end
      if ev.key == "t" then
        self.with_test = not self.with_test
        replan(self)
        return
      end
      if ev.key == "r" then
        self.register = not self.register
        replan(self)
        return
      end
      if ev.key == "f" then
        self.force = not self.force
        replan(self)
        return
      end
    end
    if typing and ev.kind == "key" and ev.key == "Esc" then
      self.focus.focus("kind")
      return
    end
    if not (typing and ev.kind == "key" and ev.key != "Tab" and ev.key != "Enter") and self.focus.handle(ev) then
      self.status = ""
      return
    end
    if typing then
      if self.name.handle(ev) then
        self.status = ""
        replan(self)
      end
      return
    end
    if self.focus.has("kind") then
      let before = self.kinds.selected
      self.kinds.handle(ev)
      if self.kinds.selected != before then
        replan(self)
      end
    elseif self.focus.has("files") then
      let before = self.paths.selected
      self.paths.handle(ev)
      if self.paths.selected != before then
        self.scroll = 0
      end
    elseif ev.kind == "key" then
      if ev.key == "Down" or ev.key == "j" then
        self.scroll += 1
      elseif ev.key == "Up" or ev.key == "k" then
        self.scroll = if self.scroll > 0 then self.scroll - 1 else 0 end
      elseif ev.key == "PageDown" then
        self.scroll += 10
      elseif ev.key == "PageUp" then
        self.scroll = if self.scroll > 10 then self.scroll - 10 else 0 end
      end
    end
  end

  public fun view(self, screen: b.Buffer, area: l.Rect) -> array<int>
    let rows = area.split_column([l.Size.fill(1), l.Size.fixed(1)], 0)
    let cols = rows[0].split_row([l.Size.fixed(32), l.Size.fill(1)], 0)
    let left = cols[0].split_column([l.Size.fill(1), l.Size.fixed(3), l.Size.fixed(5)], 0)
    let edge = fun(id: string) -> st.Style
      if self.focus.has(id) then st.Style.create().fg(st.Color.ansi(6)).bold() else st.Style.create() end
    end
    self.kinds.render(screen, bk.Block.create().rounded().title("Kind").border_style(edge("kind")).render(screen, left[0]), self.focus.has("kind"))
    let name_box = bk.Block.create().rounded().title("Name").border_style(edge("name")).render(screen, left[1])
    let at = self.name.render(screen, name_box, self.focus.has("name"))
    let options = bk.Block.create().rounded().title("Options").render(screen, left[2])
    screen.put(options.x, options.y, (if self.with_test then "[x]" else "[ ]" end) + " t  test with a controller", st.Style.create())
    screen.put(options.x, options.y + 1, (if self.register then "[x]" else "[ ]" end) + " r  register in app.q", st.Style.create())
    screen.put(options.x, options.y + 2, (if self.force then "[x]" else "[ ]" end) + " f  replace existing files", st.Style.create())
    let right = cols[1].split_column([l.Size.fixed(6), l.Size.fill(1)], 0)
    let list_area = bk.Block.create().rounded().title("Files").border_style(edge("files")).render(screen, right[0])
    if self.problem != "" then
      screen.put(list_area.x, list_area.y, tx.truncate(self.problem, list_area.w), st.Style.create().fg(st.Color.ansi(3)))
    else
      self.paths.render(screen, list_area, self.focus.has("files"))
    end
    let preview = bk.Block.create().rounded().title("Preview").border_style(edge("preview")).render(screen, right[1])
    let change = selected_change(self)
    if change != none then
      let lines = if change.content == "" then [change.note] else change.content.split("\n") end
      let start = if self.scroll > lines.len() - 1 then lines.len() - 1 else self.scroll end
      for i in 0..preview.h do
        let n = start + i
        if n >= lines.len() then
          break
        end
        screen.put(preview.x, preview.y + i, tx.truncate(lines[n], preview.w), st.Style.create())
      end
    end
    let hints = [["tab", "next"], ["t r f", "options"], ["ctrl+s", "write"], ["q", "quit"]]
    hp.HelpBar.create(hints).render(screen, rows[1])
    if self.status != "" then
      screen.put(area.right() - self.status.len() - 1, rows[1].y, self.status, st.Style.create().fg(st.Color.ansi(2)).bold())
    end
    if at.len() == 2 then
      return at
    end
    []
  end
end

--" Runs the wizard in the terminal, on the disk. --"
fun run() -> Result<bool, Error>
  let wizard = create(mk.disk_files(), fun() -> int time.now() end)
  ap.run_in_terminal(wizard)
end

export Wizard, create, run
