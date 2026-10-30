import "../tui/keys.q" as k
import "../tui/style.q" as st
import "../tui/theme.q" as th
import "config.q" as c

fun files(table: map<string, string>) -> fun(string) -> string?
  fun(path: string) -> string?
    table[path]
  end
end

fun test_no_file_means_the_defaults()
  let config = c.load(files({}), "home/kit.json", "kit.json").unwrap()
  assert_eq(config.theme, "dark")
  assert_eq(config.quit_key, "q")
  assert_eq(config.dash_url, "http://localhost:8000")
  assert_eq(config.db_url, "")
  assert(not config.db_write)
end

fun test_a_file_sets_the_theme_the_keys_and_the_sections()
  let text = "\{\"theme\":\"light\",\"keys\":\{\"quit\":\"ctrl+q\"},\"db\":\{\"url\":\"sqlite://a.db\",\"write\":true},\"dashboard\":\{\"url\":\"http://x:1\",\"log\":\"a.log\"}}"
  let config = c.load(files({"kit.json": text}), "", "kit.json").unwrap()
  assert_eq(config.theme, "light")
  assert_eq(config.quit_key, "ctrl+q")
  assert_eq(config.db_url, "sqlite://a.db")
  assert(config.db_write)
  assert_eq(config.dash_log, "a.log")
end

fun test_the_project_wins_over_the_user_key_by_key()
  let user = "\{\"theme\":\"light\",\"db\":\{\"url\":\"sqlite://mine.db\",\"write\":true}}"
  let project = "\{\"db\":\{\"url\":\"sqlite://project.db\"}}"
  let config = c.load(files({"home/kit.json": user, "kit.json": project}), "home/kit.json", "kit.json").unwrap()
  assert_eq(config.theme, "light")
  assert_eq(config.db_url, "sqlite://project.db")
  assert(config.db_write)
end

fun test_a_theme_of_your_own_starts_from_a_built_in_one()
  let text = "\{\"theme\":\"sunset\",\"themes\":\{\"sunset\":\{\"base\":\"high-contrast\",\"accent\":\"#ff8800\",\"error\":\"bright-red\",\"selection\":\"palette:24\",\"selection_text\":\"white\"}}}"
  let config = c.load(files({"kit.json": text}), "", "kit.json").unwrap()
  let theme = c.chosen_theme(config)
  assert_eq(theme.name, "sunset")
  assert_eq(theme.accent, st.Color.rgb(255, 136, 0))
  assert_eq(theme.error, st.Color.ansi(9))
  assert_eq(theme.select_bg, st.Color.indexed(24))
  assert_eq(theme.select_fg, st.Color.ansi(7))
  assert_eq(theme.ok, st.Color.ansi(10))
end

fun test_apply_puts_the_theme_and_the_quit_key_to_work()
  let text = "\{\"theme\":\"mono\",\"keys\":\{\"quit\":\"ctrl+q\"}}"
  let config = c.load(files({"kit.json": text}), "", "kit.json").unwrap()
  c.apply(config)
  assert_eq(th.current_name(), "mono")
  assert(k.quit_pressed(Event { kind: "key", key: "q", ctrl: true }))
  assert(not k.quit_pressed(Event { kind: "key", key: "q" }))
  c.apply(c.defaults())
  assert_eq(th.current_name(), "dark")
  assert(k.quit_pressed(Event { kind: "key", key: "q" }))
end

fun message_of(text: string) -> string
  let result = c.load(files({"kit.json": text}), "", "kit.json")
  if result.is_ok() then "" else result.unwrap_err().message end
end

fun test_mistakes_are_reported_with_where_they_are()
  assert(message_of("not json").starts_with("kit.json: "))
  assert_eq(message_of("\{\"thme\":\"dark\"}"), "unknown setting `thme`")
  assert_eq(message_of("\{\"db\":\{\"ulr\":\"x\"}}"), "unknown setting `db.ulr`")
  assert(message_of("\{\"theme\":\"neon\"}").starts_with("theme: `neon` is not a theme"))
  assert_eq(message_of("\{\"themes\":\{\"a\":\{\"accent\":\"purplish\"}}}"), "themes.a.accent: `purplish` is not a colour (#rrggbb, a name, or palette:N)")
  assert(message_of("\{\"themes\":\{\"a\":\{\"base\":\"nope\"}}}").contains("not a built-in theme"))
  assert_eq(message_of("\{\"keys\":\{\"quit\":5}}"), "keys.quit must be a text")
  assert_eq(message_of("\{\"themes\":\{\"a\":\{\"accent\":\"#12\"}}}"), "themes.a.accent: `#12` is not a colour (#rrggbb)")
end

fun test_colours_in_their_forms()
  assert_eq(c.colour("red").unwrap(), st.Color.ansi(1))
  assert_eq(c.colour("bright-cyan").unwrap(), st.Color.ansi(14))
  assert_eq(c.colour("default").unwrap(), 0)
  assert_eq(c.colour("#00ff00").unwrap(), st.Color.rgb(0, 255, 0))
  assert_eq(c.colour("palette:200").unwrap(), st.Color.indexed(200))
  assert(c.colour("palette:300").is_err())
  assert(c.colour("").is_err())
end
