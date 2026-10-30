--" # qlang-kit

The command line tool of the qlang framework.

```
qlang run main.q -- dashboard --url http://localhost:8000 --log app.log
```

| Command | What it does |
| --- | --- |
| `make` | code generators: `make controller Post`, `make migration create_posts_table`... |
| `wizard` | `make` as a full screen: pick, name, preview the files, write |
| `config` | the settings in use: theme, keys, defaults (`kit.json`) |
| `test` | the test runner, watching: run it with `bin/kit test` |
| `db` | browse a database (tables, rows, structure, SQL, migrations) |
| `dashboard` | a live terminal view of a running app (routes, requests, logs) |
| `help` | this list |
--"
import "config/config.q" as cfg
import "dash/app.q" as dash
import "make/make.q" as mk
import "prompt/rules.q" as rules
import "tui/theme.q" as th
import "dbx/app.q" as dbx
import "wizard/app.q" as wiz
import "prompt/session.q" as sess

fun usage() -> string
  "qlang-kit 0.1.0\n\nusage: kit <command> [options]\n\ncommands:\n  make [<kind> <Name>] [--dry-run] [--force] [--no-register] [--no-test] [--no-interaction]   write a controller, model, migration...\n  make --list | --publish-stubs        the kinds | copy the stubs to stubs/ to change them\n  wizard                               make as a full screen, with a preview of the files\n  config                               the settings in use (kit.json, ~/.config/kit/kit.json)\n  test                                 the test runner: watches the files, shows failures with their source (bin/kit test)\n  db [--url URL] [--write]             browse a database: tables, rows, structure, SQL, migrations (read only by default)\n  dashboard [--url URL] [--log FILE]   live view of a running app (default URL http://localhost:8000)\n  help                                 this list\n"
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

fun read_text(path: string) -> string?
  let read = fs.read(path)
  if read.is_ok() then read.unwrap() else none end
end

--" Where your own settings are: `$XDG_CONFIG_HOME/kit/kit.json` or `~/.config/kit/kit.json`. --"
fun user_config_path() -> string
  let xdg = env.get("XDG_CONFIG_HOME") ?? ""
  if xdg != "" then
    return xdg + "/kit/kit.json"
  end
  let home = env.get("HOME") ?? ""
  if home == "" then "" else home + "/.config/kit/kit.json" end
end

--" Runs a command; gives the exit code. --"
fun run_command(args: array<string>) -> int
  let loaded = cfg.load(read_text, user_config_path(), "kit.json")
  if loaded.is_err() then
    print("settings: " + loaded.unwrap_err().message)
    return 78
  end
  let settings = loaded.unwrap()
  cfg.apply(settings)
  if args.is_empty() or args[0] == "help" or args[0] == "--help" then
    print(usage())
    return 0
  end
  if args[0] == "make" then
    return make_command(args)
  end
  if args[0] == "test" then
    print("kit test starts qlang, which needs a permission: use `bin/kit test`, or\n  qlang run --allow-process watch.q")
    return 64
  end
  if args[0] == "db" then
    let url = option(args, "--url", if settings.db_url != "" then settings.db_url else env.get("DATABASE_URL") ?? "" end)
    if url == "" then
      print("db: give the database with --url (sqlite://app.db, postgres://...) or DATABASE_URL")
      return 64
    end
    let ran = dbx.run(url, has(args, "--write") or settings.db_write)
    if ran.is_err() then
      print("db: " + ran.unwrap_err().message)
      return 1
    end
    return 0
  end
  if args[0] == "config" then
    print("theme       " + settings.theme)
    print("themes      built in: " + th.builtin_names().join(", ") + (if settings.themes.is_empty() then "" else "; yours: " + settings.themes.keys().join(", ") end))
    print("quit key    " + settings.quit_key)
    print("db          " + (if settings.db_url == "" then "(DATABASE_URL)" else settings.db_url end) + (if settings.db_write then "  (write)" else "" end))
    print("dashboard   " + settings.dash_url + (if settings.dash_log == "" then "" else "  log " + settings.dash_log end))
    print("files       " + user_config_path() + (if read_text(user_config_path()) == none then " (none)" else "" end) + ", kit.json" + (if read_text("kit.json") == none then " (none)" else "" end))
    return 0
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
    let ran = dash.run(option(args, "--url", settings.dash_url), option(args, "--log", settings.dash_log))
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
