import "../tui/testing.q" as t
import "app.q" as r

fun first_output() -> string
  "ok   x_test.q::test_a\nFAIL x_test.q::test_b\n     error[R050]: panic: assert_eq failed\n       actual:   1\n       expected: 2\n       --> x_test.q:3:3\nok   y_test.q::test_c\n\n2 passed, 1 failed\n"
end

fun fixed_output() -> string
  "ok   x_test.q::test_a\nok   x_test.q::test_b\nok   y_test.q::test_c\n\n3 passed, 0 failed\n"
end

struct Fake
  public files: map<string, string>
  public output: array<string>
  public calls: array<array<string>>
  public ms: int
end

fun fake() -> Fake
  Fake { files: {"x_test.q": "fun test_a()\n  assert_eq(1, 1)\nend\n  assert_eq(1, 2)\n", "y_test.q": "fun test_c()\nend\n"}, output: [first_output()], calls: [], ms: 0 }
end

fun source(f: Fake) -> r.Source
  let files = fun() -> array<string>
    f.files.keys()
  end
  let read = fun(path: string) -> Result<string, Error>
    let found = f.files[path]
    if found == none then
      return Result<string, Error>.Err(Error { message: "not found" })
    end
    Result<string, Error>.Ok(found)
  end
  let exec = fun(args: array<string>) -> Result<string, Error>
    f.calls.push(args)
    f.ms += 40
    let at = if f.calls.len() > f.output.len() then f.output.len() - 1 else f.calls.len() - 1 end
    Result<string, Error>.Ok(f.output[at])
  end
  r.Source { files: files, read: read, exec: exec, clock: fun() -> int f.ms end }
end

fun start(f: Fake) -> t.Harness
  let app = t.Harness.start(110, 30, r.create(source(f)))
  app.context().after("go", 10)
  app.context().every("poll", 1000)
  app.advance(10)
  app
end

fun test_the_first_run_shows_the_verdicts_and_the_totals()
  let app = start(fake())
  assert(app.contains("2 passed"))
  assert(app.contains("1 failed"))
  assert(app.contains("✓ x_test.q::test_a"))
  assert(app.contains("✗ x_test.q::test_b"))
  assert(app.contains("run 1"))
end

fun test_a_failure_shows_its_message_and_the_source_around_it()
  let f = fake()
  let app = start(f)
  app.key("Down")
  assert(app.contains("assert_eq failed"))
  assert(app.contains("x_test.q:3"))
  assert(app.contains(">    3 |"))
  assert(app.contains("fun test_a()"))
end

fun test_a_passing_test_says_so()
  let app = start(fake())
  assert(app.contains("passed"))
end

fun test_r_runs_everything_again()
  let f = fake()
  f.output = [first_output(), fixed_output()]
  let app = start(f)
  app.key("r")
  app.advance(10)
  assert(app.contains("3 passed"))
  assert(app.contains("0 failed"))
  assert_eq(f.calls.len(), 2)
  assert_eq(f.calls[1], ["test"])
end

fun test_enter_runs_only_the_selected_test_and_updates_it_in_the_report()
  let f = fake()
  f.output = [first_output(), "ok   x_test.q::test_b\n\n1 passed, 0 failed\n"]
  let app = start(f)
  app.key("Down")
  app.key("Enter")
  app.advance(10)
  assert_eq(f.calls[1], ["test", "x_test.q", "--filter", "test_b"])
  assert(app.contains("3 passed"))
  assert(app.contains("0 failed"))
end

fun test_a_changed_file_triggers_a_run_when_watching()
  let f = fake()
  f.output = [first_output(), fixed_output()]
  let app = start(f)
  app.advance(1000)
  assert_eq(f.calls.len(), 1)
  f.files["x_test.q"] = "fun test_a()\n  assert_eq(1, 1)\nend\n"
  app.advance(1000)
  app.advance(10)
  assert_eq(f.calls.len(), 2)
  assert(app.contains("0 failed"))
  app.advance(5000)
  assert_eq(f.calls.len(), 2)
end

fun test_a_new_file_also_counts_as_a_change()
  let f = fake()
  let app = start(f)
  f.files["z_test.q"] = "fun test_z()\nend\n"
  app.advance(1000)
  app.advance(10)
  assert_eq(f.calls.len(), 2)
end

fun test_w_stops_the_watching()
  let f = fake()
  let app = start(f)
  app.key("w")
  assert(app.contains("not watching"))
  f.files["x_test.q"] = "changed"
  app.advance(1000)
  app.advance(10)
  assert_eq(f.calls.len(), 1)
end

fun test_f_shows_only_the_failures()
  let app = start(fake())
  app.key("f")
  assert(app.contains("Failures"))
  assert(app.contains("✗ x_test.q::test_b"))
  assert(not app.contains("✓ y_test.q::test_c"))
  app.key("f")
  assert(app.contains("✓ y_test.q::test_c"))
end

fun test_q_quits()
  let app = start(fake())
  app.key("q")
  assert(app.finished())
end
