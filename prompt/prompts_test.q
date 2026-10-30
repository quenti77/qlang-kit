import "../tui/testing.q" as t
import "prompts.q" as pr
import "rules.q" as r

fun frame(p: pr.Prompt, label: string, hint: string) -> pr.Frame
  pr.Frame { prompt: p, label: label, hint: hint, cancelled: false, finished: false }
end

fun open(f: pr.Frame) -> t.Harness
  t.Harness.start(80, 24, f)
end

fun test_text_is_typed_and_accepted_with_enter()
  let p = pr.TextPrompt.create("name", "", false, [])
  let f = frame(p, "Your name", "as on the badge")
  let app = open(f)
  assert(app.contains("Your name"))
  assert(app.contains("as on the badge"))
  app.text("Ada")
  assert(app.contains("Ada"))
  app.key("Enter")
  assert(app.finished())
  assert(f.finished)
  assert_eq(p.answer(), "Ada")
end

fun test_a_rule_keeps_the_prompt_open_and_shows_why()
  let p = pr.TextPrompt.create("", "", false, [r.required(), r.min_length(3)])
  let f = frame(p, "Name", "")
  let app = open(f)
  app.key("Enter")
  assert(not app.finished())
  assert(app.contains("! this is required"))
  app.text("ab")
  assert(not app.contains("! this is required"))
  app.key("Enter")
  assert(app.contains("! at least 3 characters"))
  app.key("c")
  app.key("Enter")
  assert(app.finished())
  assert_eq(p.answer(), "abc")
end

fun test_the_default_is_taken_when_nothing_is_typed()
  let p = pr.TextPrompt.create("", "blog", false, [])
  let app = open(frame(p, "Name", ""))
  assert(app.contains("blog"))
  app.ctrl("u")
  app.key("Enter")
  assert_eq(p.answer(), "blog")
end

fun test_a_password_is_not_shown()
  let p = pr.TextPrompt.create("", "", true, [])
  let app = open(frame(p, "Password", ""))
  app.text("s3cret")
  assert(not app.contains("s3cret"))
  assert(app.contains("••••••"))
  app.key("Enter")
  assert_eq(p.answer(), "s3cret")
end

fun test_escape_and_ctrl_c_cancel()
  let f = frame(pr.TextPrompt.create("", "", false, []), "Name", "")
  let app = open(f)
  app.key("Esc")
  assert(app.finished())
  assert(f.cancelled)
  assert(not f.finished)
  let g = frame(pr.TextPrompt.create("", "", false, []), "Name", "")
  let other = open(g)
  other.ctrl("c")
  assert(other.finished())
  assert(not g.finished)
end

fun test_confirm_answers_with_letters_and_arrows()
  let p = pr.ConfirmPrompt { yes: false }
  let app = open(frame(p, "Delete?", ""))
  assert(app.contains("[ Yes ]"))
  app.key("y")
  assert(app.finished())
  assert(p.yes)
  let q = pr.ConfirmPrompt { yes: false }
  let other = open(frame(q, "Delete?", ""))
  other.key("Right")
  other.key("Enter")
  assert(q.yes)
  let n = pr.ConfirmPrompt { yes: true }
  let third = open(frame(n, "Delete?", ""))
  third.key("n")
  assert(not n.yes)
  assert(third.finished())
end

fun test_select_moves_and_chooses()
  let p = pr.SelectPrompt.create(["sqlite", "postgres", "mysql"], 0)
  let app = open(frame(p, "Database", ""))
  assert(app.contains("sqlite"))
  app.key("Down")
  app.key("Enter")
  assert(app.finished())
  assert_eq(p.answer(), "postgres")
end

fun test_select_with_no_options_cannot_be_accepted()
  let p = pr.SelectPrompt.create([], 0)
  let app = open(frame(p, "Nothing", ""))
  app.key("Enter")
  assert(not app.finished())
end

fun test_multi_select_ticks_with_space_and_all_with_a()
  let p = pr.MultiPrompt.create(["web", "api", "cli"], ["api"], 0)
  let app = open(frame(p, "Parts", ""))
  assert(app.contains("[x] api"))
  app.key("Down")
  app.key("Down")
  app.key(" ")
  assert(app.contains("[x] cli"))
  app.key("Enter")
  assert(app.finished())
  assert_eq(p.answers(), ["api", "cli"])
  let all = pr.MultiPrompt.create(["a", "b"], [], 0)
  let again = open(frame(all, "x", ""))
  again.key("a")
  assert_eq(all.answers(), ["a", "b"])
  again.key("a")
  assert_eq(all.answers(), [])
end

fun test_multi_select_can_require_a_minimum()
  let p = pr.MultiPrompt.create(["a", "b"], [], 1)
  let app = open(frame(p, "Parts", ""))
  app.key("Enter")
  assert(not app.finished())
  assert(app.contains("! choose at least 1"))
  app.key(" ")
  app.key("Enter")
  assert(app.finished())
end

fun test_autocomplete_narrows_completes_and_accepts()
  let p = pr.AutoPrompt.create("kind", ["controller", "model", "migration", "middleware"], true)
  let app = open(frame(p, "Kind", ""))
  app.text("mi")
  assert(app.contains("migration"))
  assert(app.contains("middleware"))
  assert(not app.contains("controller"))
  app.key("Down")
  app.key("Tab")
  assert(app.contains("middleware"))
  app.key("Enter")
  assert(app.finished())
  assert_eq(p.answer(), "middleware")
end

fun test_a_strict_autocomplete_refuses_what_is_not_a_suggestion()
  let p = pr.AutoPrompt.create("kind", ["model"], true)
  let app = open(frame(p, "Kind", ""))
  app.text("zzz")
  app.key("Enter")
  assert(not app.finished())
  assert(app.contains("! choose one of the suggestions"))
  let free = pr.AutoPrompt.create("kind", ["model"], false)
  let other = open(frame(free, "Kind", ""))
  other.text("zzz")
  other.key("Enter")
  assert(other.finished())
  assert_eq(free.answer(), "zzz")
end
