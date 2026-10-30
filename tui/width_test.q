import "width.q" as w

fun test_ascii_accents_and_controls()
  assert_eq(w.char_width("a"), 1)
  assert_eq(w.char_width("é"), 1)
  assert_eq(w.char_width("\t"), 0)
  assert_eq(w.char_width("́"), 0)
end

fun test_wide_characters_take_two_columns()
  assert_eq(w.char_width("漢"), 2)
  assert_eq(w.char_width("あ"), 2)
  assert_eq(w.char_width("한"), 2)
  assert_eq(w.char_width("Ａ"), 2)
  assert_eq(w.char_width("😀"), 2)
end

fun test_symbols_that_are_narrow()
  assert_eq(w.char_width("─"), 1)
  assert_eq(w.char_width("█"), 1)
  assert_eq(w.char_width("€"), 1)
  assert_eq(w.char_width("→"), 1)
end

fun test_a_text_adds_its_characters()
  assert_eq(w.text_width("abc"), 3)
  assert_eq(w.text_width("a漢b"), 4)
  assert_eq(w.text_width(""), 0)
end
