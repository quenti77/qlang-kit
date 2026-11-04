# qlang-kit

The command line tool of the [qlang](https://github.com/quenti77/qlang) web framework, written in qlang:

- **`make`**: generators for controllers, models, migrations, providers, tests... (a controller or a provider is registered in `app.q`, a migration in `migrations.q`) from stubs you can override;
- **project commands**: the ones of `qlang-std` (`db:migrate`, `db:seed`...) behind one entry point;
- **a full terminal interface (TUI)**: panels, forms, tables, logs, a live view of routes, queries and the
  queue, built on the terminal primitives of the language.

## Install

```
curl -fsSL https://raw.githubusercontent.com/quenti77/qlang-kit/main/install.sh | sh
```

kit is written in qlang: it needs the [`qlang`](https://github.com/quenti77/qlang) command. The installer checks the
release's checksum, keeps each version in `~/.local/share/kit/versions` and puts a `kit` launcher in `~/.local/bin`.

```
kit version               kit versions              kit update
kit install 0.1.0         kit use 0.1.0             # pins this folder (writes .kit-version)
```

**In a project**, so that everybody who works on it runs the same kit: `kit init` adds kit to the dependencies of
`qlang.toml` (the version is pinned there and in `qlang.lock`) and writes `kit.q`:

```
kit init && qlang install
qlang run --allow-process kit.q -- make controller Post
```

## Commands, options and exit codes

These are the promise of the stable part (see Stability). `kit help` prints the same list.

| Command | Options | What it does |
| --- | --- | --- |
| `kit make [<kind> <Name>]` | `--dry-run` (list the files, write nothing), `--force` (replace files that exist), `--no-register` (do not add the new controller, provider or migration to `app.q` / `migrations.q`), `--no-test` (no test file), `--no-interaction` (never ask: use what was given, the defaults, or say which answer is missing) | writes a controller, model, migration, provider, job, middleware, policy, resource, factory, seeder, command or test from the stubs |
| `kit make --list` | | prints the kinds |
| `kit make --publish-stubs` | | copies the stubs to `stubs/` to change them (the ones that exist are kept) |
| `kit wizard` | | `make` as a full screen, with a preview of the files |
| `kit init` | `--force` | makes the project depend on kit: pins the version in `qlang.toml` and writes `kit.q` |
| `kit version` | | the version of kit |
| `kit config` | | the settings in use (`kit.json` of the project, then `~/.config/kit/kit.json`) |
| `kit test` | `--filter NAME` is passed to `qlang test` by the runner (`Enter` on a test) | the test runner: watches the `.q` files and runs the tests again when one changes |
| `kit db` | `--url URL` (or `DATABASE_URL`), `--write` | browses a database; read only unless `--write` |
| `kit dashboard` | `--url URL` (default `http://localhost:8000`), `--log FILE` | live view of a running app |
| `kit help`, `kit --help` | | this list |

**Exit codes**: `0` the command did what was asked; `1` it could not (a file that exists without `--force`, an unknown kind, a name that
is refused, a missing answer with `--no-interaction`, a database that does not open); `78` the settings file (`kit.json`) cannot be read.
The text each command prints on success is not promised, the codes are.

**Windows.** `install.sh` is a POSIX shell script: on Windows, install `qlang` first (`install.ps1` of qlang), then run kit from a
clone with `qlang run main.q -- <command>` (or from a project that has `kit` as a dependency: `kit init`). A Windows installer for
kit itself, tried on a real machine, is still to do.

## Stability

Each file has a level in `[stability]` of `qlang.toml` (see `docs/stability.md` of qlang). **Stable** (what 1.0 promises: no
breaking change without a deprecation cycle): the entry point and its sub-commands (`main.q`, `cli.q`, `version.q`), and `make`
with its generators and stubs (`make/`). **Provisional**: the settings (`kit.json`), the prompts, the test runner, the wizard.
**Experimental**: the terminal screens built on `Term` (`tui/`), the dashboard and the database browser. The commands, their
options and their exit codes are the promise; the look of a screen is not.

## Try it

```
qlang run main.q -- dashboard --url http://localhost:8000 --log app.log
qlang run examples/demo.q
```

`make` writes code from stubs (`qlang run main.q -- make --list` for the kinds):

```
qlang run ../qlang-kit/main.q -- make controller BlogPost      # controllers/blog_posts.q + its test, registered in app.q
qlang run ../qlang-kit/main.q -- make migration create_posts_table --dry-run   # + listed in migrations.q
qlang run ../qlang-kit/main.q -- make provider Mailer           # providers/mailer.q, registered in app.q
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

**Settings.** `kit.json` in the project and `~/.config/kit/kit.json` for you (the project wins, key by key): the theme
(`dark`, `light`, `high-contrast`, `mono`, or one of your own built on them with your colours), the key that quits, and the
defaults of `db` and `dashboard`. See `kit.example.json`. A mistake is reported where it is (`themes.sunset.accent: ...`)
and an unknown setting is a mistake too. `kit config` shows what is in use.

`dashboard` shows a running app: health, routes (from `/openapi.json`), requests per route with p50/p95 (from
`/metrics`) and its JSON log (`qlang serve --log-format json`), with the `N+1?` warnings of `--dev`.

Status: the TUI engine (`tui/`) and the dashboard (`dash/`) are in; `make` and the prompts come next. See the roadmap in the issues.
