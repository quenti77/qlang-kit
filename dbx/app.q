--" # The database browser

`kit db --url sqlite://app.db` opens a database in the terminal: its tables, the rows of a table (a page at a time),
its structure, a place to type SQL, and the migrations that were applied.

| Key | Does |
| --- | --- |
| `Tab` | moves between the list of tables and the content |
| `1` `2` `3` `4` | Rows, Structure, SQL, Migrations |
| `n` `p` | next / previous page of rows; `←` `→` scroll the columns |
| `Ctrl+R` or `F5` | runs the SQL that is typed (the SQL tab) |
| `r` | reads the database again |
| `q` | quits (not while typing SQL) |

It only **reads**, unless it is started with `--write`.
--"
import "../tui/app.q" as ap
import "../tui/block.q" as bk
import "../tui/buffer.q" as b
import "../tui/help.q" as hp
import "../tui/keys.q" as k
import "../tui/layout.q" as l
import "../tui/list.q" as li
import "../tui/style.q" as st
import "../tui/table.q" as tb
import "../tui/tabs.q" as ts
import "../tui/text.q" as tx
import "../tui/textarea.q" as ta
import "catalog.q" as cat

--" A table of text with the widths the content needs (at most 24), from column `first`. --"
fun make_table(names: array<string>, rows: array<array<string>>, first: int) -> tb.Table
  let columns: array<tb.Column> = []
  for i in first..names.len() do
    let widest = names[i].chars().len()
    for row in rows do
      if i < row.len() and row[i].chars().len() > widest then
        widest = row[i].chars().len()
      end
    end
    columns.push(tb.Column.create(names[i], l.Size.fixed(if widest > 24 then 24 else widest end)))
  end
  let table = tb.Table.create(columns)
  table.set_rows(rows.map(fun(r: array<string>) -> array<string> r.slice(first, r.len()) end))
  table
end

--" The migrations in `files` (`migrations/20261030_create_users.q`) that the table `schema_migrations` does not list. --"
fun pending(applied: array<string>, files: array<string>) -> array<string>
  let out: array<string> = []
  for f in files do
    let stem = f.substring(0, f.len() - 2).split("/")
    let id = stem[stem.len() - 1]
    if not applied.contains(id) then
      out.push(id)
    end
  end
  out
end

--" The state of the browser. --"
struct Browser
  public db: Db
  public driver: string
  public url: string
  public write: bool
  public files: fun() -> array<string>
  public tables: li.List
  public names: array<string>
  public tabs: ts.Tabs
  public focus: k.FocusRing
  public rows: tb.Table
  public structure: tb.Table
  public sql: ta.TextArea
  public result: tb.Table
  public migrations: tb.Table
  public names_of_columns: array<string>
  public all_rows: array<array<string>>
  public page: int
  public total: int
  public first_column: int
  public message: string
  public ran: string
end

fun page_size() -> int
  50
end

fun create(db: Db, url: string, write: bool, files: fun() -> array<string>) -> Browser
  let listed = cat.tables(db, cat.driver_of(url))
  let names: array<string> = []
  if listed.is_ok() then
    names = listed.unwrap()
  end
  let empty = make_table([], [], 0)
  let b = Browser {
    db: db,
    driver: cat.driver_of(url),
    url: url,
    write: write,
    files: files,
    tables: li.List.create(names),
    names: names,
    tabs: ts.Tabs.create(["1 Rows", "2 Structure", "3 SQL", "4 Migrations"]),
    focus: k.FocusRing.create(["tables", "content"]),
    rows: empty,
    structure: empty,
    sql: ta.TextArea.create(),
    result: empty,
    migrations: empty,
    names_of_columns: [],
    all_rows: [],
    page: 1,
    total: 0,
    first_column: 0,
    message: if listed.is_err() then listed.unwrap_err().message else "" end,
    ran: "",
  }
  load_table(b)
  load_migrations(b)
  b
end

fun current(b: Browser) -> string
  b.tables.selected_item() ?? ""
end

--" Reads the rows and the structure of the selected table. --"
fun load_table(b: Browser)
  let table = current(b)
  if table == "" then
    return
  end
  let page = cat.rows_page(b.db, b.driver, table, page_size(), b.page)
  if page.is_err() then
    b.message = page.unwrap_err().message
    return
  end
  b.names_of_columns = page.unwrap().columns
  b.all_rows = page.unwrap().rows
  b.total = page.unwrap().total
  b.rows = make_table(b.names_of_columns, b.all_rows, b.first_column)
  let cols = cat.columns(b.db, b.driver, table)
  if cols.is_ok() then
    b.structure = make_table(["Column", "Type", "Null", "Key", "Default"], cols.unwrap().map(fun(c: cat.Column) -> array<string> [c.name, c.kind, if c.nullable then "yes" else "no" end, if c.primary then "PRI" else "" end, c.default] end), 0)
  end
  b.message = ""
end

fun load_migrations(b: Browser)
  if not b.names.contains("schema_migrations") then
    b.migrations = make_table(["Migration", "State"], b.files().map(fun(f: string) -> array<string> [f, "no schema_migrations table yet"] end), 0)
    return
  end
  let found = cat.run_sql(b.db, "SELECT id FROM schema_migrations ORDER BY id", false)
  let applied: array<string> = []
  let rows: array<array<string>> = []
  if found.is_ok() then
    for r in found.unwrap().rows do
      applied.push(r[0])
      rows.push([r[0], "applied"])
    end
  end
  for id in pending(applied, b.files()) do
    rows.push([id, "pending"])
  end
  b.migrations = make_table(["Migration", "State"], rows, 0)
