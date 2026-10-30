import "buffer.q" as b
import "style.q" as st

fun plain() -> st.Style
  st.Style.create()
end

fun test_text_is_put_and_cut_at_the_edges()
  let screen = b.Buffer.create(6, 2)
  assert_eq(screen.put(1, 0, "hello world", plain()), 6)
  assert_eq(screen.put(-2, 1, "abcd", plain()), 2)
  assert_eq(screen.lines(), [" hello", "cd"])
end

fun test_a_row_outside_the_screen_is_ignored()
  let screen = b.Buffer.create(4, 1)
  screen.put(0, 5, "x", plain())
  screen.put(0, -1, "x", plain())
  assert_eq(screen.lines(), [""])
end

fun test_a_wide_character_fills_two_cells()
  let screen = b.Buffer.create(6, 1)
  assert_eq(screen.put(0, 0, "a漢b", plain()), 4)
  assert_eq(screen.char_at(1, 0), "漢")
  assert_eq(screen.char_at(2, 0), "")
  assert_eq(screen.char_at(3, 0), "b")
  assert_eq(screen.lines(), ["a漢b"])
end

fun test_a_wide_character_that_does_not_fit_becomes_a_space()
  let screen = b.Buffer.create(3, 1)
  screen.put(0, 0, "ab漢", plain())
  assert_eq(screen.lines(), ["ab"])
end

fun test_overwriting_half_of_a_wide_character_blanks_the_other_half()
  let screen = b.Buffer.create(4, 1)
  screen.put(0, 0, "漢", plain())
  screen.put(1, 0, "x", plain())
  assert_eq(screen.char_at(0, 0), " ")
  assert_eq(screen.char_at(1, 0), "x")
  let other = b.Buffer.create(4, 1)
  other.put(0, 0, "漢", plain())
  other.put(0, 0, "y", plain())
  assert_eq(other.char_at(0, 0), "y")
  assert_eq(other.char_at(1, 0), " ")
end

fun test_fill_draws_a_rectangle()
  let screen = b.Buffer.create(5, 3)
  screen.fill(1, 1, 3, 2, "#", plain())
  assert_eq(screen.lines(), ["", " ###", " ###"])
end

fun test_the_first_diff_erases_the_terminal_and_draws_only_what_is_not_blank()
  let screen = b.Buffer.create(10, 3)
  screen.put(2, 1, "hi", plain())
  assert_eq(screen.diff(none, 256), "\e[0m\e[2J\e[2;3H\e[0mhi")
end

fun test_an_unchanged_screen_costs_nothing()
  let screen = b.Buffer.create(10, 3)
  screen.put(2, 1, "hi", plain())
  assert_eq(screen.diff(screen.copy(), 256), "")
end

fun test_only_the_cells_that_changed_are_written()
  let before = b.Buffer.create(10, 3)
  before.put(0, 0, "hello", plain())
  let after = before.copy()
  after.put(4, 0, "!", plain())
  assert_eq(after.diff(before, 256), "\e[1;5H\e[0m!")
end

fun test_a_short_gap_is_written_instead_of_a_jump()
  let before = b.Buffer.create(10, 1)
  before.put(0, 0, "abcdefgh", plain())
  let after = before.copy()
  after.put(1, 0, "X", plain())
  after.put(3, 0, "Y", plain())
  assert_eq(after.diff(before, 256), "\e[1;2H\e[0mXcY")
end

fun test_a_style_is_set_once_for_a_run_and_reset_at_the_end()
  let screen = b.Buffer.create(8, 1)
  let red = st.Style.create().fg(st.Color.ansi(1))
  screen.put(0, 0, "ab", red)
  screen.put(2, 0, "cd", plain())
  assert_eq(screen.diff(none, 16), "\e[0m\e[2J\e[1;1H\e[0;31mab\e[0mcd")
  let only_red = b.Buffer.create(4, 1)
  only_red.put(0, 0, "x", red)
  assert_eq(only_red.diff(none, 16), "\e[0m\e[2J\e[1;1H\e[0;31mx\e[0m")
end

fun test_a_screen_of_another_size_is_drawn_again()
  let small = b.Buffer.create(4, 1)
  let big = b.Buffer.create(5, 1)
  big.put(0, 0, "a", plain())
  assert_eq(big.diff(small, 256), "\e[0m\e[2J\e[1;1H\e[0ma")
end

fun test_a_wide_character_moves_the_cursor_by_two()
  let before = b.Buffer.create(8, 1)
  let after = before.copy()
  after.put(0, 0, "漢字", plain())
  assert_eq(after.diff(before, 256), "\e[1;1H\e[0m漢字")
end
