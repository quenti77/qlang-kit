--" # Reading logs

`qlang serve --log-format json` writes one JSON object per line (`time`, `level`, `message` and the fields).
This module reads those lines (and plain text lines too: `ERROR something broke`), filters them and finds the
SQL warnings (`N+1?`) of `--dev`.

```
let entries = parse_all(text)
let shown = filter(entries, "warn", "users")        -- at least `warn`, containing "users"
```
--"

--" One line of the log. --"
struct Entry
  public time: string
  --" `"debug"`, `"info"`, `"warn"` or `"error"`. --"
  public level: string
  public message: string
  --" The raw line, for the detail view. --"
  public raw: string
end

--" A number to compare levels: debug 0, info 1, warn 2, error 3. --"
fun level_rank(level: string) -> int
  let l = level.lower()
  if l == "debug" or l == "trace" then
    0
  elseif l == "info" then
    1
  elseif l == "warn" or l == "warning" then
    2
  elseif l == "error" or l == "fatal" then
    3
  else
    1
  end
end

fun normal_level(level: string) -> string
  let l = level.lower()
  if l == "warning" then
    "warn"
  elseif l == "trace" then
    "debug"
  elseif l == "fatal" then
    "error"
  else
    l
  end
end

--" Reads one line: JSON, else `LEVEL message`, else just a message at the `info` level. --"
fun parse_line(line: string) -> Entry
  let text = line.trim()
  if text.starts_with("\{") then
    let parsed = Json.parse(text)
    if parsed.is_ok() then
      let j = parsed.unwrap()
      let level = (j.get("level") ?? Json.string("info")).as_string()
      let message = (j.get("message") ?? j.get("msg") ?? Json.string("")).as_string()
      let time = (j.get("time") ?? Json.string("")).as_string()
      return Entry { time: time, level: normal_level(level), message: message, raw: text }
    end
  end
  let space = text.index_of(" ")
  if space != none then
    let head = text.substring(0, space)
    if level_rank(head) != 1 or head.lower() == "info" then
      if head.upper() == head and head.len() <= 7 then
        return Entry { time: "", level: normal_level(head), message: text.substring(space + 1, text.len()), raw: text }
      end
    end
  end
  Entry { time: "", level: "info", message: text, raw: text }
end

--" Reads every non-empty line. --"
fun parse_all(text: string) -> array<Entry>
  let out: array<Entry> = []
  for line in text.split("\n") do
    if line.trim() != "" then
      out.push(parse_line(line))
    end
  end
  out
end

--" The entries at least at `level` (`""` for all) that contain `needle` (`""` for all, any case). --"
fun filter(entries: array<Entry>, level: string, needle: string) -> array<Entry>
  let floor = if level == "" then 0 else level_rank(level) end
  let low = needle.lower()
  entries.filter(fun(e: Entry) -> bool
    level_rank(e.level) >= floor and (low == "" or e.raw.lower().contains(low))
  end)
end

--" Whether the entry is the `N+1?` warning of `--dev`. --"
fun is_n_plus_one(e: Entry) -> bool
  e.message.contains("N+1?")
end

export Entry, parse_line, parse_all, filter, level_rank, is_n_plus_one
