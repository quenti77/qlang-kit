import "layout.q" as l

fun widths(rects: array<l.Rect>) -> array<int>
  rects.map(fun(r: l.Rect) -> int r.w end)
end

fun test_fixed_and_fill_share_a_row()
  let screen = l.Rect.create(0, 0, 80, 24)
  let parts = screen.split_row([l.Size.fixed(20), l.Size.fill(1)], 0)
  assert_eq(widths(parts), [20, 60])
  assert_eq(parts[1].x, 20)
  assert_eq(parts[1].h, 24)
end

fun test_gaps_are_taken_off_and_left_between_the_parts()
  let parts = l.Rect.create(0, 0, 21, 5).split_row([l.Size.fill(1), l.Size.fill(1), l.Size.fill(1)], 1)
  assert_eq(widths(parts), [6, 6, 7])
  assert_eq(parts[1].x, 7)
  assert_eq(parts[2].x, 14)
end

fun test_fill_weights_and_percent()
  let parts = l.Rect.create(0, 0, 100, 3).split_row([l.Size.percent(25), l.Size.fill(1), l.Size.fill(2)], 0)
  assert_eq(widths(parts), [25, 25, 50])
end

fun test_the_rounding_goes_to_the_last_part_that_grows()
  let parts = l.Rect.create(0, 0, 10, 1).split_row([l.Size.fill(1), l.Size.fill(1), l.Size.fill(1)], 0)
  assert_eq(widths(parts), [3, 3, 4])
end

fun test_a_column_split_stacks_rows()
  let parts = l.Rect.create(2, 3, 40, 24).split_column([l.Size.fixed(1), l.Size.fill(1), l.Size.fixed(1)], 0)
  assert_eq(parts.map(fun(r: l.Rect) -> int r.h end), [1, 22, 1])
  assert_eq(parts[2].y, 26)
  assert_eq(parts[0].x, 2)
end

fun test_a_terminal_that_is_too_small_gives_empty_rectangles()
  let parts = l.Rect.create(0, 0, 3, 1).split_row([l.Size.fixed(10), l.Size.fixed(10), l.Size.fill(1)], 1)
  assert_eq(widths(parts), [1, 0, 0])
  assert(parts[2].is_empty())
end

fun test_inner_shrink_and_center()
  let r = l.Rect.create(0, 0, 10, 6)
  let inner = r.inner(1)
  assert_eq(inner.x, 1)
  assert_eq(inner.w, 8)
  assert_eq(inner.h, 4)
  assert_eq(r.inner(9).w, 0)
  let c = r.center(4, 2)
  assert_eq(c.x, 3)
  assert_eq(c.y, 2)
  assert_eq(r.center(40, 40).w, 10)
end

fun test_intersect_and_contains()
  let a = l.Rect.create(0, 0, 10, 10)
  let b = l.Rect.create(5, 5, 10, 10)
  let both = a.intersect(b)
  assert_eq(both.x, 5)
  assert_eq(both.w, 5)
  assert(a.intersect(l.Rect.create(20, 20, 2, 2)).is_empty())
  assert(a.contains(9, 9))
  assert(not a.contains(10, 0))
end

fun test_a_grid_goes_row_by_row()
  let cells = l.Rect.create(0, 0, 10, 4).grid(2, 2)
  assert_eq(cells.len(), 4)
  assert_eq(cells[1].x, 5)
  assert_eq(cells[2].y, 2)
  assert_eq(l.Rect.create(0, 0, 10, 4).grid(0, 2).len(), 0)
end
