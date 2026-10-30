import "buffer.q" as b
import "layout.q" as l
import "textarea.q" as ta

fun key(name: string) -> Event
  Event { kind: "key", key: name }
end

fun type_text(area: ta.TextArea, text: string)
  for ch in text.chars() do
    area.handle(key(ch))
  end
end

fun test_enter_splits_the_line_at_the_cursor()
  let area = ta.TextArea.create()
  type_text(area, "helloworld")
  for i in 0..5 do
    area.handle(key("Left"))
  end
  area.handle(key("Enter"))
  assert_eq(area.text(), "hello\nworld")
  assert_eq(area.row, 1)
  assert_eq(area.col, 0)
end

fun test_backspace_at_the_start_of_a_line_joins_it_to_the_one_above()
  let area = ta.TextArea.create()
  area.set("ab\ncd")
  area.handle(key("Home"))
  area.handle(key("Backspace"))
  assert_eq(area.text(), "abcd")
  assert_eq(area.row, 0)
  assert_eq(area.col, 2)
  area.handle(key("Home"))
  area.handle(key("Backspace"))
  assert_eq(area.text(), "abcd")
end

fun test_delete_at_the_end_of_a_line_pulls_the_next_one_up()
  let area = ta.TextArea.create()
  area.set("ab\ncd\nef")
  area.handle(key("Up"))
  area.handle(key("Up"))
  area.handle(key("End"))
  area.handle(key("Delete"))
  assert_eq(area.text(), "abcd\nef")
  area.handle(key("Down"))
  area.handle(key("End"))
  area.handle(key("Delete"))
  assert_eq(area.text(), "abcd\nef")
end

fun test_the_arrows_cross_the_ends_of_lines_and_keep_the_column_in_range()
  let area = ta.TextArea.create()
  area.set("abcdef\nxy")
  assert_eq(area.col, 2)
  area.handle(key("Up"))
  assert_eq(area.col, 2)
  area.handle(key("End"))
  area.handle(key("Right"))
  assert_eq(area.row, 1)
  assert_eq(area.col, 0)
  area.handle(key("Left"))
  assert_eq(area.row, 0)
  assert_eq(area.col, 6)
  area.handle(key("Down"))
  assert_eq(area.col, 2)
end

fun test_a_paste_keeps_its_line_breaks()
  let area = ta.TextArea.create()
  area.set("start end")
  for i in 0..4 do
    area.handle(key("Left"))
  end
  area.handle(Event { kind: "paste", text: "A\nB\nC" })
  assert_eq(area.text(), "startA\nB\nC end")
  assert_eq(area.row, 2)
  assert_eq(area.col, 1)
end

fun test_control_keys_edit_within_the_line()
  let area = ta.TextArea.create()
  area.set("one two three")
  area.handle(Event { kind: "key", key: "w", ctrl: true })
  assert_eq(area.text(), "one two ")
  area.handle(Event { kind: "key", key: "u", ctrl: true })
  assert_eq(area.text(), "")
end

fun test_tab_and_escape_are_left_to_the_program()
  let area = ta.TextArea.create()
  assert(not area.handle(key("Tab")))
  assert(not area.handle(key("Esc")))
  assert(not area.handle(Event { kind: "mouse" }))
end

fun test_the_view_scrolls_to_the_cursor_and_gives_its_position()
  let area = ta.TextArea.create()
  area.set("1\n2\n3\n4\n5")
  let screen = b.Buffer.create(6, 3)
  let at = area.render(screen, l.Rect.create(0, 0, 6, 3), true)
  assert_eq(screen.lines(), ["3", "4", "5"])
  assert_eq(at, [1, 2])
  assert_eq(area.render(screen, l.Rect.create(0, 0, 6, 3), false), [])
end

fun test_a_long_line_scrolls_sideways()
  let area = ta.TextArea.create()
  area.set("abcdefghij")
  let screen = b.Buffer.create(5, 2)
  let at = area.render(screen, l.Rect.create(0, 0, 5, 2), true)
  assert_eq(screen.lines()[0], "ghij")
  assert_eq(at, [4, 0])
end
