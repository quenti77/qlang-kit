--" # Themes

The colours the widgets use, by **role** rather than by name: the accent (a focused frame), good, warning and
error, and the selected line. A program reads them with `accent()`, `ok()`, `warn()`, `error()` and `selected()`;
`use_theme` changes them for the whole program, so a theme set once at the start is the look of every widget.

```
use_theme(find("high-contrast"))
screen.put(0, 0, "saved", ok())
```

Built in: `dark` (the default), `light`, `high-contrast` and `mono` (no colour at all: bold and underline). A theme
of your own starts from one of them (`kit.json`, see `config.q`).
--"
import "style.q" as st

--" The colours of a theme. A colour is an `int` as in `style.q` (`0` is the terminal's own). --"
struct Theme
  public name: string
  public accent: int
  public ok: int
  public warn: int
  public error: int
  --" The colours of the selected line; with `0` for the background it is shown reversed. --"
  public select_fg: int
  public select_bg: int
  --" Colours are used at all (false: only bold and underline). --"
  public colour: bool
end

impl Theme
  public fun dark() -> Theme
    Theme { name: "dark", accent: st.Color.ansi(6), ok: st.Color.ansi(2), warn: st.Color.ansi(3), error: st.Color.ansi(1), select_fg: 0, select_bg: 0, colour: true }
  end

  public fun light() -> Theme
    Theme { name: "light", accent: st.Color.ansi(4), ok: st.Color.ansi(2), warn: st.Color.indexed(130), error: st.Color.ansi(1), select_fg: 0, select_bg: 0, colour: true }
  end

  public fun high_contrast() -> Theme
    Theme { name: "high-contrast", accent: st.Color.ansi(14), ok: st.Color.ansi(10), warn: st.Color.ansi(11), error: st.Color.ansi(9), select_fg: st.Color.ansi(0), select_bg: st.Color.ansi(15), colour: true }
  end

  public fun mono() -> Theme
    Theme { name: "mono", accent: 0, ok: 0, warn: 0, error: 0, select_fg: 0, select_bg: 0, colour: false }
  end

  --" A copy, to change a few colours of it. --"
  public fun copy(self) -> Theme
    Theme { name: self.name, accent: self.accent, ok: self.ok, warn: self.warn, error: self.error, select_fg: self.select_fg, select_bg: self.select_bg, colour: self.colour }
  end
end

--" The names of the built-in themes. --"
fun builtin_names() -> array<string>
  ["dark", "light", "high-contrast", "mono"]
end

--" A built-in theme by name, or `none`. --"
fun find(name: string) -> Theme?
  if name == "dark" then
    Theme.dark()
  elseif name == "light" then
    Theme.light()
  elseif name == "high-contrast" then
    Theme.high_contrast()
  elseif name == "mono" then
    Theme.mono()
  else
    none
  end
end

-- the theme in use: one value for the whole program, changed in place
let active = Theme.dark()

--" Makes `theme` the look of every widget from now on. --"
fun use_theme(theme: Theme)
  active.name = theme.name
  active.accent = theme.accent
  active.ok = theme.ok
  active.warn = theme.warn
  active.error = theme.error
  active.select_fg = theme.select_fg
  active.select_bg = theme.select_bg
  active.colour = theme.colour
end

--" The name of the theme in use. --"
fun current_name() -> string
  active.name
end

fun coloured(color: int) -> st.Style
  if active.colour then st.Style.create().fg(color) else st.Style.create() end
end

--" A focused frame, a title that matters. --"
fun accent() -> st.Style
  coloured(active.accent).bold()
end

--" Something that went well. --"
fun ok() -> st.Style
  coloured(active.ok)
end

--" Something to look at. --"
fun warn() -> st.Style
  if active.colour then coloured(active.warn) else st.Style.create().bold() end
end

--" Something wrong. --"
fun error() -> st.Style
  if active.colour then coloured(active.error) else st.Style.create().bold().underline() end
end

--" The selected line of a list that has the focus. --"
fun selected() -> st.Style
  if active.colour and active.select_bg != 0 then
    return st.Style.create().fg(active.select_fg).bg(active.select_bg)
  end
  st.Style.create().reverse()
end

--" Something less important. --"
fun muted() -> st.Style
  st.Style.create().dim()
end

export Theme, builtin_names, find, use_theme, current_name, accent, ok, warn, error, selected, muted
