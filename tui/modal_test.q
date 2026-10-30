import "buffer.q" as b
import "layout.q" as l
import "modal.q" as m

fun key(name: string) -> Event
  Event { kind: "key", key: name }
end

fun test_enter_presses_the_selected_button()
  let ask = m.Dialog.create("Save", "Save the changes?", ["Save", "Discard", "Cancel"])
  ask.handle(key("Right"))
  ask.handle(key("Enter"))
  assert_eq(ask.result(), "Discard")
  assert(not ask.is_open())
  assert(not ask.handle(key("Enter")))
end

fun test_a_confirmation_starts_on_no_and_escape_cancels()
  let ask = m.Dialog.confirm("Delete", "Sure?")
  ask.handle(key("Enter"))
  assert_eq(ask.result(), "No")
  ask.reopen()
  ask.handle(key("Left"))
  ask.handle(key("Enter"))
  assert_eq(ask.result(), "Yes")
  ask.reopen()
  ask.handle(key("Esc"))
  assert_eq(ask.result(), "No")
end

fun test_the_first_letter_of_a_button_presses_it()
  let ask = m.Dialog.confirm("Delete", "Sure?")
  ask.handle(key("y"))
  assert_eq(ask.result(), "Yes")
end

fun test_buttons_wrap_around_and_other_keys_are_swallowed()
  let ask = m.Dialog.create("t", "m", ["A", "B"])
  ask.handle(key("Left"))
  assert(ask.handle(key("F5")))
  ask.handle(key("Enter"))
  assert_eq(ask.result(), "B")
end

fun test_the_box_is_drawn_in_the_middle_with_its_buttons()
  let ask = m.Dialog.confirm("Delete", "Remove this user?")
  let screen = b.Buffer.create(60, 12)
  let box = ask.render(screen, l.Rect.create(0, 0, 60, 12))
  assert_eq(box.w, 40)
  assert_eq(box.x, 10)
  let lines = screen.lines()
  assert(lines[box.y].contains("Delete"))
  assert(lines[box.y + 1].contains("Remove this user?"))
  assert(lines[box.y + box.h - 2].contains("[ Yes ]  [ No ]"))
end

fun test_a_long_message_wraps_inside_the_box()
  let ask = m.Dialog.notice("Info", "one two three four five six seven eight nine ten eleven twelve thirteen")
  let screen = b.Buffer.create(50, 14)
  let box = ask.render(screen, l.Rect.create(0, 0, 50, 14))
  assert(box.h > 6)
end
