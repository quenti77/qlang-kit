--" # Text area

Several lines of text with a cursor, like `TextInput` but with `Enter` for a new line. Arrows move by
character and line, `Home` and `End` go to the ends of the line, `PageUp` and `PageDown` by a screen,
`Ctrl+A` / `Ctrl+E` / `Ctrl+U` / `Ctrl+K` / `Ctrl+W` edit as in `TextInput` within the line (`Backspace` at
the start of a line joins it to the one above). A paste keeps its line breaks. `Tab` and `Esc` are left to
the program.

```
let notes = TextArea.create()
notes.set("first\nsecond")
notes.handle(event)
let cursor = notes.render(screen, area, true)      -- [column, row] for the terminal cursor
notes.text()                                       -- "first\nsecond"
```
--"
import "buffer.q" as b
import "layout.q" as l
import "style.q" as st
import "width.q" as w

fun width_of(chars: array<string>, from_index: int, to_index: int) -> int
  let total = 0
  for i in from_index..to_index do
    total += w.char_width(chars[i])
  end
  total
end

--" Lines of text being typed. --"
struct TextArea
  lines: array<string>
  --" The line of the cursor (from 0). --"
  public row: int
  --" The column of the cursor in characters (from 0). --"
  public col: int
  top: int
  page: int
end

