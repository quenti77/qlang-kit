--" # kit in a project

`kit init` makes a project use kit as a **dependency**: the version is the one of the project's `qlang.toml` (and its
lock file), so everyone who works on the project runs the same kit. It adds the dependency, and writes `kit.q`, the file
that starts kit from the package.

```
qlang install
qlang run --allow-process kit.q -- make controller Post
```
--"
import "make.q" as mk

fun launcher() -> string
  [
    "-- Starts kit from the package this project depends on (see qlang.toml):",
    "--   qlang run --allow-process kit.q -- make controller Post",
    "--   qlang run --allow-process kit.q -- test",
    "import \"@kit/cli.q\" as cli",
    "import \"@kit/runner/app.q\" as runner",
    "",
    "fun test_runner() -> int",
    "  let ran = runner.run()",
    "  if ran.is_err() then",
    "    print(\"test: \" + ran.unwrap_err().message)",
    "    return 1",
    "  end",
    "  0",
    "end",
    "",
    "let code = cli.run_command(env.args(), test_runner)",
    "if code != 0 then",
    "  exit(code)",
    "end",
  ].join("\n") + "\n"
end

fun dependency_line(version: string) -> string
  "kit = \{ git = \"https://github.com/quenti77/qlang-kit\", tag = \"v" + version + "\" }"
end

--" `qlang.toml` with the kit dependency added; `none` when it already has one. --"
fun with_dependency(toml: string, version: string) -> string?
  if regex.matches(toml, "(^|\n)kit\\s*=") then
    return none
  end
  let line = dependency_line(version)
  if not toml.contains("[dependencies]") then
    return toml.trim_end() + "\n\n[dependencies]\n" + line + "\n"
  end
  let out: array<string> = []
  for l in toml.split("\n") do
    out.push(l)
    if l.trim() == "[dependencies]" then
      out.push(line)
    end
  end
  out.join("\n")
end

--" What `kit init` would do: add the dependency and write `kit.q`. Without a `qlang.toml` it is an error (a project
has one). --"
fun plan_init(files: mk.Files, version: string, force: bool) -> Result<array<mk.Change>, Error>
  let toml = files.read("qlang.toml")
  if toml.is_err() then
    return Result<array<mk.Change>, Error>.Err(Error { message: "there is no qlang.toml here: run this in a project (qlang init)" })
  end
  let changes: array<mk.Change> = []
  let edited = with_dependency(toml.unwrap(), version)
  if edited != none then
    changes.push(mk.Change { path: "qlang.toml", content: edited, action: "update", note: "kit v" + version })
  end
  if files.exists("kit.q") and not force then
    changes.push(mk.Change { path: "kit.q", content: "", action: "skip", note: "already there (--force replaces it)" })
  else
    changes.push(mk.Change { path: "kit.q", content: launcher(), action: if files.exists("kit.q") then "update" else "create" end, note: "" })
  end
  Result<array<mk.Change>, Error>.Ok(changes)
end

export launcher, with_dependency, plan_init
