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

`make` writes code from stubs (`qlang run main.q -- make --list` for the kinds):

```
qlang run ../qlang-kit/main.q -- make controller BlogPost      # controllers/blog_posts.q + its test, registered in app.q
qlang run ../qlang-kit/main.q -- make migration create_posts_table --dry-run
qlang run ../qlang-kit/main.q -- make --publish-stubs          # copy the stubs to stubs/ to change them
```

Without arguments `kit make` asks what to make and how to call it (`--no-interaction` never asks: it uses what
was given, the defaults, or says which answer is missing). The questions are in `prompt/`: text, password,
confirm, select, multi-select and autocomplete, with rules (`required`, `min_length`, `matches`...); a command
asks them through a `Session`, which also takes answers from the command line and works without a terminal.

`bin/kit test` is a test runner that **watches** your `.q` files and runs `qlang test` again when one changes: every test
with its verdict, and for a failure the message and the source around the line (`r` run all, `Enter` run the selected
test, `w` watching, `f` only failures). It starts `qlang`, so it runs with `--allow-process` (the `bin/kit` script
does that, and only for `test`). `bin/kit` dispatches the other commands too.

`kit db --url sqlite://app.db` (or `DATABASE_URL`; also `postgres://` and `mysql://`) browses a database: the tables, the rows
of a table a page at a time (`n`/`p`, `←` `→` scroll the columns), its structure, a SQL editor (`Ctrl+R` runs) and the migrations
(applied, or pending when a file of `migrations/` is not in `schema_migrations`). It only reads unless started with `--write`.

`dashboard` shows a running app: health, routes (from `/openapi.json`), requests per route with p50/p95 (from
`/metrics`) and its JSON log (`qlang serve --log-format json`), with the `N+1?` warnings of `--dev`.

Status: the TUI engine (`tui/`) and the dashboard (`dash/`) are in; `make` and the prompts come next. See the roadmap in the issues.
