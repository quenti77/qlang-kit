# Changelog

## 1.1.0

The terminal screens get cheaper and more flexible (needs qlang 1.8 for the step limit that counts between two events). Nothing breaks.

- **`tui/`: a redraw costs much less.** `Buffer.diff` gives `""` at once for a screen that did not change and skips the rows that did not, `put` has a short path for printable ASCII and `char_width` answers it without looking at bytes. A `"timeout"` event with no timer due no longer draws again. For a screen of 120 by 40 that did not change, the work of a redraw falls to about a third; `Buffer.diff` of two equal screens is about 60 times faster.
- **`run_in_terminal(program, mouse: false)`** (and `run_in_terminal_with`) does not report the mouse: the terminal keeps selecting text itself and a movement of the pointer no longer redraws. `true` stays the default.
- **`Table.colorize(style)`** gives a cell a style of its own (`style(row, column)` gives a `Style?`, `none` for the style of the row); on the selected row the text keeps the colour of the cell on the background of the selection. **`Table.marker("▶ ")`** puts a mark in front of the selected row (the other rows get spaces).

## 1.0.0

First stable version. What 1.x promises is the stable part (commands, options, exit codes and the generators); the screens that depend on `Term` stay experimental, the rest is provisional (see Stability in the README).

- **Stability levels.** The entry point and its sub-commands, and `make` with its generators and stubs, are **stable**; the
  settings, the prompts, the test runner and the wizard are **provisional**; the terminal screens (`tui/`), the dashboard and
  the database browser stay **experimental** (they depend on `Term`, which is experimental in qlang). All 239 tests pass with
  qlang 1.1 (`qlang test --allow-process`).
- **Documented.** `README.md` lists every command, option and exit code (`0`, `1`, `78`), and says what Windows does today.
- **Complete.** Every item of the roadmap (#1) exists: the twelve generators of `make --list`, the widgets, the dashboard, the
  database browser, `kit init`.

## 0.2.0 and before

See the releases of the repository.
