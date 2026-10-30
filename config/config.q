--" # Configuration

`kit.json` in the project, and `~/.config/kit/kit.json` for you; the project's settings win over yours, key by key.

```
{
  "theme": "sunset",
  "themes": {
    "sunset": { "base": "dark", "accent": "#ff8800", "error": "bright-red", "selection": "#334455", "selection_text": "white" }
  },
  "keys": { "quit": "ctrl+q" },
  "db": { "url": "sqlite://app.db", "write": false },
  "dashboard": { "url": "http://localhost:8000", "log": "storage/app.log" }
}
```

A colour is `#rrggbb`, a name (`black red green yellow blue magenta cyan white`, `bright-` before it for the light version,
`default` for the terminal's own) or `palette:N` (the 256 colours). A mistake is reported with where it is
(`themes.sunset.accent: ...`), never ignored. Unknown settings are mistakes too, so that a typo does not go unnoticed.
--"
import "../tui/keys.q" as k
import "../tui/style.q" as st
import "../tui/theme.q" as th

--" What the file says (with the defaults for what it does not say). --"
struct Config
  public theme: string
  public themes: map<string, th.Theme>
  public quit_key: string
  public db_url: string
  public db_write: bool
  public dash_url: string
  public dash_log: string
end

--" The settings when there is no file. --"
fun defaults() -> Config
  Config { theme: "dark", themes: {}, quit_key: "q", db_url: "", db_write: false, dash_url: "http://localhost:8000", dash_log: "" }
end

fun failure<T>(message: string) -> Result<T, Error>
  Result<T, Error>.Err(Error { message: message })
end

fun name_colour(name: string) -> int?
  let names = ["black", "red", "green", "yellow", "blue", "magenta", "cyan", "white"]
  if name == "default" then
    return 0
  end
  let bright = name.starts_with("bright-")
  let base = if bright then name.substring(7, name.len()) else name end
  let at = names.index_of(base)
  if at == none then
    return none
  end
  st.Color.ansi(at + (if bright then 8 else 0 end))
end

--" A colour from its text. --"
fun colour(text: string) -> Result<int, Error>
  let t = text.trim().lower()
  if t.starts_with("#") then
    let c = st.Color.hex(t)
    if c == 0 then
      return failure<int>("`{text}` is not a colour (#rrggbb)")
    end
    return Result<int, Error>.Ok(c)
  end
  if t.starts_with("palette:") then
    let n = int.parse(t.substring(8, t.len()))
    if n == none or n < 0 or n > 255 then
      return failure<int>("`{text}` is not a colour (palette:0 to palette:255)")
    end
    return Result<int, Error>.Ok(st.Color.indexed(n))
  end
  let named = name_colour(t)
  if named == none then
    return failure<int>("`{text}` is not a colour (#rrggbb, a name, or palette:N)")
  end
  Result<int, Error>.Ok(named)
end

fun at(j: Json, key: string) -> Json
  j.get(key) ?? Json.null()
end

--" `over` on top of `base`: objects are merged key by key, anything else is replaced. --"
fun merge(base: Json, over: Json) -> Json
  if not base.is_object() or not over.is_object() then
    return over
  end
  let out: map<string, Json> = {}
  let a = base.as_object()
  let b = over.as_object()
  for key in a.keys() do
    out[key] = a[key] ?? Json.null()
  end
  for key in b.keys() do
    let had = out[key]
    out[key] = if had == none then b[key] ?? Json.null() else merge(had, b[key] ?? Json.null()) end
  end
  Json.object(out)
end

fun check_keys(where_: string, j: Json, allowed: array<string>) -> Result<bool, Error>
  if not j.is_object() then
    return failure<bool>("{where_} must be an object")
  end
  for key in j.as_object().keys() do
    if not allowed.contains(key) then
      return failure<bool>("unknown setting `" + (if where_ == "" then "" else where_ + "." end) + key + "`")
    end
  end
  Result<bool, Error>.Ok(true)
end

fun text_of(j: Json, path: string, fallback: string) -> Result<string, Error>
  if j.is_null() then
    return Result<string, Error>.Ok(fallback)
  end
  if not j.is_string() then
    return failure<string>("{path} must be a text")
  end
  Result<string, Error>.Ok(j.as_string())
end

fun theme_from(name: string, j: Json) -> Result<th.Theme, Error>
  let allowed = ["base", "accent", "ok", "warn", "error", "selection", "selection_text"]
  let checked = check_keys("themes." + name, j, allowed)
  if checked.is_err() then
    return Result<th.Theme, Error>.Err(checked.unwrap_err())
  end
  let base_name = text_of(at(j, "base"), "themes.{name}.base", "dark")
  if base_name.is_err() then
    return Result<th.Theme, Error>.Err(base_name.unwrap_err())
  end
  let base = th.find(base_name.unwrap())
  if base == none then
    return failure<th.Theme>("themes.{name}.base: `{base_name.unwrap()}` is not a built-in theme (" + th.builtin_names().join(", ") + ")")
  end
  let theme = base.copy()
  theme.name = name
  for key in ["accent", "ok", "warn", "error", "selection", "selection_text"] do
    let given = at(j, key)
    if given.is_null() then
      continue
    end
    if not given.is_string() then
      return failure<th.Theme>("themes.{name}.{key} must be a colour")
    end
    let c = colour(given.as_string())
    if c.is_err() then
      return failure<th.Theme>("themes.{name}.{key}: " + c.unwrap_err().message)
    end
    if key == "accent" then
      theme.accent = c.unwrap()
    elseif key == "ok" then
      theme.ok = c.unwrap()
    elseif key == "warn" then
      theme.warn = c.unwrap()
    elseif key == "error" then
      theme.error = c.unwrap()
    elseif key == "selection" then
      theme.select_bg = c.unwrap()
      theme.colour = true
    else
      theme.select_fg = c.unwrap()
    end
  end
  Result<th.Theme, Error>.Ok(theme)
end

--" Reads the text of a settings file (or of several, merged: see `load`). --"
fun from_json(j: Json) -> Result<Config, Error>
  let c = defaults()
  let top = check_keys("", j, ["theme", "themes", "keys", "db", "dashboard"])
  if top.is_err() then
    return Result<Config, Error>.Err(top.unwrap_err())
  end
  let theme = text_of(at(j, "theme"), "theme", "dark")
  if theme.is_err() then
    return Result<Config, Error>.Err(theme.unwrap_err())
  end
  c.theme = theme.unwrap()
  let themes = at(j, "themes")
  if not themes.is_null() then
    let listed = check_keys("themes", themes, themes.as_object().keys())
    if listed.is_err() then
      return Result<Config, Error>.Err(listed.unwrap_err())
    end
    for name in themes.as_object().keys() do
      let built = theme_from(name, at(themes, name))
      if built.is_err() then
        return Result<Config, Error>.Err(built.unwrap_err())
      end
      c.themes[name] = built.unwrap()
    end
  end
  if th.find(c.theme) == none and c.themes[c.theme] == none then
    return failure<Config>("theme: `{c.theme}` is not a theme (built in: " + th.builtin_names().join(", ") + "; yours: " + c.themes.keys().join(", ") + ")")
  end
  let keys = at(j, "keys")
  if not keys.is_null() then
    let checked = check_keys("keys", keys, ["quit"])
    if checked.is_err() then
      return Result<Config, Error>.Err(checked.unwrap_err())
    end
    let quit = text_of(at(keys, "quit"), "keys.quit", "q")
    if quit.is_err() then
      return Result<Config, Error>.Err(quit.unwrap_err())
    end
    c.quit_key = quit.unwrap()
  end
  let db = at(j, "db")
  if not db.is_null() then
    let checked = check_keys("db", db, ["url", "write"])
    if checked.is_err() then
      return Result<Config, Error>.Err(checked.unwrap_err())
    end
    let url = text_of(at(db, "url"), "db.url", "")
    if url.is_err() then
      return Result<Config, Error>.Err(url.unwrap_err())
    end
    c.db_url = url.unwrap()
    c.db_write = at(db, "write").to_text() == "true"
  end
  let dash = at(j, "dashboard")
  if not dash.is_null() then
    let checked = check_keys("dashboard", dash, ["url", "log"])
    if checked.is_err() then
      return Result<Config, Error>.Err(checked.unwrap_err())
    end
    let url = text_of(at(dash, "url"), "dashboard.url", "http://localhost:8000")
    if url.is_err() then
      return Result<Config, Error>.Err(url.unwrap_err())
    end
    let log = text_of(at(dash, "log"), "dashboard.log", "")
    if log.is_err() then
      return Result<Config, Error>.Err(log.unwrap_err())
    end
    c.dash_url = url.unwrap()
    c.dash_log = log.unwrap()
  end
  Result<Config, Error>.Ok(c)
end

--" Reads the files (yours, then the project's on top of them) with `read`, which gives `none` for a file that is not
there. A file that is not valid JSON is an error that names it. --"
fun load(read: fun(string) -> string?, user_file: string, project_file: string) -> Result<Config, Error>
  let merged = Json.object({})
  for path in [user_file, project_file] do
    if path == "" then
      continue
    end
    let text = read(path)
    if text == none then
      continue
    end
    let parsed = Json.parse(text)
    if parsed.is_err() then
      return failure<Config>("{path}: " + parsed.unwrap_err().message)
    end
    merged = merge(merged, parsed.unwrap())
  end
  from_json(merged)
end

--" The theme the file chose. --"
fun chosen_theme(c: Config) -> th.Theme
  let own = c.themes[c.theme]
  if own != none then
    return own
  end
  th.find(c.theme) ?? th.Theme.dark()
end

--" Puts the settings to work: the theme and the quit key of every screen. --"
fun apply(c: Config)
  th.use_theme(chosen_theme(c))
  k.set_quit(c.quit_key)
end

export Config, defaults, colour, merge, from_json, load, chosen_theme, apply
