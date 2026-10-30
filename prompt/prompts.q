--" # Prompts

Small interactive questions, each drawn in a box in the middle of the screen: text, password, confirm,
select, multi-select and autocomplete. Every prompt is a `Prompt` (`handle` an event, `draw` itself); a
`Frame` puts one in a box and runs it with the event loop of the TUI engine, so a prompt is tested like
any other screen (`testing.Harness`). `session.q` is what a command uses: it also answers without a terminal.
--"
import "../tui/app.q" as ap
import "../tui/block.q" as bk
import "../tui/buffer.q" as b
import "../tui/input.q" as inp
import "../tui/layout.q" as l
import "../tui/list.q" as li
import "../tui/style.q" as st
import "../tui/text.q" as tx
import "../tui/theme.q" as th
import "rules.q" as rules

--" What every prompt can do. --"
trait Prompt
  fun handle(self, ev: Event) -> bool
  fun draw(self, screen: b.Buffer, area: l.Rect) -> array<int>
  fun height(self) -> int
end

fun red() -> st.Style
  th.error()
end

fun dim() -> st.Style
  st.Style.create().dim()
end

--" A line of text (a password when `secret`). `default` is taken when nothing is typed. --"
struct TextPrompt
  public input: inp.TextInput
  public rule_list: array<rules.Rule>
  public default: string
  public error: string
  public secret: bool
end

impl TextPrompt
  public fun create(placeholder: string, default: string, secret: bool, rule_list: array<rules.Rule>) -> TextPrompt
    let input = if secret then inp.TextInput.password(placeholder) else inp.TextInput.create(placeholder) end
    if default != "" and not secret then
      input.set(default)
    end
    TextPrompt { input: input, rule_list: rule_list, default: default, error: "", secret: secret }
  end

  public fun answer(self) -> string
    if self.input.value == "" then self.default else self.input.value end
  end
end

impl Prompt for TextPrompt
  public fun handle(self, ev: Event) -> bool
    if ev.kind == "key" and ev.key == "Enter" then
      let problem = rules.check_all(self.rule_list, self.answer())
      if problem != none then
        self.error = problem
        return false
      end
      return true
    end
    if self.input.handle(ev) then
      self.error = ""
    end
    false
  end

  public fun draw(self, screen: b.Buffer, area: l.Rect) -> array<int>
    let at = self.input.render(screen, area, true)
    if self.error != "" and area.h > 1 then
      screen.put(area.x, area.y + 1, tx.truncate("! " + self.error, area.w), red())
    end
    at
  end

  public fun height(self) -> int
    2
  end
end

--" Yes or no. --"
struct ConfirmPrompt
  public yes: bool
end

impl Prompt for ConfirmPrompt
  public fun handle(self, ev: Event) -> bool
    if ev.kind != "key" or ev.ctrl or ev.alt then
      return false
    end
    if ev.key == "y" or ev.key == "Y" then
      self.yes = true
      return true
    end
    if ev.key == "n" or ev.key == "N" then
      self.yes = false
      return true
    end
    if ev.key == "Left" or ev.key == "Right" or ev.key == "Tab" or ev.key == "h" or ev.key == "l" then
      self.yes = not self.yes
      return false
    end
    ev.key == "Enter"
  end

  public fun draw(self, screen: b.Buffer, area: l.Rect) -> array<int>
    let chosen = th.selected().bold()
    screen.put(area.x, area.y, "[ Yes ]", if self.yes then chosen else st.Style.create() end)
    screen.put(area.x + 9, area.y, "[ No ]", if self.yes then st.Style.create() else chosen end)
    []
  end

  public fun height(self) -> int
    1
  end
end

--" One option out of several. --"
struct SelectPrompt
  public options: array<string>
  public list: li.List
end

impl SelectPrompt
  public fun create(options: array<string>, start: int) -> SelectPrompt
    let list = li.List.create(options)
    list.move_to(start)
    SelectPrompt { options: options, list: list }
  end

  public fun answer(self) -> string
    self.list.selected_item() ?? ""
  end
end

impl Prompt for SelectPrompt
  public fun handle(self, ev: Event) -> bool
    if ev.kind == "key" and ev.key == "Enter" then
      return not self.options.is_empty()
    end
    self.list.handle(ev)
    false
  end

  public fun draw(self, screen: b.Buffer, area: l.Rect) -> array<int>
    self.list.render(screen, area, true)
    []
  end

  public fun height(self) -> int
    if self.options.len() > 8 then 8 else self.options.len() end
  end
end

--" Several options, each ticked or not (`Space` ticks, `a` ticks all or none). --"
struct MultiPrompt
  public options: array<string>
  public ticked: array<bool>
  public list: li.List
  public minimum: int
  public error: string
end

fun tick_lines(options: array<string>, ticked: array<bool>) -> array<string>
  let out: array<string> = []
  for i in 0..options.len() do
    out.push((if ticked[i] then "[x] " else "[ ] " end) + options[i])
  end
  out
end

impl MultiPrompt
  public fun create(options: array<string>, ticked: array<string>, minimum: int) -> MultiPrompt
    let flags: array<bool> = options.map(fun(o: string) -> bool ticked.contains(o) end)
    MultiPrompt { options: options, ticked: flags, list: li.List.create(tick_lines(options, flags)), minimum: minimum, error: "" }
  end

  fun refresh(self)
    self.list.set_items(tick_lines(self.options, self.ticked))
  end

  public fun answers(self) -> array<string>
    let out: array<string> = []
    for i in 0..self.options.len() do
      if self.ticked[i] then
        out.push(self.options[i])
      end
    end
    out
  end
