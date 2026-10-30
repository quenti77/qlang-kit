--" # Text input

A line of text with a cursor. `handle` takes an `Event`: characters are inserted, and `Backspace`,
`Delete`, the arrows, `Home`, `End`, `Ctrl+A`/`Ctrl+E` (start, end), `Ctrl+B`/`Ctrl+F` (back, forward),
`Ctrl+U` (delete to the start), `Ctrl+K` (delete to the end) and `Ctrl+W` (delete the word before) edit
it; a paste is inserted as one line. `Enter`, `Tab` and `Esc` are not used: they belong to the program.

```
let name = TextInput.create("Name")                   -- the placeholder
name.handle(event)
let cursor = name.render(screen, area, true)           -- [column, row] where to put the terminal cursor
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

fun is_word(ch: string) -> bool
  ch != " " and ch != "\t"
end

--" One line of text being typed. --"
struct TextInput
  --" What was typed. --"
  public value: string
  --" The position of the cursor, in characters from the start. --"
  public cursor: int
  placeholder: string
  mask: string
  limit: int
end

impl TextInput
  --" An empty input that shows `placeholder` while it is empty. --"
  public fun create(placeholder: string) -> TextInput
    TextInput { value: "", cursor: 0, placeholder: placeholder, mask: "", limit: 0 }
  end

  --" An input that shows `mask` (`"•"`) in place of each character, for a password. --"
  public fun password(placeholder: string) -> TextInput
    TextInput { value: "", cursor: 0, placeholder: placeholder, mask: "•", limit: 0 }
  end

  --" At most `n` characters (0 is no limit). --"
  public fun max_length(self, n: int) -> TextInput
    self.limit = n
    self
  end

  --" Replaces the text, with the cursor at the end. --"
  public fun set(self, text: string)
    self.value = text
    self.cursor = text.chars().len()
  end

  public fun clear(self)
    self.set("")
  end

  fun put(self, text: string)
    let chars = self.value.chars()
    let added = text.replace("\n", " ").replace("\r", "").chars()
    if self.limit > 0 and chars.len() + added.len() > self.limit then
      let room = self.limit - chars.len()
      if room <= 0 then
        return
      end
      added = added.slice(0, room)
    end
    let before = chars.slice(0, self.cursor).join("")
    let after = chars.slice(self.cursor, chars.len()).join("")
    self.value = before + added.join("") + after
    self.cursor += added.len()
  end

  fun cut(self, start: int, stop: int)
    let chars = self.value.chars()
    self.value = chars.slice(0, start).join("") + chars.slice(stop, chars.len()).join("")
    self.cursor = start
  end

  fun word_start(self) -> int
    let chars = self.value.chars()
    let i = self.cursor
    while i > 0 and not is_word(chars[i - 1]) do
      i -= 1
    end
    while i > 0 and is_word(chars[i - 1]) do
      i -= 1
    end
    i
  end

  --" Uses the event if it edits the text or moves the cursor. --"
  public fun handle(self, ev: Event) -> bool
    let n = self.value.chars().len()
    if ev.kind == "paste" then
      self.put(ev.text)
      return true
    end
    if ev.kind != "key" then
      return false
    end
    if ev.ctrl then
      if ev.key == "a" then
        self.cursor = 0
      elseif ev.key == "e" then
        self.cursor = n
      elseif ev.key == "b" then
        self.cursor = if self.cursor > 0 then self.cursor - 1 else 0 end
      elseif ev.key == "f" then
        self.cursor = if self.cursor < n then self.cursor + 1 else n end
      elseif ev.key == "u" then
        self.cut(0, self.cursor)
      elseif ev.key == "k" then
        self.cut(self.cursor, n)
      elseif ev.key == "w" then
        self.cut(self.word_start(), self.cursor)
      else
        return false
      end
      return true
    end
    if ev.alt then
      return false
    end
    if ev.key == "Left" then
      self.cursor = if self.cursor > 0 then self.cursor - 1 else 0 end
    elseif ev.key == "Right" then
      self.cursor = if self.cursor < n then self.cursor + 1 else n end
    elseif ev.key == "Home" then
      self.cursor = 0
    elseif ev.key == "End" then
      self.cursor = n
    elseif ev.key == "Backspace" then
      if self.cursor > 0 then
        self.cut(self.cursor - 1, self.cursor)
      end
    elseif ev.key == "Delete" then
      if self.cursor < n then
        self.cut(self.cursor, self.cursor + 1)
        self.cursor = self.cursor
      end
    elseif ev.key.chars().len() == 1 then
      self.put(ev.key)
    else
      return false
    end
    true
  end

  --" Draws the text in the first row of `area` and gives where the terminal cursor goes: `[column, row]`,
    or an empty array when the input does not have the focus (put the cursor there only when it does). --"
  public fun render(self, screen: b.Buffer, area: l.Rect, focused: bool) -> array<int>
    if area.is_empty() then
      return []
    end
    let shown = if self.mask == "" then self.value.chars() else self.value.chars().map(fun(c: string) -> string self.mask end) end
    if shown.is_empty() and not focused then
      screen.put(area.x, area.y, self.placeholder, st.Style.create().dim())
      return []
    end
    if shown.is_empty() then
      screen.put(area.x, area.y, self.placeholder, st.Style.create().dim())
      return [area.x, area.y]
    end
    let start = 0
    while start < self.cursor and width_of(shown, start, self.cursor) > area.w - 1 do
      start += 1
    end
    screen.put(area.x, area.y, shown.slice(start, shown.len()).join(""), st.Style.create())
    if not focused then
      return []
    end
    [area.x + width_of(shown, start, self.cursor), area.y]
  end
end

export TextInput
