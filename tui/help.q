--" # Help bar

The line of key hints at the bottom of a screen: `q quit  ↑↓ move  enter open`.

```
let help = HelpBar.create([["q", "quit"], ["↑↓", "move"], ["enter", "open"]])
help.render(screen, area)
```
Hints that do not fit are left out (the first ones have priority), with `…` to say so.
--"
import "buffer.q" as b
import "layout.q" as l
import "style.q" as st
import "width.q" as w

--" Pairs of a key and what it does. --"
struct HelpBar
  hints: array<array<string>>
end

impl HelpBar
  --" Each hint is `[key, what it does]`. --"
  public fun create(hints: array<array<string>>) -> HelpBar
    HelpBar { hints: hints }
  end

  public fun set(self, hints: array<array<string>>)
    self.hints = hints
  end

  --" Draws the hints on the first row of `area`. --"
  public fun render(self, screen: b.Buffer, area: l.Rect)
    if area.is_empty() then
      return
    end
    let x = area.x
    let end_x = area.x + area.w
    for i in 0..self.hints.len() do
      let key = self.hints[i][0]
      let what = " " + self.hints[i][1]
      let size = w.text_width(key) + w.text_width(what)
      let more = i + 1 < self.hints.len()
      if x + size > end_x - (if more then 3 else 0 end) then
        screen.put(x, area.y, "…", st.Style.create().dim())
        return
      end
      screen.put(x, area.y, key, st.Style.create().bold())
      screen.put(x + w.text_width(key), area.y, what, st.Style.create().dim())
      x += size + 2
    end
  end
end

export HelpBar