end

impl Prompt for MultiPrompt
  public fun handle(self, ev: Event) -> bool
    if ev.kind == "key" and ev.key == "Enter" then
      if self.answers().len() < self.minimum then
        self.error = "choose at least {self.minimum}"
        return false
      end
      return true
    end
    if ev.kind == "key" and not ev.ctrl and not ev.alt then
      if ev.key == " " and not self.options.is_empty() then
        self.ticked[self.list.selected] = not self.ticked[self.list.selected]
        self.error = ""
        self.refresh()
        return false
      end
      if ev.key == "a" then
        let all = self.answers().len() < self.options.len()
        for i in 0..self.ticked.len() do
          self.ticked[i] = all
        end
        self.refresh()
        return false
      end
    end
    self.list.handle(ev)
    false
  end

  public fun draw(self, screen: b.Buffer, area: l.Rect) -> array<int>
    let rows = if self.error != "" then area.h - 1 else area.h end
    self.list.render(screen, l.Rect.create(area.x, area.y, area.w, rows), true)
    if self.error != "" then
      screen.put(area.x, area.y + rows, "! " + self.error, red())
    end
    []
  end

  public fun height(self) -> int
    (if self.options.len() > 8 then 8 else self.options.len() end) + 1
  end
end

--" A text with suggestions that narrow as you type (`Down` and `Up` choose, `Tab` completes, `Enter` accepts). With
`strict` the answer must be one of the options. --"
struct AutoPrompt
  public options: array<string>
  public input: inp.TextInput
  public list: li.List
  public strict: bool
  public error: string
  public picked: string
end

fun narrowed(options: array<string>, text: string) -> array<string>
  let low = text.lower()
  options.filter(fun(o: string) -> bool low == "" or o.lower().contains(low) end)
end

impl AutoPrompt
  public fun create(placeholder: string, options: array<string>, strict: bool) -> AutoPrompt
    AutoPrompt { options: options, input: inp.TextInput.create(placeholder), list: li.List.create(options), strict: strict, error: "", picked: "" }
  end

  public fun answer(self) -> string
    self.picked
  end
end

impl Prompt for AutoPrompt
  public fun handle(self, ev: Event) -> bool
    if ev.kind == "key" and not ev.ctrl and not ev.alt then
      if ev.key == "Down" or ev.key == "Up" or ev.key == "PageDown" or ev.key == "PageUp" then
        self.list.handle(ev)
        return false
      end
      if ev.key == "Tab" then
        let choice = self.list.selected_item()
        if choice != none then
          self.input.set(choice)
          self.list.set_items(narrowed(self.options, choice))
        end
        return false
      end
      if ev.key == "Enter" then
        let typed = self.input.value
        if self.options.contains(typed) then
          self.picked = typed
          return true
        end
        let choice = self.list.selected_item()
        if choice != none and typed != "" then
          self.picked = choice
          return true
        end
        if not self.strict and typed != "" then
          self.picked = typed
          return true
        end
        self.error = if self.strict then "choose one of the suggestions" else "type something" end
        return false
      end
    end
    if self.input.handle(ev) then
      self.error = ""
      self.list.set_items(narrowed(self.options, self.input.value))
      self.list.move_to(0)
    end
    false
  end

  public fun draw(self, screen: b.Buffer, area: l.Rect) -> array<int>
    let at = self.input.render(screen, l.Rect.create(area.x, area.y, area.w, 1), true)
    if self.error != "" then
      screen.put(area.x, area.y + 1, tx.truncate("! " + self.error, area.w), red())
    end
    if area.h > 2 then
      self.list.render(screen, l.Rect.create(area.x, area.y + 2, area.w, area.h - 2), false)
    end
    at
  end

  public fun height(self) -> int
    10
  end
end

--" A prompt in a box with its question, run by the event loop. `Esc` and `Ctrl+C` cancel. --"
struct Frame
  public prompt: Prompt
  public label: string
  public hint: string
  public cancelled: bool
  public finished: bool
end

impl ap.Program for Frame
  public fun update(self, ev: Event, ctx: ap.Context)
    if ev.kind == "key" and ev.key == "Esc" then
      self.cancelled = true
      ctx.quit()
      return
    end
    if self.prompt.handle(ev) then
      self.finished = true
      ctx.quit()
    end
  end

  public fun view(self, screen: b.Buffer, area: l.Rect) -> array<int>
    let extra = if self.hint == "" then 0 else 1 end
    let width = if area.w < 64 then area.w else 60 end
    let box = area.center(width, self.prompt.height() + extra + 3)
    let inside = bk.Block.create().rounded().title(self.label).render(screen, box)
    if inside.is_empty() then
      return []
    end
    if self.hint != "" then
      screen.put(inside.x + 1, inside.y, tx.truncate(self.hint, inside.w - 2), dim())
    end
    let body = l.Rect.create(inside.x + 1, inside.y + extra, inside.w - 2, inside.h - extra - 1)
    let cursor = self.prompt.draw(screen, body)
    screen.put(inside.x + 1, inside.bottom() - 1, "enter ok · esc cancel", dim())
    cursor
  end
end

export Prompt, TextPrompt, ConfirmPrompt, SelectPrompt, MultiPrompt, AutoPrompt, Frame
