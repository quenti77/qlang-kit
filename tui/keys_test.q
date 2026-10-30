import "keys.q" as k

fun key(name: string) -> Event
  Event { kind: "key", key: name }
end

fun test_plain_keys_and_modifiers_are_read_from_text()
  let save = k.Chord.parse("ctrl+s")
  assert(save.ctrl)
  assert(not save.alt)
  assert_eq(save.key, "s")
  let all = k.Chord.parse("ctrl+alt+shift+Tab")
  assert(all.ctrl and all.alt and all.shift)
  assert_eq(all.key, "Tab")
  assert_eq(k.Chord.parse("+").key, "+")
  assert_eq(k.Chord.parse("ctrl++").key, "+")
  assert(k.Chord.parse("ctrl++").ctrl)
end

fun test_a_chord_matches_only_its_own_modifiers()
  let save = k.Chord.parse("ctrl+s")
  assert(save.matches(Event { kind: "key", key: "s", ctrl: true }))
  assert(not save.matches(key("s")))
  assert(not save.matches(Event { kind: "key", key: "s", ctrl: true, alt: true }))
  assert(not save.matches(Event { kind: "mouse", action: "down" }))
end

fun test_a_capital_letter_means_shift()
  let big = k.Chord.parse("G")
  assert(big.matches(key("G")))
  assert(big.matches(Event { kind: "key", key: "g", shift: true }))
  assert(not big.matches(key("g")))
  let small = k.Chord.parse("g")
  assert(small.matches(key("g")))
  assert(not small.matches(key("G")))
end

fun test_symbols_ignore_shift_and_named_keys_compare_it()
  let help = k.Chord.parse("?")
  assert(help.matches(key("?")))
  assert(help.matches(Event { kind: "key", key: "?", shift: true }))
  let back = k.Chord.parse("shift+Tab")
  assert(back.matches(Event { kind: "key", key: "Tab", shift: true }))
  assert(not back.matches(key("Tab")))
  assert(k.Chord.parse("F5").matches(key("F5")))
end

fun test_a_keymap_finds_the_action_and_rebinding_replaces_it()
  let keys = k.Keymap.create().bind("q", "quit").bind("ctrl+s", "save").bind("?", "help")
  assert_eq(keys.action_for(key("q")), "quit")
  assert_eq(keys.action_for(Event { kind: "key", key: "s", ctrl: true }), "save")
  assert_eq(keys.action_for(key("z")), "")
  keys.bind("q", "close")
  assert_eq(keys.action_for(key("q")), "close")
  assert_eq(keys.chord_of("save"), "ctrl+s")
end

fun test_hints_follow_the_order_asked_and_skip_unbound_actions()
  let keys = k.Keymap.create().bind("q", "quit").bind("ctrl+s", "save")
  assert_eq(keys.hints(["save", "nothing", "quit"]), [["ctrl+s", "save"], ["q", "quit"]])
end

fun test_tab_moves_the_focus_round()
  let focus = k.FocusRing.create(["list", "search", "details"])
  assert(focus.has("list"))
  assert(focus.handle(key("Tab")))
  assert(focus.has("search"))
  focus.handle(key("Tab"))
  focus.handle(key("Tab"))
  assert(focus.has("list"))
  assert(focus.handle(Event { kind: "key", key: "Tab", shift: true }))
  assert_eq(focus.focused(), "details")
  assert(not focus.handle(key("x")))
  assert(focus.focus("search"))
  assert(not focus.focus("missing"))
end

fun test_an_empty_ring_is_harmless()
  let focus = k.FocusRing.create([])
  focus.next()
  focus.prev()
  assert_eq(focus.focused(), "")
end
