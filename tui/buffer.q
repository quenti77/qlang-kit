--" # The screen in memory

A `Buffer` is a grid of cells, each with a character and a style. A program draws into a buffer, and
`diff` gives the escape sequences that turn what the terminal shows (the previous buffer) into the new
one: only the cells that changed are written, so a screen that hardly changes costs a few bytes.

```
let screen = Buffer.create(80, 24)
screen.put(2, 1, "Hello", Style.create().bold())
screen.fill(0, 0, 80, 1, " ", Style.create().bg(Color.ansi(4)))
Term.frame(screen.diff(previous, Term.colors()))
```

A character that takes two columns (`漢`, an emoji) fills a cell and the next one, which holds `""`.
--"
import "style.q" as st
import "width.q" as w

--" A grid of cells. --"
struct Buffer
  public cols: int
  public rows: int
  chars: array<string>
  styles: array<int>
end

impl Buffer
  --" An empty screen: spaces in the style of the terminal. --"
  public fun create(cols: int, rows: int) -> Buffer
    let c = if cols < 0 then 0 else cols end
    let r = if rows < 0 then 0 else rows end
    let chars: array<string> = []
    let styles: array<int> = []
    for _i in 0..(c * r) do
      chars.push(" ")
      styles.push(0)
    end
    Buffer { cols: c, rows: r, chars: chars, styles: styles }
  end

  --" The character of a cell (`""` for the second column of a wide character, `" "` outside). --"
  public fun char_at(self, x: int, y: int) -> string
    if x < 0 or y < 0 or x >= self.cols or y >= self.rows then
      return " "
    end
    self.chars[y * self.cols + x]
  end

  public fun style_at(self, x: int, y: int) -> st.Style
    if x < 0 or y < 0 or x >= self.cols or y >= self.rows then
      return st.Style.create()
    end
    st.Style.of_key(self.styles[y * self.cols + x])
  end

  -- the cell at `i` is about to be overwritten: if it is half of a wide character, the other half becomes a space
  fun release(self, i: int, x: int)
    if self.chars[i] == "" and x > 0 then
      self.chars[i - 1] = " "
    elseif x + 1 < self.cols and self.chars[i + 1] == "" then
      self.chars[i + 1] = " "
    end
  end

  --" Writes a text from column `x` of row `y`, in one line (a newline is not a line break: it is dropped).
    What goes past the right edge is cut. Gives the column after the last character written. --"
  public fun put(self, x: int, y: int, text: string, style: st.Style) -> int
    if y < 0 or y >= self.rows then
      return x
    end
    let key = style.key()
    let at = x
    for ch in text.chars() do
      let width = w.char_width(ch)
      if width == 0 then
        -- a mark joins the character before it: it is not drawn on its own
        continue
      end
      if at >= self.cols then
        break
      end
      if at < 0 then
        at += width
        continue
      end
      let i = y * self.cols + at
      if width == 2 and at + 1 >= self.cols then
        -- no room for the second half
        self.release(i, at)
        self.chars[i] = " "
        self.styles[i] = key
        at += 1
        continue
      end
      self.release(i, at)
      self.chars[i] = ch
      self.styles[i] = key
      if width == 2 then
        self.release(i + 1, at + 1)
        self.chars[i + 1] = ""
        self.styles[i + 1] = key
      end
      at += width
    end
    at
  end

  --" Fills a rectangle with one character. --"
  public fun fill(self, x: int, y: int, width: int, height: int, ch: string, style: st.Style)
    let line = ""
    for _i in 0..width do
      line += ch
    end
    for row in y..(y + height) do
      self.put(x, row, line, style)
    end
  end

  --" Empties the screen. --"
  public fun clear(self)
    let key = 0
    for i in 0..self.chars.len() do
      self.chars[i] = " "
      self.styles[i] = key
    end
  end

  --" A copy. --"
  public fun copy(self) -> Buffer
    Buffer { cols: self.cols, rows: self.rows, chars: self.chars.concat([]), styles: self.styles.concat([]) }
  end

  --" The rows as plain text, without the styles (trailing spaces cut): what a test compares. --"
  public fun lines(self) -> array<string>
    let out: array<string> = []
    for y in 0..self.rows do
      let line = ""
      for x in 0..self.cols do
        line += self.chars[y * self.cols + x]
      end
      out.push(line.trim_end())
    end
    out
  end

  fun same(self, other: Buffer?, x: int, y: int) -> bool
    let i = y * self.cols + x
    if other == none then
      return self.chars[i] == " " and self.styles[i] == 0
    end
    self.chars[i] == other.chars[i] and self.styles[i] == other.styles[i]
  end

  --" The escape sequences that turn the screen `previous` into this one. With `none`, or a screen of another
    size, the whole terminal is erased and drawn again. `depth` is the number of colours of the terminal
    (`Term.colors()`). Empty when nothing changed. --"
  public fun diff(self, previous: Buffer?, depth: int) -> string
    let base = previous
    let out = ""
    if base != none and (base.cols != self.cols or base.rows != self.rows) then
      base = none
    end
    if base == none then
      out = "\e[0m\e[2J"
    end
    let last_style = -1
    let cx = -1
    let cy = -1
    for y in 0..self.rows do
      let x = 0
      while x < self.cols do
        if self.chars[y * self.cols + x] == "" then
          x += 1
          continue
        end
        let changed = not self.same(base, x, y)
        if not changed and cy == y and cx == x then
          -- the cursor is here: a short run of cells that did not change is cheaper to write than a jump
          let k = 1
          let near = false
          while k <= 3 and x + k < self.cols do
            if not self.same(base, x + k, y) then
              near = true
            end
            k += 1
          end
          changed = near
        end
        if not changed then
          x += 1
          continue
        end
        if cy != y or cx != x then
          out += "\e[{y + 1};{x + 1}H"
        end
        let key = self.styles[y * self.cols + x]
        if key != last_style then
          out += st.Style.of_key(key).sgr(depth)
          last_style = key
        end
        out += self.chars[y * self.cols + x]
        let advance = if x + 1 < self.cols and self.chars[y * self.cols + x + 1] == "" then 2 else 1 end
        cx = x + advance
        cy = y
        x += advance
      end
    end
    if out != "" and last_style != 0 and last_style != -1 then
      out += "\e[0m"
    end
    out
  end
end

export Buffer
