--" # Styles and colours

A **colour** is an `int`: `0` is the terminal's own colour, `1` to `256` are the 256 palette colours
(`Color.indexed(n)`, `Color.ansi(n)`), and above that comes true colour (`Color.rgb(r, g, b)`). A
**style** is a foreground, a background and some attributes (bold, italic...). The terminal may show
fewer colours than asked: `sgr` turns a colour into the closest one the terminal has (`Term.colors()`).

```
let warning = Style.create().fg(Color.rgb(255, 170, 0)).bold()
warning.sgr(256)               -- "\e[0;1;38;5;214m"
```
--"

--" Makes colours. --"
struct Color
end

impl Color
  --" The colour of the terminal itself. --"
  public fun default() -> int
    0
  end

  --" One of the 16 first colours: 0 black, 1 red, 2 green, 3 yellow, 4 blue, 5 magenta, 6 cyan, 7 white,
    and 8 to 15 their bright versions. --"
  public fun ansi(n: int) -> int
    clamp(n, 15) + 1
  end

  --" A colour of the 256 colours palette (16 to 231 the colour cube, 232 to 255 the greys). --"
  public fun indexed(n: int) -> int
    clamp(n, 255) + 1
  end

  --" A true colour, each part from 0 to 255 (a value outside is brought back to that range). --"
  public fun rgb(r: int, g: int, b: int) -> int
    257 + clamp(r, 255) * 65536 + clamp(g, 255) * 256 + clamp(b, 255)
  end

  --" The colour `#rrggbb`, or the default colour if the text is not that. --"
  public fun hex(text: string) -> int
    if not regex.matches(text, "^#[0-9a-fA-F]\{6\}$") then
      return 0
    end
    Color.rgb(hex_part(text.substring(1, 3)), hex_part(text.substring(3, 5)), hex_part(text.substring(5, 7)))
  end
end

fun clamp(n: int, high: int) -> int
  if n < 0 then
    0
  elseif n > high then
    high
  else
    n
  end
end

fun hex_part(two: string) -> int
  let digits = "0123456789abcdef"
  let lower = two.lower()
  (digits.index_of(lower.substring(0, 1)) ?? 0) * 16 + (digits.index_of(lower.substring(1, 2)) ?? 0)
end

-- the red, green and blue of a colour that is not the default one
fun to_rgb(color: int) -> array<int>
  if color >= 257 then
    let v = color - 257
    return [v div 65536, (v div 256) % 256, v % 256]
  end
  let n = color - 1
  if n < 16 then
    let base = [[0, 0, 0], [205, 0, 0], [0, 205, 0], [205, 205, 0], [0, 0, 238], [205, 0, 205], [0, 205, 205], [229, 229, 229], [127, 127, 127], [255, 0, 0], [0, 255, 0], [255, 255, 0], [92, 92, 255], [255, 0, 255], [0, 255, 255], [255, 255, 255]]
    return base[n]
  end
  if n < 232 then
    let c = n - 16
    let level = fun(l: int) -> int
      if l == 0 then 0 else 55 + 40 * l end
    end
    return [level(c div 36), level((c div 6) % 6), level(c % 6)]
  end
  let grey = 8 + 10 * (n - 232)
  [grey, grey, grey]
end

-- the closest of the 256 palette colours (0 to 255) to a true colour
fun rgb_to_256(r: int, g: int, b: int) -> int
  if r == g and g == b then
    if r < 8 then
      return 16
    end
    if r > 248 then
      return 231
    end
    return 232 + (r - 8) * 24 div 247
  end
  let level = fun(v: int) -> int
    if v < 48 then
      0
    elseif v < 115 then
      1
    else
      (v - 35) div 40
    end
  end
  16 + 36 * level(r) + 6 * level(g) + level(b)
end

-- the closest of the 16 first colours (0 to 15) to a true colour
fun rgb_to_16(r: int, g: int, b: int) -> int
  let top = if r > g and r > b then r elseif g > b then g else b end
  if top < 64 then
    return 0
  end
  let base = (if r >= 128 then 1 else 0 end) + (if g >= 128 then 2 else 0 end) + (if b >= 128 then 4 else 0 end)
  if base == 0 then
    return 8
  end
  if top >= 192 then base + 8 else base end
end

-- the SGR parameters of a colour: `layer` is 30 for the foreground and 40 for the background
fun color_code(color: int, layer: int, depth: int) -> string
  if color == 0 or depth <= 0 then
    return ""
  end
  let rgb = to_rgb(color)
  if color >= 257 and depth >= 16777216 then
    return "{layer + 8};2;{rgb[0]};{rgb[1]};{rgb[2]}"
  end
  let n = if color >= 257 then rgb_to_256(rgb[0], rgb[1], rgb[2]) else color - 1 end
  if depth >= 256 then
    return "{layer + 8};5;{n}"
  end
  let small = if n < 16 then n else rgb_to_16(rgb[0], rgb[1], rgb[2]) end
  if small < 8 then "{layer + small}" else "{layer + 60 + small - 8}" end
end

--" Foreground, background and attributes. A style never changes: `bold()` and the others give a new one. --"
struct Style
  public fg: int = 0
  public bg: int = 0
  public attrs: int = 0
end

impl Style
  --" The style of the terminal itself. --"
  public fun create() -> Style
    Style { fg: 0, bg: 0, attrs: 0 }
  end

  public fun fg(self, color: int) -> Style
    Style { fg: color, bg: self.bg, attrs: self.attrs }
  end

  public fun bg(self, color: int) -> Style
    Style { fg: self.fg, bg: color, attrs: self.attrs }
  end

  fun with_attr(self, bit: int) -> Style
    if self.has(bit) then
      return self
    end
    Style { fg: self.fg, bg: self.bg, attrs: self.attrs + bit }
  end

  fun has(self, bit: int) -> bool
    (self.attrs div bit) % 2 == 1
  end

  public fun bold(self) -> Style
    self.with_attr(1)
  end

  public fun dim(self) -> Style
    self.with_attr(2)
  end

  public fun italic(self) -> Style
    self.with_attr(4)
  end

  public fun underline(self) -> Style
    self.with_attr(8)
  end

  --" Swaps the foreground and the background. --"
  public fun reverse(self) -> Style
    self.with_attr(16)
  end

  public fun strike(self) -> Style
    self.with_attr(32)
  end

  --" One number for the style, to compare two styles or keep one in a table. --"
  public fun key(self) -> int
    (self.fg * 33554432 + self.bg) * 64 + self.attrs
  end

  --" The style a `key` stands for. --"
  public fun of_key(k: int) -> Style
    Style { fg: (k div 64) div 33554432, bg: (k div 64) % 33554432, attrs: k % 64 }
  end

  --" The escape sequence that gives this style, whatever the one before it was. `depth` is the number
    of colours the terminal shows (`Term.colors()`): colours are brought back to what it has, and with
    `0` only the attributes are kept. --"
  public fun sgr(self, depth: int) -> string
    let parts = ["0"]
    let codes = ["1", "2", "3", "4", "7", "9"]
    let bits = [1, 2, 4, 8, 16, 32]
    for i in 0..6 do
      if self.has(bits[i]) then
        parts.push(codes[i])
      end
    end
    let front = color_code(self.fg, 30, depth)
    if front != "" then
      parts.push(front)
    end
    let back = color_code(self.bg, 40, depth)
    if back != "" then
      parts.push(back)
    end
    "\e[" + parts.join(";") + "m"
  end
end

export Color, Style
