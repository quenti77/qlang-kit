--" # Blocks: frames with a title

A `Block` draws a border, with a title in the top line, and gives the rectangle inside it for the
content.

```
let block = Block.create().title("Routes").rounded().border_style(Style.create().fg(Color.ansi(6)))
let inside = block.render(screen, area)          -- draws the frame, gives the inner Rect
screen.put(inside.x, inside.y, "GET /", Style.create())
```

Borders: `single` (the default), `rounded`, `double`, `thick`, `ascii` and `borderless`. A rectangle too small for
a frame (under 2 characters in a direction) is left alone and the block gives an empty rectangle.
--"
import "buffer.q" as b
import "layout.q" as l
import "style.q" as st
import "text.q" as tx
import "width.q" as w

-- top left, top right, bottom left, bottom right, horizontal, vertical
fun glyphs(border: string) -> array<string>
  if border == "rounded" then
    return ["╭", "╮", "╰", "╯", "─", "│"]
  end
  if border == "double" then
    return ["╔", "╗", "╚", "╝", "═", "║"]
  end
  if border == "thick" then
    return ["┏", "┓", "┗", "┛", "━", "┃"]
  end
  if border == "ascii" then
    return ["+", "+", "+", "+", "-", "|"]
  end
  ["┌", "┐", "└", "┘", "─", "│"]
end

--" A frame with an optional title. Like `Style`, a block never changes: each method gives a new one. --"
struct Block
  border: string
  heading: string
  align: string
  line: st.Style
  title_style: st.Style
  fill: st.Style?
end

impl Block
  --" A block with a single border and no title. --"
  public fun create() -> Block
    Block { border: "single", heading: "", align: "left", line: st.Style.create(), title_style: st.Style.create().bold(), fill: none }
  end

  fun styled(self, border: string) -> Block
    Block { border: border, heading: self.heading, align: self.align, line: self.line, title_style: self.title_style, fill: self.fill }
  end

  public fun single(self) -> Block
    self.styled("single")
  end

  public fun rounded(self) -> Block
    self.styled("rounded")
  end

  public fun double(self) -> Block
    self.styled("double")
  end

  public fun thick(self) -> Block
    self.styled("thick")
  end

  public fun ascii(self) -> Block
    self.styled("ascii")
  end

  --" No frame: the content gets the whole rectangle. --"
  public fun borderless(self) -> Block
    self.styled("none")
  end

  --" The text in the top line. --"
  public fun title(self, text: string) -> Block
    Block { border: self.border, heading: text, align: self.align, line: self.line, title_style: self.title_style, fill: self.fill }
  end

  --" Where the title sits in the top line: `"left"`, `"center"` or `"right"`. --"
  public fun title_align(self, align: string) -> Block
    Block { border: self.border, heading: self.heading, align: align, line: self.line, title_style: self.title_style, fill: self.fill }
  end

  --" The style of the lines of the frame. --"
  public fun border_style(self, style: st.Style) -> Block
    Block { border: self.border, heading: self.heading, align: self.align, line: style, title_style: self.title_style, fill: self.fill }
  end

  public fun title_style(self, style: st.Style) -> Block
    Block { border: self.border, heading: self.heading, align: self.align, line: self.line, title_style: style, fill: self.fill }
  end

  --" Paints the inside with this style (a background colour), spaces over what was there. --"
  public fun background(self, style: st.Style) -> Block
    Block { border: self.border, heading: self.heading, align: self.align, line: self.line, title_style: self.title_style, fill: style }
  end

  --" The rectangle left for the content inside `area`. --"
  public fun inner(self, area: l.Rect) -> l.Rect
    if self.border == "none" then
      return area
    end
    area.inner(1)
  end

  --" Draws the frame and the title in `area` and gives the rectangle for the content. --"
  public fun render(self, screen: b.Buffer, area: l.Rect) -> l.Rect
    let paint = self.fill
    if self.border == "none" then
      if paint != none then
        screen.fill(area.x, area.y, area.w, area.h, " ", paint)
      end
      return area
    end
    if area.w < 2 or area.h < 2 then
      return l.Rect.create(area.x, area.y, 0, 0)
    end
    if paint != none then
      screen.fill(area.x, area.y, area.w, area.h, " ", paint)
    end
    let g = glyphs(self.border)
    let right = area.x + area.w - 1
    let bottom = area.y + area.h - 1
    let across = ""
    for i in 0..(area.w - 2) do
      across += g[4]
    end
    screen.put(area.x, area.y, g[0] + across + g[1], self.line)
    screen.put(area.x, bottom, g[2] + across + g[3], self.line)
    for y in (area.y + 1)..bottom do
      screen.put(area.x, y, g[5], self.line)
      screen.put(right, y, g[5], self.line)
    end
    if self.heading != "" and area.w > 4 then
      let label = " " + tx.truncate(self.heading, area.w - 4) + " "
      let size = w.text_width(label)
      let start = area.x + 1
      if self.align == "right" then
        start = right - size
      elseif self.align == "center" then
        start = area.x + 1 + (area.w - 2 - size) div 2
      end
      screen.put(start, area.y, label, self.title_style)
    end
    area.inner(1)
  end
end

export Block
