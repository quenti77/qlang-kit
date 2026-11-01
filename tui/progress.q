--" # Progress bar and spinner

```
Progress.draw(screen, area, 0.42, style)       -- "██████▍       42%"
let spin = Spinner.create()
spin.tick()                                    -- once per frame
screen.put(0, 0, spin.frame(), style)          -- "⠋", "⠙", "⠹"...
```
--"
import "buffer.q" as b
import "layout.q" as l
import "style.q" as st
import "text.q" as tx

--" A bar that fills from the left. --"
struct Progress
end

impl Progress
  --" The bar as text, `width` columns wide, for a `ratio` from 0.0 to 1.0 (values outside are brought back). Eighths of a
    column are drawn with the partial blocks, so the bar moves smoothly. --"
  public fun bar(ratio: float, width: int) -> string
    let r = if ratio < 0.0 then 0.0 elseif ratio > 1.0 then 1.0 else ratio end
    let eighths = (r * width as float * 8.0) as int
    let full = eighths div 8
    let rest = eighths % 8
    let parts = [" ", "▏", "▎", "▍", "▌", "▋", "▊", "▉"]
    let out = ""
    for _i in 0..full do
      out += "█"
    end
    if full < width then
      out += parts[rest]
      for _i in 0..(width - full - 1) do
        out += " "
      end
    end
    out
  end

  --" Draws the bar in the first row of `area`, followed by the percentage when there is room. --"
  public fun draw(screen: b.Buffer, area: l.Rect, ratio: float, style: st.Style)
    if area.is_empty() then
      return
    end
    let r = if ratio < 0.0 then 0.0 elseif ratio > 1.0 then 1.0 else ratio end
    let percent = tx.fit("{(r * 100.0) as int}%", 4, "right")
    if area.w >= 12 then
      screen.put(area.x, area.y, Progress.bar(r, area.w - 5), style)
      screen.put(area.x + area.w - 4, area.y, percent, st.Style.create())
    else
      screen.put(area.x, area.y, Progress.bar(r, area.w), style)
    end
  end
end

--" A character that turns, to say that something is happening. --"
struct Spinner
  step_count: int
  frames: array<string>
end

impl Spinner
  public fun create() -> Spinner
    Spinner { step_count: 0, frames: ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"] }
  end

  --" Moves to the next picture. --"
  public fun tick(self)
    self.step_count = (self.step_count + 1) % self.frames.len()
  end

  public fun frame(self) -> string
    self.frames[self.step_count]
  end
end

export Progress, Spinner
