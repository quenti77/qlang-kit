--" # List

A column of lines with one selected, which scrolls to keep it visible. `handle` takes an `Event` (the
arrows, `PageUp`, `PageDown`, `Home`, `End`, `j` and `k`, the mouse wheel) and says whether it used it.

```
let routes = List.create(["GET /", "POST /login", "GET /users"])
routes.handle(event)                        -- moves the selection
routes.render(screen, area, true)           -- draws it; `true` when the list has the focus
routes.selected_item()                      -- "GET /" (or none for an empty list)
```
--"
import "buffer.q" as b
import "layout.q" as l
import "style.q" as st
import "theme.q" as th
import "text.q" as tx

--" Draws a vertical scroll bar of `height` rows at column `x` when `count` lines do not fit. --"
fun scrollbar(screen: b.Buffer, x: int, y: int, height: int, count: int, offset: int)
  if height <= 0 or count <= height then
    return
  end
  let track = st.Style.create().dim()
  let thumb = height * height div count
  let size = if thumb < 1 then 1 else thumb end
  let room = height - size
  let top = if count - height == 0 then 0 else offset * room div (count - height) end
  for i in 0..height do
    let inside = i >= top and i < top + size
    screen.put(x, y + i, if inside then "█" else "│" end, if inside then st.Style.create() else track end)
  end
end

--" Lines to choose from. --"
struct List
  items: array<string>
  --" The index of the selected line (0 when the list is empty). --"
  public selected: int
  offset: int
  page: int
  marker: string
end

impl List
  public fun create(items: array<string>) -> List
    List { items: items, selected: 0, offset: 0, page: 10, marker: "› " }
  end

  --" Replaces the lines; the selection stays on the same number, brought back into the list. --"
  public fun set_items(self, items: array<string>)
    self.items = items
    self.move_to(self.selected)
  end

  public fun len(self) -> int
    self.items.len()
  end

  --" The selected line, or `none` for an empty list. --"
  public fun selected_item(self) -> string?
    if self.items.is_empty() then
      return none
    end
    self.items[self.selected]
  end

  --" Selects the line number `index` (brought back into the list). --"
  public fun move_to(self, index: int)
    let last = self.items.len() - 1
    if last < 0 then
      self.selected = 0
      self.offset = 0
      return
    end
    self.selected = if index < 0 then 0 elseif index > last then last else index end
  end

  --" Moves the selection by `delta` lines (negative goes up). --"
  public fun move(self, delta: int)
    self.move_to(self.selected + delta)
  end

  --" Uses the event if it moves the selection. --"
  public fun handle(self, ev: Event) -> bool
    if ev.kind == "mouse" then
      if ev.action == "scroll_down" then
        self.move(3)
        return true
      end
      if ev.action == "scroll_up" then
        self.move(-3)
        return true
      end
      return false
    end
    if ev.kind != "key" or ev.ctrl or ev.alt then
      return false
    end
    if ev.key == "Down" or ev.key == "j" then
      self.move(1)
    elseif ev.key == "Up" or ev.key == "k" then
      self.move(-1)
    elseif ev.key == "PageDown" then
      self.move(self.page)
    elseif ev.key == "PageUp" then
      self.move(0 - self.page)
    elseif ev.key == "Home" or ev.key == "g" then
      self.move_to(0)
    elseif ev.key == "End" or ev.key == "G" then
      self.move_to(self.items.len() - 1)
    else
      return false
    end
    true
  end

  --" Selects the line under a click inside `area`; says whether it did. --"
  public fun click(self, area: l.Rect, ev: Event) -> bool
    if ev.kind != "mouse" or ev.action != "down" or not area.contains(ev.x, ev.y) then
      return false
    end
    let index = self.offset + ev.y - area.y
    if index >= self.items.len() then
      return false
    end
    self.move_to(index)
    true
  end

  --" Draws the lines that fit in `area`. The selected one is reversed when the list has the focus,
    only marked when it has not. --"
  public fun render(self, screen: b.Buffer, area: l.Rect, focused: bool)
    if area.is_empty() then
      return
    end
    self.page = area.h
    if self.selected < self.offset then
      self.offset = self.selected
    end
    if self.selected >= self.offset + area.h then
      self.offset = self.selected - area.h + 1
    end
    let bar = self.items.len() > area.h
    let width = if bar then area.w - 1 else area.w end
    for row in 0..area.h do
      let index = self.offset + row
      if index >= self.items.len() then
        break
      end
      let chosen = index == self.selected
      let style = if chosen and focused then th.selected() elseif chosen then st.Style.create().bold() else st.Style.create() end
      let prefix = if chosen then self.marker else "  " end
      screen.put(area.x, area.y + row, tx.fit(prefix + self.items[index], width, "left"), style)
    end
    if bar then
      scrollbar(screen, area.x + area.w - 1, area.y, area.h, self.items.len(), self.offset)
    end
  end
end

export List, scrollbar
