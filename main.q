--" # qlang-kit

The command line tool of the qlang framework (see `cli.q` for the commands).

```
qlang run main.q -- make controller Post
bin/kit test                       -- the test runner starts qlang: it needs --allow-process
```
--"
import "cli.q" as cli

fun needs_permission() -> int
  print("kit test starts qlang, which needs a permission: use `bin/kit test`, or\n  qlang run --allow-process watch.q")
  64
end

let code = cli.run_command(env.args(), needs_permission)
if code != 0 then
  exit(code)
end
