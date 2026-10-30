import "block.q" as bk
import "buffer.q" as b
import "layout.q" as l
import "style.q" as st

fun area(w: int, h: int) -> l.Rect
  l.Rect.create(0, 0, w, h)
end

fun test_a_frame_with_a_title_gives_the_inside()
  let screen = b.Buffer.create(12, 4)
  let inside = bk.Block.create().title("Hi").render(screen, area(12, 4))
  assert_eq(screen.lines(), ["┌ Hi ──────┐", "│          │", "│          │", "└──────────┘"])
  assert_eq(inside.x, 1)
  assert_eq(inside.y, 1)
  assert_eq(inside.w, 10)
  assert_eq(inside.h, 2)
end

fun test_the_other_borders()
  let screen = b.Buffer.create(4, 3)
  bk.Block.create().rounded().render(screen, area(4, 3))
  assert_eq(screen.lines(), ["╭──╮", "│  │", "╰──╯"])
  let ascii = b.Buffer.create(4, 3)
  bk.Block.create().ascii().render(ascii, area(4, 3))
  assert_eq(ascii.lines(), ["+--+", "|  |", "+--+"])
  let double = b.Buffer.create(3, 3)
  bk.Block.create().double().render(double, area(3, 3))
  assert_eq(double.lines(), ["╔═╗", "║ ║", "╚═╝"])
end

fun test_the_title_can_sit_in_the_middle_or_on_the_right()
  let centered = b.Buffer.create(12, 3)
  bk.Block.create().title("ab").title_align("center").render(centered, area(12, 3))
  assert_eq(centered.lines()[0], "┌─── ab ───┐")
  let right = b.Buffer.create(12, 3)
  bk.Block.create().title("ab").title_align("right").render(right, area(12, 3))
  assert_eq(right.lines()[0], "┌────── ab ┐")
end

fun test_a_long_title_is_cut_to_fit()
  let screen = b.Buffer.create(10, 3)
  bk.Block.create().title("a very long title").render(screen, area(10, 3))
  assert_eq(screen.lines()[0], "┌ a ver… ┐")
end

fun test_no_border_gives_the_whole_area()
  let screen = b.Buffer.create(4, 2)
  let inside = bk.Block.create().borderless().title("x").render(screen, area(4, 2))
  assert_eq(inside.w, 4)
  assert_eq(screen.lines(), ["", ""])
end

fun test_a_rectangle_too_small_is_left_alone()
  let screen = b.Buffer.create(4, 3)
  let inside = bk.Block.create().render(screen, area(1, 3))
  assert(inside.is_empty())
  assert_eq(screen.lines(), ["", "", ""])
end

fun test_the_styles_go_to_the_frame_and_the_background_to_the_inside()
  let screen = b.Buffer.create(6, 3)
  let cyan = st.Style.create().fg(st.Color.ansi(6))
  let blue = st.Style.create().bg(st.Color.ansi(4))
  bk.Block.create().border_style(cyan).background(blue).render(screen, area(6, 3))
  assert_eq(screen.style_at(0, 0).fg, cyan.fg)
  assert_eq(screen.style_at(2, 1).bg, blue.bg)
end

fun test_wide_characters_in_a_title_are_measured_in_columns()
  let screen = b.Buffer.create(10, 3)
  bk.Block.create().title("漢字").render(screen, area(10, 3))
  assert_eq(screen.lines()[0], "┌ 漢字 ──┐")
end
