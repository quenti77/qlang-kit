import "parse.q" as p

fun sample() -> string
  "ok   x_test.q::test_a\nFAIL x_test.q::test_b\n     error[R050]: panic: assert_eq failed\n       actual:   1\n       expected: 2\n       --> x_test.q:6:3\n       |\n     6 |   assert_eq(1, 2)\n       note: called from `test_b` (x_test.q:5:1)\nok   y_test.q::test_c\n\n2 passed, 1 failed\n"
end

fun test_cases_and_totals_are_read()
  let r = p.parse(sample())
  assert_eq(r.cases.len(), 3)
  assert_eq(r.passed, 2)
  assert_eq(r.failed, 1)
  assert(r.cases[0].ok)
  assert_eq(r.cases[0].file, "x_test.q")
  assert_eq(r.cases[0].name, "test_a")
  assert(not r.cases[1].ok)
  assert(r.cases[2].ok)
end

fun test_a_failure_keeps_its_explanation_and_its_place()
  let r = p.parse(sample())
  let bad = r.cases[1]
  assert_eq(bad.detail.len(), 7)
  assert(bad.detail[0].contains("assert_eq failed"))
  assert_eq(bad.at_file, "x_test.q")
  assert_eq(bad.at_line, 6)
  assert_eq(r.cases[0].detail.len(), 0)
end

fun test_a_failure_at_the_end_is_kept_too()
  let r = p.parse("FAIL z_test.q::test_z\n     error: boom\n       --> z_test.q:2:1\n\n0 passed, 1 failed\n")
  assert_eq(r.cases[0].at_line, 2)
  assert_eq(r.failed, 1)
end

fun test_lines_of_a_file_that_does_not_compile_are_kept_apart()
  let r = p.parse("FAIL w_test.q: it does not compile\nerror[T001]: unknown name\n0 passed, 1 failed\n")
  assert_eq(r.cases.len(), 1)
  assert_eq(r.cases[0].name, "")
  assert(not r.cases[0].ok)
  assert(r.cases[0].detail[0].contains("unknown name"))
end

fun test_empty_output_is_an_empty_report()
  let r = p.parse("")
  assert_eq(r.cases.len(), 0)
  assert_eq(r.passed, 0)
end
