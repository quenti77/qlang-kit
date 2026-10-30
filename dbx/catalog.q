--" # Looking into a database

What the database browser needs from a database, written for SQLite, PostgreSQL and MySQL: the tables, the
columns of a table, a page of rows, and the result of a query. Table names come from the database's own
catalog and are quoted; a query typed by the user is only run if it only reads (unless writing is allowed).

```
let db = Db.connect("sqlite://app.db").unwrap()
tables(db, "sqlite")                          -- ["posts", "users"]
columns(db, "sqlite", "users")                -- [Column { name: "id", ... }]
rows_page(db, "sqlite", "users", 50, 1)       -- the first 50 rows and the total
```
--"

--" One column of a table. --"
struct Column
  public name: string
  public kind: string
  public nullable: bool
  public primary: bool
  public default: string
end

--" Some rows as text, ready to show. --"
struct Rows
  public columns: array<string>
  public rows: array<array<string>>
  --" How many rows the table has (for a page), or how many came back (for a query). --"
  public total: int
end

--" `"sqlite"`, `"postgres"` or `"mysql"` from the URL of the database (`""` when it is none of them). --"
fun driver_of(url: string) -> string
  if url.starts_with("sqlite:") then
    "sqlite"
  elseif url.starts_with("postgres:") or url.starts_with("postgresql:") then
    "postgres"
  elseif url.starts_with("mysql:") then
    "mysql"
  else
    ""
  end
end

fun failure<T>(message: string) -> Result<T, Error>
  Result<T, Error>.Err(Error { message: message })
end

--" A value as it is shown: text as it is, `NULL`, numbers and booleans in their usual form. --"
fun cell(value: Json) -> string
  if value.is_null() then
    "NULL"
  elseif value.is_string() then
    value.as_string()
  else
    value.to_text()
  end
end

fun text_of(row: map<string, Json>, key: string) -> string
  cell(row[key] ?? Json.null())
end

--" The table names of the database, sorted. --"
fun tables(db: Db, driver: string) -> Result<array<string>, Error>
  let sql = if driver == "sqlite" then
    "SELECT name AS name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%' ORDER BY name"
  elseif driver == "postgres" then
    "SELECT table_name AS name FROM information_schema.tables WHERE table_schema = 'public' AND table_type = 'BASE TABLE' ORDER BY table_name"
  else
    "SELECT table_name AS name FROM information_schema.tables WHERE table_schema = DATABASE() ORDER BY table_name"
  end
  let found = db.query(sql, [])
  if found.is_err() then
    return Result<array<string>, Error>.Err(found.unwrap_err())
  end
  Result<array<string>, Error>.Ok(found.unwrap().map(fun(r: map<string, Json>) -> string text_of(r, "name") end))
end

--" A table name that is safe to put in a query: letters, digits, `_` and `$` only. --"
fun is_name(name: string) -> bool
  regex.matches(name, "^[A-Za-z_][A-Za-z0-9_$]*$")
end

--" The name quoted for the database (`"users"`, or `` `users` `` for MySQL). --"
fun quote(driver: string, name: string) -> Result<string, Error>
  if not is_name(name) then
    return failure<string>("`{name}` is not a table name I can use")
  end
  Result<string, Error>.Ok(if driver == "mysql" then "`" + name + "`" else "\"" + name + "\"" end)
end

