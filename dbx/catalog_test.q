import "catalog.q" as c

fun database() -> Db
  let db = Db.connect("sqlite://:memory:").unwrap()
  db.execute("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT NOT NULL, age INTEGER DEFAULT 18, note TEXT)", [])
  db.execute("CREATE TABLE posts (id INTEGER PRIMARY KEY, title TEXT)", [])
  for i in 1..8 do
    db.execute("INSERT INTO users (name, age) VALUES (?, ?)", [Json.string("user{i}"), Json.number(20.0 + i as float)])
  end
  db.execute("INSERT INTO users (name, note) VALUES ('Nul', 'x')", [])
  db
end

fun test_the_driver_is_read_from_the_url()
  assert_eq(c.driver_of("sqlite://a.db"), "sqlite")
  assert_eq(c.driver_of("postgres://u@h/db"), "postgres")
  assert_eq(c.driver_of("postgresql://u@h/db"), "postgres")
  assert_eq(c.driver_of("mysql://u@h/db"), "mysql")
  assert_eq(c.driver_of("ftp://x"), "")
end

fun test_tables_are_listed_sorted()
  assert_eq(c.tables(database(), "sqlite").unwrap(), ["posts", "users"])
end

fun test_columns_come_with_their_type_null_key_and_default()
  let cols = c.columns(database(), "sqlite", "users").unwrap()
  assert_eq(cols.len(), 4)
  assert_eq(cols[0].name, "id")
  assert(cols[0].primary)
  assert_eq(cols[1].kind, "TEXT")
  assert(not cols[1].nullable)
  assert(cols[3].nullable)
  assert_eq(cols[2].default, "18")
  assert_eq(cols[3].default, "NULL")
end

fun test_a_page_of_rows_has_the_columns_in_order_and_the_total()
  let page = c.rows_page(database(), "sqlite", "users", 5, 1).unwrap()
  assert_eq(page.columns, ["id", "name", "age", "note"])
  assert_eq(page.rows.len(), 5)
  assert_eq(page.total, 8)
  assert_eq(page.rows[0], ["1", "user1", "21", "NULL"])
  let last = c.rows_page(database(), "sqlite", "users", 5, 2).unwrap()
  assert_eq(last.rows.len(), 3)
  assert_eq(last.rows[2][3], "x")
end

fun test_a_table_name_that_is_not_plain_is_refused()
  assert(c.rows_page(database(), "sqlite", "users; DROP TABLE users", 5, 1).is_err())
  assert(c.columns(database(), "sqlite", "a b").is_err())
  assert(c.is_name("user_2"))
  assert(not c.is_name("2users"))
end

fun test_only_reads_recognises_what_only_reads()
  assert(c.only_reads("SELECT * FROM users"))
  assert(c.only_reads("  select 1;  "))
  assert(c.only_reads("WITH x AS (SELECT 1) SELECT * FROM x"))
  assert(c.only_reads("PRAGMA table_info(users)"))
  assert(not c.only_reads("DELETE FROM users"))
  assert(not c.only_reads("SELECT 1; DROP TABLE users"))
  assert(not c.only_reads(""))
end

fun test_a_query_gives_rows_and_a_write_is_refused_unless_allowed()
  let db = database()
  let read = c.run_sql(db, "SELECT name, age FROM users WHERE age > 25 ORDER BY age", false).unwrap()
  assert_eq(read.columns, ["name", "age"])
  assert_eq(read.total, 2)
  let refused = c.run_sql(db, "DELETE FROM users", false)
  assert(refused.unwrap_err().message.contains("--write"))
  assert_eq(c.rows_page(db, "sqlite", "users", 50, 1).unwrap().total, 8)
  let wrote = c.run_sql(db, "DELETE FROM users WHERE age > 25", true).unwrap()
  assert_eq(wrote.rows[0][0], "2")
  assert(c.run_sql(db, "SELEC oops", false).is_err())
end

fun test_an_empty_result_has_no_columns()
  let none_found = c.run_sql(database(), "SELECT * FROM users WHERE id < 0", false).unwrap()
  assert_eq(none_found.total, 0)
  assert_eq(none_found.columns, [])
end
