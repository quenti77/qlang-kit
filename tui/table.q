--" # Table

Rows and columns with a header, one row selected, scrolling like a `List`. Columns have a title, a
size (`Size.fixed(12)`, `Size.fill(1)`...) and an alignment.

```
let users = Table.create([
    Column.create("id", Size.fixed(5)).align("right"),
    Column.create("name", Size.fill(1)),
    Column.create("email", Size.fill(2)),
])
users.set_rows([["1", "Ada", "ada@example.org"], ["2", "Bob", "bob@example.org"]])
users.handle(event)
users.render(screen, area, true)
users.selected_row()                         -- ["1", "Ada", "ada@example.org"]
users.sort_by(1, false)                      -- by name, ascending
```
--"
import "buffer.q" as b
import "layout.q" as l
import "list.q" as li
import "style.q" as st
import "text.q" as tx

--" A column: its title, its size and where its text sits. --"
struct Column
  public title: string
  public size: l.Size
  public where_to: string
end

impl Column
  public fun create(title: string, size: l.Size) -> Column
    Column { title: title, size: size, where_to: "left" }
  end

  --" `"left"`, `"right"` or `"center"`. --"
  public fun align(self, side: string) -> Column
    Column { title: self.title, size: self.size, where_to: side }
  end
end

--" Rows of text under a header. --"
struct Table
  columns: array<Column>
  rows: array<array<string>>
  --" The index of the selected row. --"
  public selected: int
  offset: int
  page: int
  sorted: int
  descending: bool
end

impl Table
  public fun create(columns: array<Column>) -> Table
    Table { columns: columns, rows: [], selected: 0, offset: 0, page: 10, sorted: -1, descending: false }
  end

  public fun len(self) -> int
    self.rows.len()
  end

  --" The first cell of the first row (what a test looks at to see the order). --"
  public fun rows_first(self) -> string
    if self.rows.is_empty() or self.rows[0].is_empty() then
      return ""
    end
    self.rows[0][0]
  end

  --" Replaces the rows (the selection stays on the same number, brought back into the table). --"
  public fun set_rows(self, rows: array<array<string>>)
    self.rows = rows
    if self.sorted >= 0 then
      self.sort_by(self.sorted, self.descending)
    end
    self.move_to(self.selected)
  end

  --" The selected row, or an empty array when there is none. --"
  public fun selected_row(self) -> array<string>
    if self.rows.is_empty() then
      return []
    end
    self.rows[self.selected]
  end

  public fun move_to(self, index: int)
    let last = self.rows.len() - 1
    if last < 0 then
      self.selected = 0
      self.offset = 0
      return
    end
    self.selected = if index < 0 then 0 elseif index > last then last else index end
  end

  public fun move(self, delta: int)
    self.move_to(self.selected + delta)
  end

  --" Sorts by a column (text order, numbers by value when the whole column is numbers). --"
  public fun sort_by(self, column: int, descending: bool)
    if column < 0 or column >= self.columns.len() then
      return
    end
    let numbers = true
    for row in self.rows do
      if column < row.len() and float.parse(row[column]) == none then
        numbers = false
      end
    end
    let keyed = fun(row: array<string>) -> string
      let cell = if column < row.len() then row[column] else "" end
      if numbers then
        let n = float.parse(cell) ?? 0.0
        -- a sortable text for a number: sign, then the digits padded
        return number_key(n)
      end
      cell.lower()
    end
    self.rows.sort_by(fun(a: array<string>, b: array<string>) -> int
      let x = keyed(a)
      let y = keyed(b)
      if x < y then -1 elseif x > y then 1 else 0 end
    end)
    if descending then
      self.rows.reverse()
    end
    self.sorted = column
    self.descending = descending
  end

  --" Uses the event if it moves the selection (the same keys as `List`). --"
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
      self.move_to(self.rows.len() - 1)
    else
      return false
    end
    true
  end

  fun widths(self, total: int) -> array<int>
    let sizes = self.columns.map(fun(c: Column) -> l.Size c.size end)
    l.Rect.create(0, 0, total, 1).split_row(sizes, 1).map(fun(r: l.Rect) -> int r.w end)
  end

  --" Draws the header and the rows that fit in `area`. --"
  public fun render(self, screen: b.Buffer, area: l.Rect, focused: bool)
    if area.is_empty() then
      return
    end
    let body = area.h - 1
    self.page = if body < 1 then 1 else body end
    if self.selected < self.offset then
      self.offset = self.selected
    end
    if self.selected >= self.offset + body then
      self.offset = self.selected - body + 1
    end
    let bar = self.rows.len() > body
    let total = if bar then area.w - 1 else area.w end
    let widths = self.widths(total)
    let header = st.Style.create().bold().underline()
    let x = area.x
    for i in 0..self.columns.len() do
      let mark = if i == self.sorted then (if self.descending then " ▼" else " ▲" end) else "" end
      let column = self.columns[i]
      screen.put(x, area.y, tx.fit(column.title + mark, widths[i], column.where_to), header)
      x += widths[i] + 1
    end
    for row in 0..body do
      let index = self.offset + row
      if index >= self.rows.len() then
        break
      end
      let chosen = index == self.selected
      let style = if chosen and focused then st.Style.create().reverse() elseif chosen then st.Style.create().bold() else st.Style.create() end
      if chosen then
        screen.fill(area.x, area.y + 1 + row, total, 1, " ", style)
      end
      let cx = area.x
      for i in 0..self.columns.len() do
        let cell = if i < self.rows[index].len() then self.rows[index][i] else "" end
        screen.put(cx, area.y + 1 + row, tx.fit(cell, widths[i], self.columns[i].where_to), style)
        cx += widths[i] + 1
      end
    end
    if bar then
      li.scrollbar(screen, area.x + area.w - 1, area.y + 1, body, self.rows.len(), self.offset)
    end
  end
end

-- numbers as text that sorts like the numbers: 0 or 1 for the sign, then 20 digits
fun number_key(n: float) -> string
  let whole = (if n < 0.0 then 0.0 - n else n end) as int
  let digits = "{whole}"
  let padded = ""
  for i in 0..(20 - digits.len()) do
    padded += "0"
  end
  if n < 0.0 then
    -- negative numbers sort before, and the larger the magnitude the smaller the key
    let flipped = ""
    for ch in (padded + digits).chars() do
      flipped += "{9 - (int.parse(ch) ?? 0)}"
    end
    return "0" + flipped
  end
  "1" + padded + digits
end

export Column, Table