impl TextArea
  public fun create() -> TextArea
    TextArea { lines: [""], row: 0, col: 0, top: 0, page: 10 }
  end

  --" Replaces the text, with the cursor at the end. --"
  public fun set(self, text: string)
    self.lines = text.replace("\r\n", "\n").split("\n")
    self.row = self.lines.len() - 1
    self.col = self.lines[self.row].chars().len()
    self.top = 0
  end

  --" The whole text, lines joined by `\n`. --"
  public fun text(self) -> string
    self.lines.join("\n")
  end

  public fun line_count(self) -> int
    self.lines.len()
  end

  fun length(self, row: int) -> int
    self.lines[row].chars().len()
  end

  fun go_to(self, row: int, col: int)
    let r = if row < 0 then 0 elseif row >= self.lines.len() then self.lines.len() - 1 else row end
    self.row = r
    let n = self.length(r)
    self.col = if col < 0 then 0 elseif col > n then n else col end
  end

  fun insert(self, text: string)
    let pieces = text.replace("\r\n", "\n").replace("\r", "\n").split("\n")
    let chars = self.lines[self.row].chars()
    let before = chars.slice(0, self.col).join("")
    let after = chars.slice(self.col, chars.len()).join("")
    if pieces.len() == 1 then
      self.lines[self.row] = before + pieces[0] + after
      self.col += pieces[0].chars().len()
      return
    end
    let last = pieces.len() - 1
    let rebuilt: array<string> = []
    for i in 0..self.row do
      rebuilt.push(self.lines[i])
    end
    rebuilt.push(before + pieces[0])
    for i in 1..last do
      rebuilt.push(pieces[i])
    end
    rebuilt.push(pieces[last] + after)
    for i in (self.row + 1)..self.lines.len() do
      rebuilt.push(self.lines[i])
    end
    self.lines = rebuilt
    self.row += last
    self.col = pieces[last].chars().len()
  end

  fun replace_line(self, row: int, text: string)
    self.lines[row] = text
  end

  fun backspace(self)
    if self.col > 0 then
      let chars = self.lines[self.row].chars()
      self.replace_line(self.row, chars.slice(0, self.col - 1).join("") + chars.slice(self.col, chars.len()).join(""))
      self.col -= 1
      return
    end
    if self.row == 0 then
      return
    end
    let above = self.lines[self.row - 1]
    let joined = above + self.lines[self.row]
    let rebuilt: array<string> = []
    for i in 0..self.lines.len() do
      if i == self.row then
        continue
      end
      rebuilt.push(if i == self.row - 1 then joined else self.lines[i] end)
    end
    self.lines = rebuilt
    self.row -= 1
    self.col = above.chars().len()
  end

  fun delete_forward(self)
    let n = self.length(self.row)
    if self.col < n then
      let chars = self.lines[self.row].chars()
      self.replace_line(self.row, chars.slice(0, self.col).join("") + chars.slice(self.col + 1, n).join(""))
      return
    end
    if self.row + 1 >= self.lines.len() then
      return
    end
    let joined = self.lines[self.row] + self.lines[self.row + 1]
    let rebuilt: array<string> = []
    for i in 0..self.lines.len() do
      if i == self.row + 1 then
        continue
      end
      rebuilt.push(if i == self.row then joined else self.lines[i] end)
    end
    self.lines = rebuilt
  end

  --" Uses the event if it edits the text or moves the cursor. --"
  public fun handle(self, ev: Event) -> bool
    if ev.kind == "paste" then
      self.insert(ev.text)
      return true
    end
    if ev.kind != "key" or ev.alt then
      return false
    end
    let n = self.length(self.row)
    let chars = self.lines[self.row].chars()
    if ev.ctrl then
      if ev.key == "a" then
        self.col = 0
      elseif ev.key == "e" then
        self.col = n
      elseif ev.key == "u" then
        self.replace_line(self.row, chars.slice(self.col, n).join(""))
        self.col = 0
      elseif ev.key == "k" then
        self.replace_line(self.row, chars.slice(0, self.col).join(""))
      elseif ev.key == "w" then
        let i = self.col
        while i > 0 and chars[i - 1] == " " do
          i -= 1
        end
        while i > 0 and chars[i - 1] != " " do
          i -= 1
        end
        self.replace_line(self.row, chars.slice(0, i).join("") + chars.slice(self.col, n).join(""))
        self.col = i
      else
        return false
      end
      return true
    end
    if ev.key == "Left" then
      if self.col > 0 then
        self.col -= 1
      elseif self.row > 0 then
        self.go_to(self.row - 1, self.length(self.row - 1))
      end
    elseif ev.key == "Right" then
      if self.col < n then
        self.col += 1
      elseif self.row + 1 < self.lines.len() then
        self.go_to(self.row + 1, 0)
      end
    elseif ev.key == "Up" then
      self.go_to(self.row - 1, self.col)
    elseif ev.key == "Down" then
      self.go_to(self.row + 1, self.col)
    elseif ev.key == "PageUp" then
      self.go_to(self.row - self.page, self.col)
    elseif ev.key == "PageDown" then
      self.go_to(self.row + self.page, self.col)
    elseif ev.key == "Home" then
      self.col = 0
    elseif ev.key == "End" then
      self.col = n
    elseif ev.key == "Enter" then
      self.insert("\n")
    elseif ev.key == "Backspace" then
      self.backspace()
    elseif ev.key == "Delete" then
      self.delete_forward()
    elseif ev.key.chars().len() == 1 then
      self.insert(ev.key)
    else
      return false
    end
    true
  end

  --" Draws the text in `area` and gives where the terminal cursor goes (`[column, row]`), or an empty array
    without the focus. --"
  public fun render(self, screen: b.Buffer, area: l.Rect, focused: bool) -> array<int>
    if area.is_empty() then
      return []
    end
    self.page = area.h
    if self.row < self.top then
      self.top = self.row
    end
    if self.row >= self.top + area.h then
      self.top = self.row - area.h + 1
    end
    let plain = st.Style.create()
    let shift = 0
    let current = self.lines[self.row].chars()
    while shift < self.col and width_of(current, shift, self.col) > area.w - 1 do
      shift += 1
    end
    for i in 0..area.h do
      let r = self.top + i
      if r >= self.lines.len() then
        break
      end
      let chars = self.lines[r].chars()
      let start = if r == self.row then shift else 0 end
      if start < chars.len() then
        screen.put(area.x, area.y + i, chars.slice(start, chars.len()).join(""), plain)
      end
    end
    if not focused then
      return []
    end
    [area.x + width_of(current, shift, self.col), area.y + self.row - self.top]
  end
end

export TextArea
