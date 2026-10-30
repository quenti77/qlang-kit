--" # Asking questions in a command

A `Session` is how a command asks for what it needs. For each question it looks, in this order, at:

1. an **answer already given** (`--name Post` on the command line, or a test): it is checked against the
   rules and used without asking;
2. the **terminal**: if there is one, the question is shown as a prompt;
3. the **default**: with no terminal (a pipe, CI, `--no-interaction`) the default is used, and a question that has
   none is an error that says which answer to give.

```
let ask = Session.create({"name": "Post"})                  -- answers from the command line
let name = ask.text("name", "Name of the controller", "", [required()])
let kind = ask.select("kind", "What to make?", ["controller", "model"], "controller")
let sure = ask.confirm("force", "Replace the files?", false)
```

Pressing `Esc` or `Ctrl+C` at a prompt gives `Err` "cancelled".
--"
import "../tui/app.q" as ap
import "../tui/testing.q" as t
import "prompts.q" as pr
import "rules.q" as rules

--" Runs a prompt frame and says whether it was answered (not cancelled). --"
type Driver = fun(pr.Frame) -> Result<bool, Error>

--" The terminal: the prompt takes the screen until it is answered. --"
fun terminal_driver() -> Driver
  fun(frame: pr.Frame) -> Result<bool, Error>
    let ran = ap.run_in_terminal(frame)
    if ran.is_err() then
      return ran
    end
    Result<bool, Error>.Ok(frame.finished)
  end
end

--" Answers prompts from a script, for tests: one list of keys for each prompt, in order. An entry is a key name
(`"Enter"`, `"Down"`, `" "`) or `"type:text"` for a run of characters. A prompt left without keys is cancelled. --"
fun scripted_driver(script: array<array<string>>) -> Driver
  let next = [0]
  fun(frame: pr.Frame) -> Result<bool, Error>
    let at = next[0]
    next[0] = at + 1
    if at >= script.len() then
      return Result<bool, Error>.Ok(false)
    end
    let app = t.Harness.start(80, 24, frame)
    for entry in script[at] do
      if entry.starts_with("type:") then
        app.text(entry.substring(5, entry.len()))
      else
        app.key(entry)
      end
    end
    Result<bool, Error>.Ok(frame.finished)
  end
end

--" Where the answers come from. --"
struct Session
  public interactive: bool
  public answers: map<string, string>
  public driver: Driver
end

fun cancelled<T>() -> Result<T, Error>
  Result<T, Error>.Err(Error { message: "cancelled" })
end

fun missing<T>(key: string, label: string) -> Result<T, Error>
  Result<T, Error>.Err(Error { message: "{label}: no answer (give --{key}, or run in a terminal)" })
end

fun refused<T>(label: string, why: string) -> Result<T, Error>
  Result<T, Error>.Err(Error { message: "{label}: {why}" })
end

fun frame_of(p: pr.Prompt, label: string, hint: string) -> pr.Frame
  pr.Frame { prompt: p, label: label, hint: hint, cancelled: false, finished: false }
end

