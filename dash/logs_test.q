import "logs.q" as lg

fun test_a_json_line_is_read()
  let e = lg.parse_line("\{\"time\":\"2026-10-30T10:00:00Z\",\"level\":\"WARN\",\"message\":\"slow query\",\"ms\":120}")
  assert_eq(e.level, "warn")
  assert_eq(e.message, "slow query")
  assert_eq(e.time, "2026-10-30T10:00:00Z")
end

fun test_a_text_line_with_a_level_is_read()
  let e = lg.parse_line("ERROR could not connect")
  assert_eq(e.level, "error")
  assert_eq(e.message, "could not connect")
  let plain = lg.parse_line("started on port 8000")
  assert_eq(plain.level, "info")
  assert_eq(plain.message, "started on port 8000")
end

fun test_a_json_line_that_is_broken_is_kept_as_text()
  let e = lg.parse_line("\{not json")
  assert_eq(e.level, "info")
  assert_eq(e.message, "\{not json")
end

fun test_filter_keeps_the_level_and_the_text()
  let entries = lg.parse_all("DEBUG a thing\nINFO users listed\nWARN users slow\nERROR boom\n\n")
  assert_eq(entries.len(), 4)
  assert_eq(lg.filter(entries, "warn", "").len(), 2)
  assert_eq(lg.filter(entries, "", "USERS").len(), 2)
  assert_eq(lg.filter(entries, "warn", "users").len(), 1)
  assert_eq(lg.filter(entries, "", "").len(), 4)
end

fun test_the_n_plus_one_warning_is_found()
  let e = lg.parse_line("WARN N+1? GET /users ran the same statement 12 times")
  assert(lg.is_n_plus_one(e))
  assert(not lg.is_n_plus_one(lg.parse_line("INFO fine")))
end
