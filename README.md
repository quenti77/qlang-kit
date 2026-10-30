# qlang-kit

The command line tool of the [qlang](https://github.com/quenti77/qlang) web framework, written in qlang:

- **`make`**: generators for controllers, models, migrations, tests, providers... from stubs you can override;
- **project commands**: the ones of `qlang-std` (`db:migrate`, `db:seed`...) behind one entry point;
- **a full terminal interface (TUI)**: panels, forms, tables, logs, a live view of routes, queries and the
  queue, built on the terminal primitives of the language.

## Try it

```
qlang run main.q -- dashboard --url http://localhost:8000 --log app.log
qlang run examples/demo.q
```

`dashboard` shows a running app: health, routes (from `/openapi.json`), requests per route with p50/p95 (from
`/metrics`) and its JSON log (`qlang serve --log-format json`), with the `N+1?` warnings of `--dev`.

Status: the TUI engine (`tui/`) and the dashboard (`dash/`) are in; `make` and the prompts come next. See the roadmap in the issues.
