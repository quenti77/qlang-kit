import "buffer.q" as b
import "input.q" as inp
import "layout.q" as l

fun key(name: string) -> Event
  Event { kind: "key", key: name }
end

fun ctrl(name: string) -> Event
  Event { kind: "key", key: name, ctrl: true }
end

fun type_text(input: inp.TextInput, text: string)
  for ch in text.chars() do
    input.handle(key(ch))
  end
end

fun test_characters_are_inserted_at_the_cursor()
  let input = inp.TextInput.create("")
  type_text(input, "helo")
  input.handle(key("Left"))
  input.handle(key("l"))
  assert_eq(input.value, "hello")
  assert_eq(input.cursor, 4)
end

fun test_backspace_and_delete()
  let input = inp.TextInput.create("")
  input.set("abcd")
  input.handle(key("Backspace"))
  assert_eq(input.value, "abc")
  input.handle(key("Home"))
  input.handle(key("Delete"))
  assert_eq(input.value, "bc")
  input.handle(key("Backspace"))
  assert_eq(input.value, "bc")
end

fun test_control_keys_edit_by_line_and_word()
  let input = inp.TextInput.create("")
  input.set("one two three")
  input.handle(ctrl("w"))
  assert_eq(input.value, "one two ")
  input.handle(ctrl("a"))
  assert_eq(input.cursor, 0)
  input.handle(ctrl("e"))
  input.handle(ctrl("u"))
  assert_eq(input.value, "")
  input.set("abcdef")
  input.handle(ctrl("a"))
  input.handle(ctrl("f"))
  input.handle(ctrl("f"))
  input.handle(ctrl("k"))
  assert_eq(input.value, "ab")
end

fun test_enter_tab_escape_and_unknown_keys_are_left_to_the_program()
  let input = inp.TextInput.create("")
  assert(not input.handle(key("Enter")))
  assert(not input.handle(key("Tab")))
  assert(not input.handle(key("Esc")))
  assert(not input.handle(key("F5")))
  assert(not input.handle(Event { kind: "key", key: "x", alt: true }))
  assert_eq(input.value, "")
end

fun test_a_paste_is_one_line_and_respects_the_limit()
  let input = inp.TextInput.create("").max_length(8)
  input.handle(Event { kind: "paste", text: "ab\ncd\r\nefghij" })
  assert_eq(input.value, "ab cd ef")
  assert(not input.handle(Event { kind: "resize" }))
end

fun test_wide_characters_and_accents_are_single_characters()
  let input = inp.TextInput.create("")
  type_text(input, "é漢")
  assert_eq(input.cursor, 2)
  input.handle(key("Backspace"))
  assert_eq(input.value, "é")
end

fun test_the_placeholder_shows_while_empty()
  let input = inp.TextInput.create("Name")
  let screen = b.Buffer.create(10, 1)
  let area = l.Rect.create(0, 0, 10, 1)
  assert_eq(input.render(screen, area, false), [])
  assert_eq(screen.lines(), ["Name"])
  assert_eq(input.render(screen, area, true), [0, 0])
end

fun test_the_cursor_is_where_the_next_character_goes()
  let input = inp.TextInput.create("")
  type_text(input, "a漢b")
  let screen = b.Buffer.create(10, 1)
  let at = input.render(screen, l.Rect.create(2, 0, 8, 1), true)
  assert_eq(at, [6, 0])
  assert_eq(screen.lines(), ["  a漢b"])
end

fun test_a_long_text_scrolls_to_keep_the_cursor_visible()
  let input = inp.TextInput.create("")
  type_text(input, "abcdefghij")
  let screen = b.Buffer.create(5, 1)
  let at = input.render(screen, l.Rect.create(0, 0, 5, 1), true)
  assert_eq(screen.lines(), ["ghij"])
  assert_eq(at, [4, 0])
end

fun test_a_password_shows_only_the_mask()
  let input = inp.TextInput.password("")
  type_text(input, "abc")
  let screen = b.Buffer.create(6, 1)
  input.render(screen, l.Rect.create(0, 0, 6, 1), true)
  assert_eq(screen.lines(), ["•••"])
  assert_eq(input.value, "abc")
end