end

fun total_pages(b: Browser) -> int
  if b.total == 0 then 1 else (b.total + page_size() - 1) div page_size() end
end

fun run_typed(b: Browser)
  let done = cat.run_sql(b.db, b.sql.text(), b.write)
  if done.is_err() then
    b.message = done.unwrap_err().message
    b.ran = ""
    return
  end
  b.message = ""
  b.ran = "{done.unwrap().total} row(s)"
  b.result = make_table(done.unwrap().columns, done.unwrap().rows, 0)
  load_table(b)
end

impl ap.Program for Browser
  public fun update(self, ev: Event, ctx: ap.Context)
    let editing = self.tabs.active == 2 and self.focus.has("content")
    if ev.kind == "key" and ev.key == "Tab" and not ev.shift then
      self.focus.next()
      return
    end
    if editing then
      if ev.kind == "key" and ((ev.ctrl and ev.key == "r") or ev.key == "F5") then
        run_typed(self)
        return
      end
      if ev.kind == "key" and ev.key == "Esc" then
        self.focus.focus("tables")
        return
      end
      self.sql.handle(ev)
      return
    end
    if ev.kind == "key" and not ev.ctrl and not ev.alt then
      if ev.key == "q" then
        ctx.quit()
        return
      end
      if ev.key == "r" then
        load_table(self)
        load_migrations(self)
        return
      end
      if ev.key >= "1" and ev.key <= "4" and ev.key.chars().len() == 1 then
        self.tabs.select((int.parse(ev.key) ?? 1) - 1)
        return
      end
      if ev.key == "n" and self.page < total_pages(self) then
        self.page += 1
        load_table(self)
        return
      end
      if ev.key == "p" and self.page > 1 then
        self.page -= 1
        load_table(self)
        return
      end
      if self.focus.has("content") and self.tabs.active == 0 and (ev.key == "Left" or ev.key == "Right") then
        let max = self.names_of_columns.len() - 1
        self.first_column = if ev.key == "Right" then (if self.first_column < max then self.first_column + 1 else max end) else (if self.first_column > 0 then self.first_column - 1 else 0 end) end
        self.rows = make_table(self.names_of_columns, self.all_rows, self.first_column)
        return
      end
    end
    if self.focus.has("tables") then
      let before = self.tables.selected
      self.tables.handle(ev)
      if self.tables.selected != before then
        self.page = 1
        self.first_column = 0
        load_table(self)
      end
    elseif self.tabs.active == 0 then
      self.rows.handle(ev)
    elseif self.tabs.active == 1 then
      self.structure.handle(ev)
    elseif self.tabs.active == 3 then
      self.migrations.handle(ev)
    end
  end

  public fun view(self, screen: b.Buffer, area: l.Rect) -> array<int>
    let rows = area.split_column([l.Size.fixed(1), l.Size.fill(1), l.Size.fixed(1)], 0)
    let mode = if self.write then "read and write" else "read only" end
    screen.put(rows[0].x + 1, rows[0].y, tx.truncate(self.url + "  ·  " + mode, rows[0].w - 2), st.Style.create().dim())
    let cols = rows[1].split_row([l.Size.fixed(26), l.Size.fill(1)], 0)
    let edge = fun(id: string) -> st.Style
      if self.focus.has(id) then st.Style.create().fg(st.Color.ansi(6)).bold() else st.Style.create() end
    end
    self.tables.render(screen, bk.Block.create().rounded().title("Tables").border_style(edge("tables")).render(screen, cols[0]), self.focus.has("tables"))
    let right = cols[1].split_column([l.Size.fixed(1), l.Size.fill(1)], 0)
    self.tabs.render(screen, right[0])
    let focused = self.focus.has("content")
    let cursor: array<int> = []
    let body = bk.Block.create().rounded().border_style(edge("content")).render(screen, right[1])
    let active = self.tabs.active
    if active == 0 then
      self.rows.render(screen, body, focused)
    elseif active == 1 then
      self.structure.render(screen, body, focused)
    elseif active == 2 then
      let parts = body.split_column([l.Size.fixed(6), l.Size.fill(1)], 0)
      let box = bk.Block.create().rounded().title("SQL (ctrl+r runs)").render(screen, parts[0])
      let at = self.sql.render(screen, box, focused)
      if at.len() == 2 then
        cursor.push(at[0])
        cursor.push(at[1])
      end
      let out = bk.Block.create().rounded().title(if self.ran == "" then "Result" else "Result: " + self.ran end).render(screen, parts[1])
      self.result.render(screen, out, false)
    else
      self.migrations.render(screen, body, focused)
    end
    let status = if self.message != "" then "! " + self.message else "page {self.page}/{total_pages(self)} · {self.total} rows" end
    screen.put(rows[2].x + 1, rows[2].y, tx.truncate(status, rows[2].w - 2), if self.message != "" then st.Style.create().fg(st.Color.ansi(1)) else st.Style.create().dim() end)
    if cursor.len() == 2 then
      return cursor
    end
    []
  end
end

--" Opens the database at `url` in the terminal. --"
fun run(url: string, write: bool) -> Result<bool, Error>
  let opened = Db.connect(url)
  if opened.is_err() then
    return Result<bool, Error>.Err(opened.unwrap_err())
  end
  let files = fun() -> array<string>
    let found = fs.glob("migrations/*.q")
    if found.is_ok() then found.unwrap() else [] end
  end
  ap.run_in_terminal(create(opened.unwrap(), url, write, files))
end

export Browser, create, run, pending
