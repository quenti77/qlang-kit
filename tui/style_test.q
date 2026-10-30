import "style.q" as s

fun test_colours_are_brought_back_to_what_the_terminal_has()
  let orange = s.Color.rgb(255, 170, 0)
  assert_eq(s.Style.create().fg(orange).sgr(16777216), "\e[0;38;2;255;170;0m")
  assert_eq(s.Style.create().fg(orange).sgr(256), "\e[0;38;5;214m")
  assert_eq(s.Style.create().fg(orange).sgr(16), "\e[0;93m")
  assert_eq(s.Style.create().bg(s.Color.ansi(4)).sgr(16), "\e[0;44m")
  assert_eq(s.Style.create().fg(s.Color.ansi(9)).sgr(256), "\e[0;38;5;9m")
  assert_eq(s.Style.create().fg(s.Color.ansi(9)).sgr(16), "\e[0;91m")
end

fun test_no_colour_keeps_the_attributes_only()
  let style = s.Style.create().fg(s.Color.rgb(1, 2, 3)).bg(s.Color.ansi(1)).bold().underline()
  assert_eq(style.sgr(0), "\e[0;1;4m")
end

fun test_attributes_come_in_a_fixed_order_and_never_twice()
  let style = s.Style.create().underline().bold().bold().italic()
  assert_eq(style.sgr(256), "\e[0;1;3;4m")
  assert_eq(style.attrs, 13)
end

fun test_a_style_goes_through_its_key()
  let style = s.Style.create().fg(s.Color.rgb(10, 20, 30)).bg(s.Color.indexed(200)).bold().reverse()
  let back = s.Style.of_key(style.key())
  assert_eq(back.fg, style.fg)
  assert_eq(back.bg, style.bg)
  assert_eq(back.attrs, style.attrs)
  assert(s.Style.create().key() != style.key())
end

fun test_hex_and_out_of_range_colours()
  assert_eq(s.Color.hex("#ff8000"), s.Color.rgb(255, 128, 0))
  assert_eq(s.Color.hex("orange"), 0)
  assert_eq(s.Color.rgb(300, -5, 0), s.Color.rgb(255, 0, 0))
end

fun test_greys_use_the_grey_ramp()
  assert_eq(s.Style.create().fg(s.Color.rgb(128, 128, 128)).sgr(256), "\e[0;38;5;243m")
  assert_eq(s.Style.create().fg(s.Color.rgb(0, 0, 0)).sgr(256), "\e[0;38;5;16m")
end
