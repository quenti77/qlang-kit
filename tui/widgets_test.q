import "buffer.q" as b
import "help.q" as h
import "layout.q" as l
import "progress.q" as p
import "style.q" as st
import "tabs.q" as tb

fun key(name: string) -> Event
  Event { kind: "key", key: name }
end

fun test_tabs_cycle_and_jump_by_number()
  let tabs = tb.Tabs.create(["Routes", "Queries", "Logs"])
  tabs.handle(key("Right"))
  assert_eq(tabs.active_title(), "Queries")
  tabs.handle(key("Right"))
  tabs.handle(key("Tab"))
  assert_eq(tabs.active, 0)
  tabs.handle(Event { kind: "key", key: "Tab", shift: true })
  assert_eq(tabs.active, 2)
  tabs.handle(key("2"))
  assert_eq(tabs.active, 1)
  assert(not tabs.handle(key("7")))
  assert(not tabs.handle(key("x")))
end

fun test_tabs_are_drawn_with_the_active_one_reversed_and_can_be_clicked()
  let tabs = tb.Tabs.create(["One", "Two"])
  let screen = b.Buffer.create(20, 1)
  let area = l.Rect.create(0, 0, 20, 1)
  tabs.render(screen, area)
  assert_eq(screen.lines(), [" One   Two"])
  assert_eq(screen.style_at(1, 0).attrs, 17)
  assert_eq(screen.style_at(7, 0).attrs, 2)
  assert(tabs.click(area, Event { kind: "mouse", action: "down", x: 7, y: 0 }))
  assert_eq(tabs.active, 1)
  assert(not tabs.click(area, Event { kind: "mouse", action: "down", x: 5, y: 0 }))
end

fun test_an_empty_tab_bar_is_harmless()
  let tabs = tb.Tabs.create([])
  tabs.handle(key("Right"))
  assert_eq(tabs.active_title(), "")
  tabs.render(b.Buffer.create(5, 1), l.Rect.create(0, 0, 5, 1))
end

fun test_the_bar_fills_in_eighths()
  assert_eq(p.Progress.bar(0.0, 4), "    ")
  assert_eq(p.Progress.bar(1.0, 4), "████")
  assert_eq(p.Progress.bar(0.5, 4), "██  ")
  assert_eq(p.Progress.bar(0.375, 4), "█▌  ")
  assert_eq(p.Progress.bar(2.0, 2), "██")
  assert_eq(p.Progress.bar(-1.0, 2), "  ")
end

fun test_the_bar_is_drawn_with_a_percentage()
  let screen = b.Buffer.create(20, 1)
  p.Progress.draw(screen, l.Rect.create(0, 0, 20, 1), 0.5, st.Style.create())
  assert_eq(screen.lines()[0], "███████▌         50%")
end

fun test_the_spinner_goes_round()
  let spin = p.Spinner.create()
  assert_eq(spin.frame(), "⠋")
  spin.tick()
  assert_eq(spin.frame(), "⠙")
  for _i in 0..9 do
    spin.tick()
  end
  assert_eq(spin.frame(), "⠋")
end

fun test_hints_are_laid_out_and_the_ones_that_do_not_fit_are_dropped()
  let help = h.HelpBar.create([["q", "quit"], ["↑↓", "move"], ["enter", "open"]])
  let wide = b.Buffer.create(40, 1)
  help.render(wide, l.Rect.create(0, 0, 40, 1))
  assert_eq(wide.lines(), ["q quit  ↑↓ move  enter open"])
  let narrow = b.Buffer.create(16, 1)
  help.render(narrow, l.Rect.create(0, 0, 16, 1))
  assert_eq(narrow.lines(), ["q quit  …"])
end
