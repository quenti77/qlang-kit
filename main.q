--" # qlang-kit

The command line tool of the qlang framework.

```
qlang run main.q -- dashboard --url http://localhost:8000 --log app.log
```

| Command | What it does |
| --- | --- |
| `make` | code generators: `make controller Post`, `make migration create_posts_table`... |
| `dashboard` | a live terminal view of a running app (routes, requests, logs) |
| `help` | this list |
--"
import "dash/app.q" as dash
import "make/make.q" as mk

fun usage() -> string
  "qlang-kit 0.1.0\n\nusage: kit <command> [options]\n\ncommands:\n  make <kind> <Name> [--dry-run] [--force] [--no-register] [--no-test]   write a controller, model, migration...\n  make --list | --publish-stubs        the kinds | copy the stubs to stubs/ to change them\n  dashboard [--url URL] [--log FILE]   live view of a running app (default URL http://localhost:8000)\n  help                                 this list\n"
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
  if words.len() != 2 then
    print("usage: kit make <kind> <Name>   (kit make --list for the kinds)")
    return 64
  end
  let options = mk.Options { dry_run: has(args, "--dry-run"), force: has(args, "--force"), register: not has(args, "--no-register"), with_test: not has(args, "--no-test"), now: time.now() }
  let planned = mk.plan(words[0], words[1], files, options)
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