impl Session
  --" A session in the terminal when there is one; `answers` are the ones already given (key to text). --"
  public fun create(answers: map<string, string>) -> Session
    Session { interactive: Term.is_tty(), answers: answers, driver: terminal_driver() }
  end

  --" A session that never asks (the answers, then the defaults). --"
  public fun silent(answers: map<string, string>) -> Session
    Session { interactive: false, answers: answers, driver: scripted_driver([]) }
  end

  --" A session that asks through `driver` (see `scripted_driver`). --"
  public fun with_driver(answers: map<string, string>, driver: Driver) -> Session
    Session { interactive: true, answers: answers, driver: driver }
  end

  --" A line of text. `rule_list` is checked on answers given in advance too. --"
  public fun text(self, key: string, label: string, default: string, rule_list: array<rules.Rule>) -> Result<string, Error>
    let given = self.answers[key]
    if given != none then
      let problem = rules.check_all(rule_list, given)
      if problem != none then
        return refused<string>(label, problem)
      end
      return Result<string, Error>.Ok(given)
    end
    if not self.interactive then
      if default == "" then
        let problem = rules.check_all(rule_list, "")
        if problem != none then
          return missing<string>(key, label)
        end
      end
      return Result<string, Error>.Ok(default)
    end
    let p = pr.TextPrompt.create("", default, false, rule_list)
    let done = self.driver(frame_of(p, label, ""))
    if done.is_err() then
      return Result<string, Error>.Err(done.unwrap_err())
    end
    if not done.unwrap() then
      return cancelled<string>()
    end
    Result<string, Error>.Ok(p.answer())
  end

  --" A secret: never taken from the defaults, and never shown. --"
  public fun password(self, key: string, label: string, rule_list: array<rules.Rule>) -> Result<string, Error>
    let given = self.answers[key]
    if given != none then
      let problem = rules.check_all(rule_list, given)
      if problem != none then
        return refused<string>(label, problem)
      end
      return Result<string, Error>.Ok(given)
    end
    if not self.interactive then
      return missing<string>(key, label)
    end
    let p = pr.TextPrompt.create("", "", true, rule_list)
    let done = self.driver(frame_of(p, label, ""))
    if done.is_err() then
      return Result<string, Error>.Err(done.unwrap_err())
    end
    if not done.unwrap() then
      return cancelled<string>()
    end
    Result<string, Error>.Ok(p.answer())
  end

  --" Yes or no. A given answer is `yes`, `y`, `true`, `1`, `no`, `n`, `false` or `0`. --"
  public fun confirm(self, key: string, label: string, default: bool) -> Result<bool, Error>
    let given = self.answers[key]
    if given != none then
      let a = given.lower()
      if a == "yes" or a == "y" or a == "true" or a == "1" then
        return Result<bool, Error>.Ok(true)
      end
      if a == "no" or a == "n" or a == "false" or a == "0" then
        return Result<bool, Error>.Ok(false)
      end
      return refused<bool>(label, "answer yes or no")
    end
    if not self.interactive then
      return Result<bool, Error>.Ok(default)
    end
    let p = pr.ConfirmPrompt { yes: default }
    let done = self.driver(frame_of(p, label, ""))
    if done.is_err() then
      return Result<bool, Error>.Err(done.unwrap_err())
    end
    if not done.unwrap() then
      return cancelled<bool>()
    end
    Result<bool, Error>.Ok(p.yes)
  end

  --" One of the options. `default` is one of them or `""`. --"
  public fun select(self, key: string, label: string, options: array<string>, default: string) -> Result<string, Error>
    let given = self.answers[key]
    if given != none then
      if not options.contains(given) then
        return refused<string>(label, "one of: " + options.join(", "))
      end
      return Result<string, Error>.Ok(given)
    end
    if not self.interactive then
      if default == "" then
        return missing<string>(key, label)
      end
      return Result<string, Error>.Ok(default)
    end
    let start = options.index_of(default) ?? 0
    let p = pr.SelectPrompt.create(options, start)
    let done = self.driver(frame_of(p, label, ""))
    if done.is_err() then
      return Result<string, Error>.Err(done.unwrap_err())
    end
    if not done.unwrap() then
      return cancelled<string>()
    end
    Result<string, Error>.Ok(p.answer())
  end

  --" Several of the options. A given answer is the options separated by commas. --"
  public fun multiselect(self, key: string, label: string, options: array<string>, default: array<string>, minimum: int) -> Result<array<string>, Error>
    let given = self.answers[key]
    if given != none then
      let chosen = given.split(",").map(fun(s: string) -> string s.trim() end).filter(fun(s: string) -> bool s != "" end)
      for c in chosen do
        if not options.contains(c) then
          return refused<array<string>>(label, "`{c}` is not one of: " + options.join(", "))
        end
      end
      if chosen.len() < minimum then
        return refused<array<string>>(label, "choose at least {minimum}")
      end
      return Result<array<string>, Error>.Ok(chosen)
    end
    if not self.interactive then
      if default.len() < minimum then
        return missing<array<string>>(key, label)
      end
      return Result<array<string>, Error>.Ok(default)
    end
    let p = pr.MultiPrompt.create(options, default, minimum)
    let done = self.driver(frame_of(p, label, "space ticks, a ticks all"))
    if done.is_err() then
      return Result<array<string>, Error>.Err(done.unwrap_err())
    end
    if not done.unwrap() then
      return cancelled<array<string>>()
    end
    Result<array<string>, Error>.Ok(p.answers())
  end

  --" A text with suggestions. With `strict` the answer must be one of the options. --"
  public fun suggest(self, key: string, label: string, options: array<string>, strict: bool, default: string) -> Result<string, Error>
    let given = self.answers[key]
    if given != none then
      if strict and not options.contains(given) then
        return refused<string>(label, "one of: " + options.join(", "))
      end
      return Result<string, Error>.Ok(given)
    end
    if not self.interactive then
      if default == "" then
        return missing<string>(key, label)
      end
      return Result<string, Error>.Ok(default)
    end
    let p = pr.AutoPrompt.create("", options, strict)
    let done = self.driver(frame_of(p, label, "type to narrow, tab completes"))
    if done.is_err() then
      return Result<string, Error>.Err(done.unwrap_err())
    end
    if not done.unwrap() then
      return cancelled<string>()
    end
    Result<string, Error>.Ok(p.answer())
  end
end

export Session, Driver, terminal_driver, scripted_driver
