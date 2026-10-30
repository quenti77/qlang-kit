import "style.q" as st
import "theme.q" as th

fun test_the_default_look_is_the_dark_theme()
  assert_eq(th.current_name(), "dark")
  assert_eq(th.accent().fg, st.Color.ansi(6))
  assert_eq(th.error().fg, st.Color.ansi(1))
  assert_eq(th.selected().attrs, 16)
end

fun test_use_theme_changes_every_role_for_the_whole_program()
  th.use_theme(th.Theme.high_contrast())
  assert_eq(th.current_name(), "high-contrast")
  assert_eq(th.ok().fg, st.Color.ansi(10))
  assert_eq(th.selected().bg, st.Color.ansi(15))
  assert_eq(th.selected().attrs, 0)
  th.use_theme(th.Theme.dark())
  assert_eq(th.current_name(), "dark")
end

fun test_mono_has_no_colour_only_weight()
  th.use_theme(th.Theme.mono())
  assert_eq(th.accent().fg, 0)
  assert_eq(th.accent().attrs, 1)
  assert_eq(th.error().fg, 0)
  assert_eq(th.error().attrs, 9)
  assert_eq(th.warn().attrs, 1)
  th.use_theme(th.Theme.dark())
end

fun test_built_in_themes_are_found_by_name_and_a_copy_can_be_changed()
  for name in th.builtin_names() do
    let found = th.find(name)
    assert(found != none)
  end
  assert(th.find("nope") == none)
  let mine = th.Theme.dark().copy()
  mine.accent = st.Color.rgb(255, 136, 0)
  th.use_theme(mine)
  assert_eq(th.accent().fg, st.Color.rgb(255, 136, 0))
  assert_eq(th.Theme.dark().accent, st.Color.ansi(6))
  th.use_theme(th.Theme.dark())
end
