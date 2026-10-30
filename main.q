--" # qlang-kit

The command line tool of the qlang framework.

```
qlang run main.q -- dashboard --url http://localhost:8000 --log app.log
```

| Command | What it does |
| --- | --- |
| `make` | code generators: `make controller Post`, `make migration create_posts_table`... |
| `wizard` | `make` as a full screen: pick, name, preview the files, write |
| `dashboard` | a live terminal view of a running app (routes, requests, logs) |
| `help` | this list |
--"
import "dash/app.q" as dash
import "make/make.q" as mk
import "prompt/rules.q" as rules
import "wizard/app.q" as wiz
import "prompt/session.q" as sess

fun usage() -> string
  "qlang-kit 0.1.0\n\nusage: kit <command> [options]\n\ncommands:\n  make [<kind> <Name>] [--dry-run] [--force] [--no-register] [--no-test] [--no-interaction]   write a controller, model, migration...\n  make --list | --publish-stubs        the kinds | copy the stubs to stubs/ to change them\n  wizard                               make as a full screen, with a preview of the files\n  dashboard [--url URL] [--log FILE]   live view of a running app (default URL http://localhost:8000)\n  help                                 this list\n"
end

--" The value after `--name`, or `fallback`. --"
fun option(args: array<string>, name: string, fallback: string) -> string
  for i in 0..args.len() do
    if args[i] == name and i + 1 < args.len() then
      return args[i + 1]
    end
  end
  fallback
end

fun has(args: array<string>, flag: string) -> bool
  args.contains(flag)
end

fun show(changes: array<mk.Change>, dry: bool)
  for c in changes do
    if c.action == "skip" then
      print("  skip     " + c.path + "  (" + c.note + ")")
    elseif dry then
      print("  would " + c.action + "  " + c.path)
      print(c.content)
    else
      print("  " + c.action + "   " + c.path)
    end
  end
end

--" `kit make ...`: gives the exit code. --"
fun make_command(args: array<string>) -> int
  let files = mk.disk_files()
  if has(args, "--list") then
    print(mk.kinds().join("\n"))
    return 0
  end
  if has(args, "--publish-stubs") then
    let done = mk.publish_stubs(files)
    if done.is_err() then
      print("make: " + done.unwrap_err().message)
      return 1
    end
    for path in done.unwrap() do
      print("  create   " + path)
    end
    return 0
  end
  let words = args.slice(1, args.len()).filter(fun(a: string) -> bool not a.starts_with("--") end)
  let answers: map<string, string> = {}
  if words.len() > 0 then
    answers["kind"] = words[0]
  end
  if words.len() > 1 then
    answers["name"] = words[1]
  end
  let ask = if has(args, "--no-interaction") then sess.Session.silent(answers) else sess.Session.create(answers) end
  let kind = ask.suggest("kind", "What do you want to make?", mk.kinds(), true, "")
  if kind.is_err() then
    print("make: " + kind.unwrap_err().message)
    return if kind.unwrap_err().message == "cancelled" then 130 else 64 end
  end
  let name = ask.text("name", "Name of the " + kind.unwrap(), "", [rules.required()])
  if name.is_err() then
    print("make: " + name.unwrap_err().message)
    return if name.unwrap_err().message == "cancelled" then 130 else 64 end
  end
  let options = mk.Options { dry_run: has(args, "--dry-run"), force: has(args, "--force"), register: not has(args, "--no-register"), with_test: not has(args, "--no-test"), now: time.now() }
  let planned = mk.plan(kind.unwrap(), name.unwrap(), files, options)
  if planned.is_err() and planned.unwrap_err().message.contains("--force") and ask.interactive then
    let again = ask.confirm("force", planned.unwrap_err().message.split(" (")[0] + ". Replace it?", false)
    if again.is_ok() and again.unwrap() then
      options.force = true
      planned = mk.plan(kind.unwrap(), name.unwrap(), files, options)
    end
  end
  if planned.is_err() then
    print("make: " + planned.unwrap_err().message)
    return 1
  end
  show(planned.unwrap(), options.dry_run)
  if options.dry_run then
    return 0
  end
  let done = mk.apply(planned.unwrap(), files)
  if done.is_err() then
    print("make: " + done.unwrap_err().message)
    return 1
  end
  0
end

--" Runs a command; gives the exit code. --"
fun run_command(args: array<string>) -> int
  if args.is_empty() or args[0] == "help" or args[0] == "--help" then
    print(usage())
    return 0
  end
  if args[0] == "make" then
    return make_command(args)
  end
  if args[0] == "wizard" then
    let ran = wiz.run()
    if ran.is_err() then
      print("wizard: " + ran.unwrap_err().message)
      return 1
    end
    return 0
  end
  if args[0] == "dashboard" then
    let ran = dash.run(option(args, "--url", "http://localhost:8000"), option(args, "--log", ""))
    if ran.is_err() then
      print("dashboard: " + ran.unwrap_err().message)
      return 1
    end
    return 0
  end
  print("unknown command `" + args[0] + "`\n\n" + usage())
  64
end

let code = run_command(env.args())
if code != 0 then
  exit(code)
end
