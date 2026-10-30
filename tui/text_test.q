import "text.q" as t

fun test_truncate_marks_the_cut()
  assert_eq(t.truncate("hello", 10), "hello")
  assert_eq(t.truncate("hello world", 8), "hello w…")
  assert_eq(t.truncate("hello", 1), "…")
  assert_eq(t.truncate("hello", 0), "")
end

fun test_wide_characters_are_counted_by_columns()
  assert_eq(t.truncate("漢字漢字", 5), "漢字…")
  assert_eq(t.clip("漢字", 3), "漢")
  assert_eq(t.fit("漢", 4, "left"), "漢  ")
end

fun test_fit_pads_on_the_side_asked()
  assert_eq(t.fit("ab", 5, "left"), "ab   ")
  assert_eq(t.fit("ab", 5, "right"), "   ab")
  assert_eq(t.fit("ab", 5, "center"), " ab  ")
  assert_eq(t.fit("abcdef", 4, "left"), "abc…")
end

fun test_wrap_breaks_at_spaces()
  assert_eq(t.wrap("one two three", 7), ["one two", "three"])
  assert_eq(t.wrap("one two three", 13), ["one two three"])
  assert_eq(t.wrap("a  b", 10), ["a b"])
end

fun test_wrap_keeps_newlines_and_cuts_long_words()
  assert_eq(t.wrap("ab\n\ncd", 5), ["ab", "", "cd"])
  assert_eq(t.wrap("abcdefghij kl", 4), ["abcd", "efgh", "ij", "kl"])
  assert_eq(t.wrap("anything", 0), [])
end
