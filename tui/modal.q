--" # Dialogs

A message in a box in the middle of the screen, with buttons. While it is open it takes the keys:
`Left` / `Right` / `Tab` choose a button, `Enter` presses it, `Esc` cancels (the last button), a letter that is
the first of a button presses it (`y` for `Yes`).

```
let ask = Dialog.confirm("Delete this user?", "This cannot be undone.")
ask.handle(event)                       -- true while it uses the keys
ask.render(screen, screen_area)         -- draws on top of what is already there
ask.result()                            -- "" while open, else the label of the button pressed
```
--"
import "block.q" as bk
import "buffer.q" as b
import "layout.q" as l
import "style.q" as st
import "theme.q" as th
import "text.q" as tx
import "width.q" as w

--" A message with buttons. --"
struct Dialog
  heading: string
  message: string
  buttons: array<string>
  chosen: int
  answer: string
  danger: bool
end

impl Dialog
  --" A dialog with the buttons you give (the first is the one selected). --"
  public fun create(heading: string, message: string, buttons: array<string>) -> Dialog
    Dialog { heading: heading, message: message, buttons: buttons, chosen: 0, answer: "", danger: false }
  end

  --" `Yes` and `No`, with `No` selected: a destructive question must not be one `Enter` away. --"
  public fun confirm(heading: string, message: string) -> Dialog
    Dialog { heading: heading, message: message, buttons: ["Yes", "No"], chosen: 1, answer: "", danger: true }
  end

  --" Just `OK`. --"
  public fun notice(heading: string, message: string) -> Dialog
    Dialog.create(heading, message, ["OK"])
  end

  --" The label of the button that was pressed, or `""` while the dialog is open. --"
  public fun result(self) -> string
    self.answer
  end

  public fun is_open(self) -> bool
    self.answer == ""
  end

  --" Opens it again. --"
  public fun reopen(self)
    self.answer = ""
    self.chosen = if self.danger then self.buttons.len() - 1 else 0 end
  end

  --" Takes every key while open (it returns `true`), and records the answer when a button is pressed. A
    closed dialog uses nothing. --"
  public fun handle(self, ev: Event) -> bool
    if self.answer != "" then
      return false
    end
    if ev.kind != "key" then
      return ev.kind == "mouse"
    end
    let n = self.buttons.len()
    if ev.key == "Left" or (ev.key == "Tab" and ev.shift) then
      self.chosen = (self.chosen + n - 1) % n
    elseif ev.key == "Right" or ev.key == "Tab" then
      self.chosen = (self.chosen + 1) % n
    elseif ev.key == "Enter" then
      self.answer = self.buttons[self.chosen]
    elseif ev.key == "Esc" then
      self.answer = self.buttons[n - 1]
    elseif ev.key.chars().len() == 1 and not ev.ctrl and not ev.alt then
      for label in self.buttons do
        if label.lower().starts_with(ev.key.lower()) then
          self.answer = label
          break
        end
      end
    end
    true
  end

  -- the buttons as one line, and where each starts in it
  fun button_line(self) -> string
    self.buttons.map(fun(label: string) -> string "[ {label} ]" end).join("  ")
  end

  --" Draws the box in the middle of `area` (over what is there) and gives its rectangle. --"
  public fun render(self, screen: b.Buffer, area: l.Rect) -> l.Rect
    let buttons = self.button_line()
    let inner_w = w.text_width(buttons)
    let message_w = if area.w - 8 < 20 then 20 else area.w - 8 end
    let width = inner_w
    if width < 36 then
      width = 36
    end
    if width > message_w then
      width = message_w
    end
    let lines = tx.wrap(self.message, width)
    let height = lines.len() + 4
    let box = area.center(width + 4, height + 1)
    let edge = if self.danger then th.error() else th.accent() end
    let inside = bk.Block.create().rounded().title(self.heading).border_style(edge).background(st.Style.create()).render(screen, box)
    for i in 0..lines.len() do
      screen.put(inside.x + 1, inside.y + i, lines[i], st.Style.create())
    end
    let x = inside.x + (inside.w - inner_w) div 2
    for i in 0..self.buttons.len() do
      let text = "[ " + self.buttons[i] + " ]"
      let style = if i == self.chosen then th.selected().bold() else st.Style.create() end
      screen.put(x, inside.y + inside.h - 1, text, style)
      x += w.text_width(text) + 2
    end
    box
  end
end

export Dialog
