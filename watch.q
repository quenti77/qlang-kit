--" # kit test

The test runner screen (see `runner/app.q`). It starts `qlang`, so it needs the permission to start programs:

```
qlang run --allow-process watch.q
```
(`bin/kit test` does that.)
--"
import "runner/app.q" as runner

let ran = runner.run()
if ran.is_err() then
  print("test: " + ran.unwrap_err().message)
  exit(1)
end