--" The columns of a table, in their order. --"
fun columns(db: Db, driver: string, table: string) -> Result<array<Column>, Error>
  if not is_name(table) then
    return failure<array<Column>>("`{table}` is not a table name I can use")
  end
  let out: array<Column> = []
  if driver == "sqlite" then
    let found = db.query("SELECT name, type, \"notnull\" AS required, dflt_value AS dflt, pk FROM pragma_table_info('" + table + "')", [])
    if found.is_err() then
      return Result<array<Column>, Error>.Err(found.unwrap_err())
    end
    for r in found.unwrap() do
      out.push(Column { name: text_of(r, "name"), kind: text_of(r, "type"), nullable: text_of(r, "required") == "0", primary: text_of(r, "pk") != "0", default: text_of(r, "dflt") })
    end
    return Result<array<Column>, Error>.Ok(out)
  end
  let place = if driver == "postgres" then "$1" else "?" end
  let schema = if driver == "postgres" then "'public'" else "DATABASE()" end
  let found = db.query("SELECT column_name AS name, data_type AS type, is_nullable AS nullable, column_default AS dflt FROM information_schema.columns WHERE table_schema = " + schema + " AND table_name = " + place + " ORDER BY ordinal_position", [Json.string(table)])
  if found.is_err() then
    return Result<array<Column>, Error>.Err(found.unwrap_err())
  end
  for r in found.unwrap() do
    out.push(Column { name: text_of(r, "name"), kind: text_of(r, "type"), nullable: text_of(r, "nullable") == "YES", primary: false, default: text_of(r, "dflt") })
  end
  Result<array<Column>, Error>.Ok(out)
end

fun as_rows(found: array<map<string, Json>>, names: array<string>) -> array<array<string>>
  let out: array<array<string>> = []
  for r in found do
    out.push(names.map(fun(n: string) -> string text_of(r, n) end))
  end
  out
end

--" One page of a table (`number` from 1) with the total number of rows. --"
fun rows_page(db: Db, driver: string, table: string, size: int, number: int) -> Result<Rows, Error>
  let quoted = quote(driver, table)
  if quoted.is_err() then
    return Result<Rows, Error>.Err(quoted.unwrap_err())
  end
  let cols = columns(db, driver, table)
  if cols.is_err() then
    return Result<Rows, Error>.Err(cols.unwrap_err())
  end
  let names = cols.unwrap().map(fun(c: Column) -> string c.name end)
  let counted = db.query("SELECT COUNT(*) AS n FROM " + quoted.unwrap(), [])
  if counted.is_err() then
    return Result<Rows, Error>.Err(counted.unwrap_err())
  end
  let total = int.parse(text_of(counted.unwrap()[0], "n")) ?? 0
  let skip = (if number < 1 then 0 else number - 1 end) * size
  let found = db.query("SELECT * FROM " + quoted.unwrap() + " LIMIT {size} OFFSET {skip}", [])
  if found.is_err() then
    return Result<Rows, Error>.Err(found.unwrap_err())
  end
  Result<Rows, Error>.Ok(Rows { columns: names, rows: as_rows(found.unwrap(), names), total: total })
end

--" Whether the query only reads: it starts with `SELECT`, `WITH`, `EXPLAIN`, `SHOW`, `PRAGMA` or `VALUES`, and holds
no second statement. A query that writes inside a `WITH` is not recognised: that is why writing is a choice. --"
fun only_reads(sql: string) -> bool
  let text = sql.trim()
  while text.ends_with(";") do
    text = text.substring(0, text.len() - 1).trim()
  end
  if text.contains(";") then
    return false
  end
  let word = text.split(" ")[0].split("\n")[0].lower()
  ["select", "with", "explain", "show", "pragma", "values"].contains(word)
end

--" Runs a query. Unless `allow_write`, anything but a read is refused. A statement that writes gives the number
of rows it changed. --"
fun run_sql(db: Db, sql: string, allow_write: bool) -> Result<Rows, Error>
  if only_reads(sql) then
    let found = db.query(sql, [])
    if found.is_err() then
      return Result<Rows, Error>.Err(found.unwrap_err())
    end
    let list = found.unwrap()
    let names = if list.is_empty() then [] else list[0].keys() end
    return Result<Rows, Error>.Ok(Rows { columns: names, rows: as_rows(list, names), total: list.len() })
  end
  if not allow_write then
    return failure<Rows>("this tool only reads (start it with --write to change data)")
  end
  let done = db.execute(sql, [])
  if done.is_err() then
    return Result<Rows, Error>.Err(done.unwrap_err())
  end
  Result<Rows, Error>.Ok(Rows { columns: ["changed"], rows: [["{done.unwrap()}"]], total: done.unwrap() })
end

export Column, Rows, driver_of, cell, tables, columns, rows_page, only_reads, run_sql, is_name
