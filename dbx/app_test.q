import "../tui/testing.q" as t
import "app.q" as a

fun database() -> Db
  let db = Db.connect("sqlite://:memory:").unwrap()
  db.execute("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT NOT NULL, email TEXT)", [])
  db.execute("CREATE TABLE posts (id INTEGER PRIMARY KEY, title TEXT)", [])
  db.execute("CREATE TABLE schema_migrations (id TEXT PRIMARY KEY)", [])
  db.execute("INSERT INTO schema_migrations (id) VALUES ('001_users')", [])
  for i in 1..61 do
    db.execute("INSERT INTO users (name, email) VALUES (?, ?)", [Json.string("user{i}"), Json.string("user{i}@example.org")])
  end
  db
end

fun files() -> array<string>
  ["migrations/001_users.q", "migrations/002_posts.q"]
end

fun start(write: bool) -> t.Harness
  t.Harness.start(110, 30, a.create(database(), "sqlite://test.db", write, fun() -> array<string> files() end))
end

fun test_the_tables_and_the_first_rows_are_shown()
  let app = start(false)
  assert(app.contains("posts"))
  assert(app.contains("schema_migrations"))
  assert(app.contains("users"))
  assert(app.contains("sqlite://test.db  ·  read only"))
  assert(app.contains("page 1/1 · 0 rows"))
end

fun test_choosing_a_table_shows_its_rows_and_pages()
  let app = start(false)
  app.key("Down")
  app.key("Down")
  assert(app.contains("user1@example.org"))
  assert(app.contains("page 1/2 · 60 rows"))
  app.key("n")
  assert(app.contains("page 2/2"))
  assert(app.contains("user60"))
  assert(not app.contains("user1@"))
  app.key("p")
  assert(app.contains("page 1/2"))
  app.key("p")
  assert(app.contains("page 1/2"))
end

fun test_the_structure_tab_lists_the_columns()
  let app = start(false)
  app.key("Down")
  app.key("Down")
  app.key("2")
  assert(app.contains("Column"))
  assert(app.contains("TEXT"))
  assert(app.contains("PRI"))
  assert(app.contains("email"))
end

fun test_arrows_scroll_the_columns_when_the_content_has_the_focus()
  let app = start(false)
  app.key("Down")
  app.key("Down")
  app.key("Tab")
  app.key("Right")
  assert(not app.contains("id "))
  assert(app.contains("name"))
  app.key("Left")
  assert(app.contains("name"))
end

fun test_sql_is_typed_and_run_and_shows_its_result()
  let app = start(false)
  app.key("3")
  app.key("Tab")
  app.text("SELECT name FROM users WHERE id < 3 ORDER BY id")
  app.ctrl("r")
  assert(app.contains("Result: 2 row(s)"))
  assert(app.contains("user1"))
  assert(app.contains("user2"))
end

fun test_a_write_is_refused_unless_the_tool_was_started_with_write()
  let app = start(false)
  app.key("3")
  app.key("Tab")
  app.text("DELETE FROM users")
  app.key("F5")
  assert(app.contains("! this tool only reads"))
  app.key("Esc")
  app.key("Down")
  app.key("Down")
  assert(app.contains("60 rows"))
  let rw = start(true)
  rw.key("3")
  rw.key("Tab")
  rw.text("DELETE FROM users WHERE id > 10")
  rw.key("F5")
  assert(rw.contains("Result: 50 row(s)"))
  rw.key("Esc")
  rw.key("Down")
  rw.key("Down")
  assert(rw.contains("10 rows"))
end

fun test_a_sql_error_is_shown_not_fatal()
  let app = start(false)
  app.key("3")
  app.key("Tab")
  app.text("SELECT nope FROM nowhere")
  app.ctrl("r")
  assert(app.contains("! "))
  assert(not app.finished())
end

fun test_q_does_not_quit_while_typing_sql_but_does_elsewhere()
  let app = start(false)
  app.key("3")
  app.key("Tab")
  app.key("q")
  assert(not app.finished())
  app.key("Esc")
  app.key("q")
  assert(app.finished())
end

fun test_the_migrations_tab_tells_applied_from_pending()
  let app = start(false)
  app.key("4")
  assert(app.contains("001_users"))
  assert(app.contains("applied"))
  assert(app.contains("002_posts"))
  assert(app.contains("pending"))
end

fun test_pending_migrations_are_the_files_not_in_the_table()
  assert_eq(a.pending(["001_a"], ["migrations/001_a.q", "migrations/002_b.q"]), ["002_b"])
  assert_eq(a.pending([], []), [])
end
