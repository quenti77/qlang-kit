import "rules.q" as r

fun test_each_rule_complains_with_its_message()
  assert_eq(r.required()("  "), "this is required")
  assert_eq(r.required()("x"), none)
  assert_eq(r.min_length(3)("ab"), "at least 3 characters")
  assert_eq(r.max_length(2)("abc"), "at most 2 characters")
  assert_eq(r.integer()("12"), none)
  assert_eq(r.integer()("x"), "a whole number, please")
  assert_eq(r.one_of(["a", "b"])("c"), "one of: a, b")
  assert_eq(r.matches("^[a-z]+$", "letters")("A1"), "letters")
end

fun test_check_all_stops_at_the_first_complaint()
  let rules = [r.required(), r.min_length(3), r.integer()]
  assert_eq(r.check_all(rules, ""), "this is required")
  assert_eq(r.check_all(rules, "ab"), "at least 3 characters")
  assert_eq(r.check_all(rules, "abc"), "a whole number, please")
  assert_eq(r.check_all(rules, "123"), none)
  assert_eq(r.check_all([], "anything"), none)
end
