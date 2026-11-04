# Changelog

## Unreleased

- **Stability levels.** The entry point and its sub-commands, and `make` with its generators and stubs, are **stable**; the
  settings, the prompts, the test runner and the wizard are **provisional**; the terminal screens (`tui/`), the dashboard and
  the database browser stay **experimental** (they depend on `Term`, which is experimental in qlang). All 239 tests pass with
  qlang 1.1 (`qlang test --allow-process`).
- **Documented.** `README.md` lists every command, option and exit code (`0`, `1`, `78`), and says what Windows does today.
- **Complete.** Every item of the roadmap (#1) exists: the twelve generators of `make --list`, the widgets, the dashboard, the
  database browser, `kit init`.

## 0.2.0 and before

See the releases of the repository.
