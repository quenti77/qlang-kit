--" # Tabs

A row of titles with one active. `Left` and `Right` (and `Tab` / `Shift+Tab`) change the active one,
the digits `1` to `9` jump to it, a click on a title selects it.

```
let tabs = Tabs.create(["Routes", "Queries", "Logs"])
tabs.handle(event)
tabs.render(screen, area)
tabs.active                                    -- 0, 1, 2
```
--"
import "buffer.q" as b
import "layout.q" as l
import "style.q" as st
import "theme.q" as th
import "text.q" as tx
import "width.q" as w

--" Titles side by side. --"
struct Tabs
  titles: array<string>
  --" The index of the active tab. --"
  public active: int
end

impl Tabs
  public fun create(titles: array<string>) -> Tabs
    Tabs { titles: titles, active: 0 }
  end

  public fun select(self, index: int)
    let last = self.titles.len() - 1
    self.active = if last < 0 or index < 0 then 0 elseif index > last then last else index end
  end

  public fun active_title(self) -> string
    if self.titles.is_empty() then
      return ""
    end
    self.titles[self.active]
  end

  fun rotate(self, delta: int)
    let n = self.titles.len()
    if n > 0 then
      self.active = (self.active + delta + n) % n
    end
  end

  --" Uses the event if it changes the active tab. --"
  public fun handle(self, ev: Event) -> bool
    if ev.kind != "key" or ev.ctrl or ev.alt then
      return false
    end
    if ev.key == "Right" or (ev.key == "Tab" and not ev.shift) then
      self.rotate(1)
    elseif ev.key == "Left" or (ev.key == "Tab" and ev.shift) then
      self.rotate(-1)
    elseif ev.key.chars().len() == 1 and ev.key >= "1" and ev.key <= "9" and (int.parse(ev.key) ?? 0) <= self.titles.len() then
      self.select((int.parse(ev.key) ?? 1) - 1)
    else
      return false
    end
    true
  end

  -- the label of a tab: its number and its title
  fun label(self, i: int) -> string
    " " + self.titles[i] + " "
  end

  --" Selects the tab under a click on the row where the tabs were drawn at `area`. --"
  public fun click(self, area: l.Rect, ev: Event) -> bool
    if ev.kind != "mouse" or ev.action != "down" or not area.contains(ev.x, ev.y) then
      return false
    end
    let x = area.x
    for i in 0..self.titles.len() do
      let size = w.text_width(self.label(i))
      if ev.x >= x and ev.x < x + size then
        self.active = i
        return true
      end
      x += size + 1
    end
    false
  end

  --" Draws the titles in the first row of `area`: the active one reversed. Titles that do not fit are cut. --"
  public fun render(self, screen: b.Buffer, area: l.Rect)
    if area.is_empty() then
      return
    end
    let x = area.x
    for i in 0..self.titles.len() do
      let room = area.x + area.w - x
      if room <= 0 then
        break
      end
      let style = if i == self.active then th.selected().bold() else st.Style.create().dim() end
      screen.put(x, area.y, tx.truncate(self.label(i), room), style)
      x += w.text_width(self.label(i)) + 1
    end
  end
end

export Tabs
