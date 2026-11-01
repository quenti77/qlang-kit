--" # Layout

The screen is cut into **rectangles**. A `Rect` is a position and a size, in characters; `split_row` cuts
one into columns side by side, and `split_column` into rows one above the other, according to **sizes**:
a fixed number of characters, a percentage, or a share of what is left (`fill`).

```
let screen = Rect.create(0, 0, 80, 24)
let parts = screen.split_column([Size.fixed(1), Size.fill(1), Size.fixed(1)], 0)   -- title, body, status bar
let body = parts[1].split_row([Size.percent(30), Size.fill(1)], 1)                -- a menu and a content
let dialog = screen.center(40, 10)
```

Rectangles never go negative, and what does not fit is cut: a layout in a terminal that is too small
gives empty rectangles instead of failing.
--"

--" How much room a part takes. --"
struct Size
  public kind: string
  public value: int
end

impl Size
  --" Exactly `n` characters (less if there is no room). --"
  public fun fixed(n: int) -> Size
    Size { kind: "fixed", value: if n < 0 then 0 else n end }
  end

  --" `p` percent of the room (before the gaps are taken off). --"
  public fun percent(p: int) -> Size
    Size { kind: "percent", value: if p < 0 then 0 elseif p > 100 then 100 else p end }
  end

  --" A share of what the other parts leave: `fill(2)` gets twice what `fill(1)` gets. --"
  public fun fill(weight: int) -> Size
    Size { kind: "fill", value: if weight < 1 then 1 else weight end }
  end
end

-- the lengths of the parts of a line `total` long, with `gap` between them
fun allocate(total: int, sizes: array<Size>, gap: int) -> array<int>
  let n = sizes.len()
  let lengths: array<int> = []
  for _i in 0..n do
    lengths.push(0)
  end
  if n == 0 then
    return lengths
  end
  let gaps = gap * (n - 1)
  let room = if total - gaps < 0 then 0 else total - gaps end
  let left = room
  let weight = 0
  for i in 0..n do
    let s = sizes[i]
    if s.kind == "fill" then
      weight += s.value
      continue
    end
    let want = if s.kind == "percent" then room * s.value div 100 else s.value end
    let got = if want > left then left else want end
    lengths[i] = got
    left -= got
  end
  if weight > 0 then
    let given = 0
    let last = -1
    for i in 0..n do
      if sizes[i].kind == "fill" then
        lengths[i] = left * sizes[i].value div weight
        given += lengths[i]
        last = i
      end
    end
    -- what the divisions left over goes to the last part that grows
    lengths[last] += left - given
  end
  lengths
end

--" A rectangle of the screen: the column and the row of its top left corner (from 0), its width and its
height. --"
struct Rect
  public x: int
  public y: int
  public w: int
  public h: int
end

impl Rect
  --" A rectangle; a negative width or height is 0. --"
  public fun create(x: int, y: int, w: int, h: int) -> Rect
    Rect { x: x, y: y, w: if w < 0 then 0 else w end, h: if h < 0 then 0 else h end }
  end

  --" The column after the last one. --"
  public fun right(self) -> int
    self.x + self.w
  end

  --" The row after the last one. --"
  public fun bottom(self) -> int
    self.y + self.h
  end

  public fun is_empty(self) -> bool
    self.w == 0 or self.h == 0
  end

  --" Whether the cell at this column and row is inside. --"
  public fun contains(self, px: int, py: int) -> bool
    px >= self.x and px < self.x + self.w and py >= self.y and py < self.y + self.h
  end

  --" Takes `top`, `right`, `bottom` and `left` characters off the sides. --"
  public fun shrink(self, top: int, right: int, bottom: int, left: int) -> Rect
    Rect.create(self.x + left, self.y + top, self.w - left - right, self.h - top - bottom)
  end

  --" Takes `n` characters off every side. --"
  public fun inner(self, n: int) -> Rect
    self.shrink(n, n, n, n)
  end

  --" A rectangle of this size in the middle (cut to this one if it is bigger). --"
  public fun center(self, w: int, h: int) -> Rect
    let cw = if w > self.w then self.w else w end
    let ch = if h > self.h then self.h else h end
    Rect.create(self.x + (self.w - cw) div 2, self.y + (self.h - ch) div 2, cw, ch)
  end

  --" What the two rectangles have in common (an empty rectangle if nothing). --"
  public fun intersect(self, other: Rect) -> Rect
    let left = if self.x > other.x then self.x else other.x end
    let top = if self.y > other.y then self.y else other.y end
    let right = if self.right() < other.right() then self.right() else other.right() end
    let bottom = if self.bottom() < other.bottom() then self.bottom() else other.bottom() end
    Rect.create(left, top, right - left, bottom - top)
  end

  --" Cuts into columns side by side, with `gap` characters between them. --"
  public fun split_row(self, sizes: array<Size>, gap: int) -> array<Rect>
    let lengths = allocate(self.w, sizes, gap)
    let out: array<Rect> = []
    let at = self.x
    for len in lengths do
      out.push(Rect.create(at, self.y, len, self.h))
      at += len + gap
    end
    out
  end

  --" Cuts into rows one above the other, with `gap` lines between them. --"
  public fun split_column(self, sizes: array<Size>, gap: int) -> array<Rect>
    let lengths = allocate(self.h, sizes, gap)
    let out: array<Rect> = []
    let at = self.y
    for len in lengths do
      out.push(Rect.create(self.x, at, self.w, len))
      at += len + gap
    end
    out
  end

  --" A grid of `rows` by `cols` equal cells, row by row. --"
  public fun grid(self, rows: int, cols: int) -> array<Rect>
    let out: array<Rect> = []
    if rows < 1 or cols < 1 then
      return out
    end
    let sizes_r: array<Size> = []
    for _i in 0..rows do
      sizes_r.push(Size.fill(1))
    end
    let sizes_c: array<Size> = []
    for _i in 0..cols do
      sizes_c.push(Size.fill(1))
    end
    for line in self.split_column(sizes_r, 0) do
      for cell in line.split_row(sizes_c, 0) do
        out.push(cell)
      end
    end
    out
  end
end

export Rect, Size
