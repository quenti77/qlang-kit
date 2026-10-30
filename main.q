--" # qlang-kit

The command line tool of the qlang framework.

```
qlang run main.q -- dashboard --url http://localhost:8000 --log app.log
```

| Command | What it does |
| --- | --- |
| `dashboard` | a live terminal view of a running app (routes, requests, logs) |
| `help` | this list |
--"
import "dash/app.q" as dash

fun usage() -> string
  "qlang-kit 0.1.0\n\nusage: kit <command> [options]\n\ncommands:\n  dashboard [--url URL] [--log FILE]   live view of a running app (default URL http://localhost:8000)\n  help                                 this list\n"
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

--" Runs a command; gives the exit code. --"
fun run_command(args: array<string>) -> int
  if args.is_empty() or args[0] == "help" or args[0] == "--help" then
    print(usage())
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
