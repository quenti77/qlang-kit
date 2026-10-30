import "buffer.q" as b
import "layout.q" as l
import "list.q" as li

fun key(name: string) -> Event
  Event { kind: "key", key: name }
end

fun names() -> array<string>
  ["a", "b", "c", "d", "e", "f"]
end

fun test_the_arrows_move_the_selection_and_stop_at_the_ends()
  let list = li.List.create(names())
  assert(list.handle(key("Down")))
  assert(list.handle(key("j")))
  assert_eq(list.selected, 2)
  list.handle(key("Up"))
  assert_eq(list.selected, 1)
  list.handle(key("Home"))
  list.handle(key("Up"))
  assert_eq(list.selected, 0)
  list.handle(key("End"))
  list.handle(key("Down"))
  assert_eq(list.selected_item(), "f")
end

fun test_other_keys_and_events_are_not_used()
  let list = li.List.create(names())
  assert(not list.handle(key("x")))
  assert(not list.handle(Event { kind: "key", key: "Down", ctrl: true }))
  assert(not list.handle(Event { kind: "resize", x: 10, y: 10 }))
  assert_eq(list.selected, 0)
end

fun test_an_empty_list_has_nothing_selected()
  let list = li.List.create([])
  list.handle(key("Down"))
  assert_eq(list.selected, 0)
  assert_eq(list.selected_item(), none)
end

fun test_the_view_scrolls_to_keep_the_selection_visible()
  let list = li.List.create(names())
  let screen = b.Buffer.create(10, 3)
  let area = l.Rect.create(0, 0, 10, 3)
  list.move_to(4)
  list.render(screen, area, true)
  assert_eq(screen.lines().map(fun(s: string) -> string s.substring(0, 4) end), ["  c ", "  d ", "› e "])
  list.move_to(0)
  list.render(screen, area, true)
  assert_eq(screen.lines()[0].substring(0, 4), "› a ")
end

fun test_a_scroll_bar_shows_when_the_lines_do_not_fit()
  let list = li.List.create(names())
  let screen = b.Buffer.create(6, 3)
  list.render(screen, l.Rect.create(0, 0, 6, 3), false)
  assert_eq(screen.char_at(5, 0), "█")
  assert_eq(screen.char_at(5, 2), "│")
  let all = b.Buffer.create(6, 6)
  list.render(all, l.Rect.create(0, 0, 6, 6), false)
  assert_eq(all.char_at(5, 0), " ")
end

fun test_the_selected_line_is_reversed_only_with_the_focus()
  let list = li.List.create(names())
  let screen = b.Buffer.create(8, 2)
  list.render(screen, l.Rect.create(0, 0, 8, 2), true)
  assert_eq(screen.style_at(0, 0).attrs, 16)
  list.render(screen, l.Rect.create(0, 0, 8, 2), false)
  assert_eq(screen.style_at(0, 0).attrs, 1)
end

fun test_the_wheel_and_the_mouse_work()
  let list = li.List.create(names())
  assert(list.handle(Event { kind: "mouse", action: "scroll_down" }))
  assert_eq(list.selected, 3)
  let screen = b.Buffer.create(8, 3)
  let area = l.Rect.create(0, 0, 8, 3)
  list.render(screen, area, true)
  assert(list.click(area, Event { kind: "mouse", action: "down", x: 2, y: 0 }))
  assert_eq(list.selected, 1)
  assert(not list.click(area, Event { kind: "mouse", action: "down", x: 20, y: 0 }))
end

fun test_new_items_keep_the_selection_inside()
  let list = li.List.create(names())
  list.move_to(5)
  list.set_items(["x", "y"])
  assert_eq(list.selected, 1)
end
