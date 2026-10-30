import "buffer.q" as b
import "layout.q" as l
import "table.q" as tb

fun key(name: string) -> Event
  Event { kind: "key", key: name }
end

fun users() -> tb.Table
  let table = tb.Table.create([tb.Column.create("id", l.Size.fixed(3)).align("right"), tb.Column.create("name", l.Size.fill(1))])
  table.set_rows([["10", "Cyd"], ["2", "Ada"], ["33", "Bob"]])
  table
end

fun test_the_header_and_the_rows_are_laid_out_in_columns()
  let screen = b.Buffer.create(12, 4)
  users().render(screen, l.Rect.create(0, 0, 12, 4), false)
  assert_eq(screen.lines(), [" id name", " 10 Cyd", "  2 Ada", " 33 Bob"])
end

fun test_the_selection_moves_like_a_list()
  let table = users()
  table.handle(key("Down"))
  table.handle(key("Down"))
  table.handle(key("Down"))
  assert_eq(table.selected_row(), ["33", "Bob"])
  table.handle(key("Home"))
  assert_eq(table.selected_row(), ["10", "Cyd"])
  assert(not table.handle(key("x")))
end

fun test_sorting_by_text_and_by_number()
  let table = users()
  table.sort_by(1, false)
  assert_eq(table.selected_row(), ["2", "Ada"])
  table.sort_by(0, false)
  assert_eq(table.rows_first(), "2")
  table.sort_by(0, true)
  assert_eq(table.rows_first(), "33")
end

fun test_the_sorted_column_is_marked_and_kept_when_the_rows_change()
  let table = users()
  table.sort_by(1, true)
  let screen = b.Buffer.create(14, 2)
  table.render(screen, l.Rect.create(0, 0, 14, 2), false)
  assert_eq(screen.lines()[0], " id name ▼")
  table.set_rows([["1", "Zed"], ["2", "Amy"]])
  assert_eq(table.rows_first(), "1")
end

fun test_selected_row_of_an_empty_table_is_empty()
  let table = tb.Table.create([tb.Column.create("a", l.Size.fill(1))])
  assert_eq(table.selected_row(), [])
end

fun test_the_view_scrolls_with_the_selection()
  let table = users()
  let screen = b.Buffer.create(12, 3)
  let area = l.Rect.create(0, 0, 12, 3)
  table.move_to(2)
  table.render(screen, area, true)
  assert_eq(screen.lines()[1].substring(0, 7), "  2 Ada")
  assert_eq(screen.lines()[2].substring(0, 7), " 33 Bob")
end
