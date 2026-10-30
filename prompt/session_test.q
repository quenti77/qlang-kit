import "rules.q" as r
import "session.q" as s

fun test_an_answer_given_in_advance_is_used_without_asking()
  let ask = s.Session.with_driver({"name": "Post", "kind": "model"}, s.scripted_driver([]))
  assert_eq(ask.text("name", "Name", "", []).unwrap(), "Post")
  assert_eq(ask.select("kind", "Kind", ["controller", "model"], "controller").unwrap(), "model")
end

fun test_a_given_answer_is_checked()
  let ask = s.Session.silent({"name": "ab", "kind": "widget", "ok": "maybe"})
  let short = ask.text("name", "Name", "", [r.min_length(3)])
  assert_eq(short.unwrap_err().message, "Name: at least 3 characters")
  assert(ask.select("kind", "Kind", ["controller", "model"], "").is_err())
  assert_eq(ask.confirm("ok", "Sure?", false).unwrap_err().message, "Sure?: answer yes or no")
end

fun test_without_a_terminal_defaults_are_used_and_a_missing_answer_says_how_to_give_it()
  let ask = s.Session.silent({})
  assert_eq(ask.text("name", "Name", "blog", []).unwrap(), "blog")
  assert_eq(ask.text("opt", "Optional", "", []).unwrap(), "")
  assert_eq(ask.text("req", "Required", "", [r.required()]).unwrap_err().message, "Required: no answer (give --req, or run in a terminal)")
  assert_eq(ask.confirm("force", "Force?", true).unwrap(), true)
  assert_eq(ask.select("kind", "Kind", ["a", "b"], "b").unwrap(), "b")
  assert(ask.select("kind", "Kind", ["a", "b"], "").is_err())
  assert(ask.password("pw", "Password", []).is_err())
  assert_eq(ask.multiselect("parts", "Parts", ["a", "b"], ["a"], 0).unwrap(), ["a"])
end

fun test_prompts_are_answered_from_the_script()
  let ask = s.Session.with_driver({}, s.scripted_driver([["type:Ada", "Enter"], ["Down", "Enter"], ["Right", "Enter"], ["Down", " ", "Enter"], ["type:mo", "Enter"], ["type:secret", "Enter"]]))
  assert_eq(ask.text("name", "Name", "", []).unwrap(), "Ada")
  assert_eq(ask.select("kind", "Kind", ["controller", "model"], "controller").unwrap(), "model")
  assert_eq(ask.confirm("force", "Force?", false).unwrap(), true)
  assert_eq(ask.multiselect("parts", "Parts", ["a", "b", "c"], [], 1).unwrap(), ["b"])
  assert_eq(ask.suggest("kind", "Kind", ["controller", "model"], true, "").unwrap(), "model")
  assert_eq(ask.password("pw", "Password", []).unwrap(), "secret")
end

fun test_a_prompt_left_without_keys_is_cancelled()
  let ask = s.Session.with_driver({}, s.scripted_driver([["Esc"]]))
  assert_eq(ask.text("name", "Name", "", []).unwrap_err().message, "cancelled")
  assert_eq(ask.confirm("x", "Sure?", false).unwrap_err().message, "cancelled")
end

fun test_multiselect_answers_are_split_on_commas()
  let ask = s.Session.silent({"parts": "a, c"})
  assert_eq(ask.multiselect("parts", "Parts", ["a", "b", "c"], [], 0).unwrap(), ["a", "c"])
  let bad = s.Session.silent({"parts": "a, z"})
  assert(bad.multiselect("parts", "Parts", ["a", "b"], [], 0).is_err())
  let few = s.Session.silent({"parts": ""})
  assert(few.multiselect("parts", "Parts", ["a"], [], 1).is_err())
end

fun test_yes_and_no_have_several_spellings()
  for word in ["yes", "Y", "true", "1"] do
    assert(s.Session.silent({"x": word}).confirm("x", "?", false).unwrap())
  end
  for word in ["no", "N", "false", "0"] do
    assert(not s.Session.silent({"x": word}).confirm("x", "?", true).unwrap())
  end
end
