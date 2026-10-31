--" # make: code generators

`kit make controller Post` writes `controllers/posts.q` (and its test), registers it in `app.q`, and says what it
did. A provider is registered in `app.q` the same way, a migration in `migrations.q` (`all()` gives them to the
migrator). Every generator works from a **stub**, a text with `\{\{placeholders\}\}`; a project can change any of them
by putting its own `stubs/<kind>.stub` next to its code (`kit make --publish-stubs` copies the built-in ones
there to start from).

| Kind | File | Notes |
| --- | --- | --- |
| `controller` | `controllers/<names>.q` + `tests/<names>_test.q` | registered in `app.q` |
| `model` | `models/<name>.q` | a struct and the queries that read it |
| `migration` | `migrations/<date>_<name>.q` | `create_users` makes the table; any other name is blank; listed in `migrations.q` |
| `provider` | `providers/<name>.q` | a service and the function that makes it; registered in `app.q` |
| `job` | `jobs/<name>.q` | a struct and its handler |
| `middleware` | `middleware/<name>.q` | |
| `policy` | `policies/<name>.q` | |
| `resource` | `resources/<name>.q` | |
| `factory` | `factories/<name>.q` | |
| `seeder` | `seeders/<name>.q` | |
| `command` | `commands/<name>.q` | a `cli.q` command |
| `test` | `tests/<names>_test.q` | an HTTP test of `/<names>` |

Placeholders: `\{\{Name\}\}` (`BlogPost`), `\{\{name\}\}` (`blog_post`), `\{\{names\}\}` (`blog_posts`), `\{\{kebab\}\}`
(`blog-post`), `\{\{route\}\}` (`blog-posts`), `\{\{table\}\}` (`blog_posts`), `\{\{id\}\}` (a migration's id).
--"
import "builtin.q" as builtin
import "names.q" as nm

--" How the files are read and written: the disk in the tool, a map in the tests. --"
struct Files
  public exists: fun(string) -> bool
  public read: fun(string) -> Result<string, Error>
  public write: fun(string, string) -> Result<bool, Error>
end

--" The files of the disk (folders are created as needed). --"
fun disk_files() -> Files
  let exists = fun(path: string) -> bool
    let found = fs.exists(path)
    found.is_ok() and found.unwrap()
  end
  let read = fun(path: string) -> Result<string, Error>
    fs.read(path)
  end
  let write = fun(path: string, content: string) -> Result<bool, Error>
    let cut = path.last_index_of("/")
    if cut != none then
      let made = fs.create_dir(path.substring(0, cut))
      if made.is_err() then
        return made
      end
    end
    fs.write(path, content)
  end
  Files { exists: exists, read: read, write: write }
end

--" Files kept in a map (for tests). --"
fun memory_files(store: map<string, string>) -> Files
  let exists = fun(path: string) -> bool
    store[path] != none
  end
  let read = fun(path: string) -> Result<string, Error>
    let found = store[path]
    if found == none then
      return Result<string, Error>.Err(Error { message: "{path} not found" })
    end
    Result<string, Error>.Ok(found)
  end
  let write = fun(path: string, content: string) -> Result<bool, Error>
    store[path] = content
    Result<bool, Error>.Ok(true)
  end
  Files { exists: exists, read: read, write: write }
end

--" What the command was asked. --"
struct Options
  public dry_run: bool = false
  --" Replace a file that is already there. --"
  public force: bool = false
  --" Register what is made where the application looks for it: a controller or a provider in `app.q`, a migration in
  `migrations.q`. --"
  public register: bool = true
  --" Also write the test of a controller. --"
  public with_test: bool = true
  --" The time, in milliseconds since 1970 (the id of a migration). --"
  public now: int = 0
end

--" One thing to do to a file: `"create"`, `"update"` (an existing file changed) or `"skip"`. --"
struct Change
  public path: string
  public content: string
  public action: string
  public note: string
end

--" The kinds of file `make` knows. --"
fun kinds() -> array<string>
  ["controller", "model", "migration", "provider", "job", "middleware", "policy", "resource", "factory", "seeder", "command", "test"]
end

fun pad2(n: int) -> string
  if n < 10 then "0{n}" else "{n}" end
end

--" `20261030141500` for a time in milliseconds since 1970 (UTC). --"
fun timestamp(ms: int) -> string
  let days = ms div 86400000
  let secs = (ms % 86400000) div 1000
  let z = days + 719468
  let era = z div 146097
  let doe = z - era * 146097
  let yoe = (doe - doe div 1460 + doe div 36524 - doe div 146096) div 365
  let doy = doe - (365 * yoe + yoe div 4 - yoe div 100)
  let mp = (5 * doy + 2) div 153
  let day = doy - (153 * mp + 2) div 5 + 1
  let month = if mp < 10 then mp + 3 else mp - 9 end
  let year = yoe + era * 400 + (if month <= 2 then 1 else 0 end)
  "{year}" + pad2(month) + pad2(day) + pad2(secs div 3600) + pad2((secs % 3600) div 60) + pad2(secs % 60)
end

--" Replaces the placeholders; an unknown one is an error (a typo in a stub). --"
fun render(stub: string, vars: map<string, string>) -> Result<string, Error>
  let out = stub
  for key in vars.keys() do
    out = out.replace("\{\{" + key + "\}\}", vars[key] ?? "")
  end
  if regex.matches(out, "[\{][\{][A-Za-z_]+[\}][\}]") then
    return Result<string, Error>.Err(Error { message: "a stub has a placeholder that is not known" })
  end
  Result<string, Error>.Ok(out)
end

fun variables(kind: string, name: string, now: int) -> map<string, string>
  let w = nm.words(name)
  let plural = nm.plural(w)
  let table_words = w
  if kind == "migration" then
    let inner = w
    if inner.len() > 1 and inner[0] == "create" then
      inner = inner.slice(1, inner.len())
    end
    if inner.len() > 1 and inner[inner.len() - 1] == "table" then
      inner = inner.slice(0, inner.len() - 1)
    end
    table_words = inner
  end
  let table = nm.snake(nm.plural(table_words))
  let stamp = timestamp(now)
  {"Name": nm.pascal(w), "name": nm.snake(w), "names": nm.snake(plural), "kebab": nm.kebab(w), "route": nm.kebab(plural), "table": table, "id": stamp + "_" + nm.snake(w)}
end

-- the stub of a kind: the project's own if it has one, else the built-in
fun stub_of(kind: string, files: Files) -> Result<string, Error>
  let own = "stubs/" + kind + ".stub"
  if files.exists(own) then
    return files.read(own)
  end
  let found = builtin.builtin_stubs()[kind]
  if found == none then
    return Result<string, Error>.Err(Error { message: "there is no stub for `{kind}`" })
  end
  Result<string, Error>.Ok(found)
end

fun path_of(kind: string, vars: map<string, string>) -> string
  let name = vars["name"] ?? ""
  let names = vars["names"] ?? ""
  if kind == "controller" then
    "controllers/" + names + ".q"
  elseif kind == "migration" then
    "migrations/" + (vars["id"] ?? "") + ".q"
  elseif kind == "test" then
    "tests/" + names + "_test.q"
  elseif kind == "provider" then
    "providers/" + name + ".q"
  elseif kind == "model" then
    "models/" + name + ".q"
  elseif kind == "middleware" then
    "middleware/" + name + ".q"
  elseif kind == "policy" then
    "policies/" + name + ".q"
  elseif kind == "resource" then
    "resources/" + name + ".q"
  elseif kind == "factory" then
    "factories/" + name + ".q"
  elseif kind == "seeder" then
    "seeders/" + name + ".q"
  elseif kind == "command" then
    "commands/" + name + ".q"
  else
    "jobs/" + name + ".q"
  end
end

fun change_for(path: string, content: string, files: Files, options: Options) -> Result<Change, Error>
  if files.exists(path) and not options.force then
    return Result<Change, Error>.Err(Error { message: "{path} already exists (use --force to replace it)" })
  end
  let action = if files.exists(path) then "update" else "create" end
  Result<Change, Error>.Ok(Change { path: path, content: content, action: action, note: "" })
end

--" Adds the controller module to `App.boot(...)` of `app.q`. Gives the new text, or `none` when `app.q` does
not look like the one `qlang init --web` writes (the command then says what to add by hand). --"
fun register_controller(app_source: string, path: string, alias: string) -> string?
  let lines = app_source.split("\n")
  let boot = -1
  let last_import = -1
  for i in 0..lines.len() do
    if lines[i].contains("App.boot(") then
      boot = i
    end
    if lines[i].starts_with("import ") then
      last_import = i
    end
  end
  if boot < 0 or last_import < 0 then
    return none
  end
  let line = lines[boot]
  if not line.trim().ends_with(")") then
    return none
  end
  let module_line = "import \"" + path + "\" as " + alias
  if app_source.contains(module_line) then
    return app_source
  end
  let rebuilt: array<string> = []
  for i in 0..lines.len() do
    if i == boot then
      let trimmed = line.trim_end()
      rebuilt.push(trimmed.substring(0, trimmed.len() - 1) + ".concat(Reflect.declared(" + alias + ")))")
    else
      rebuilt.push(lines[i])
    end
    if i == last_import then
      rebuilt.push(module_line)
    end
  end
  rebuilt.join("\n")
end

-- the text of a new `migrations.q`: the project's own stub or the built-in one
fun index_stub(files: Files) -> string
  let stub = stub_of("migrations_index", files)
  if stub.is_ok() then
    stub.unwrap()
  else
    ""
  end
end

--" Adds a migration module to `migrations.q`: its import, and its `migration()` in the list of `all()`. Gives the new
text, or `none` when the file does not look like the one `kit make migration` writes. --"
fun register_migration(index_source: string, path: string, alias: string) -> string?
  let module_line = "import \"" + path + "\" as " + alias
  if index_source.contains(module_line) then
    return index_source
  end
  let lines = index_source.split("\n")
  let close = -1
  let last_import = -1
  for i in 0..lines.len() do
    if lines[i].trim() == "]" then
      close = i
    end
    if lines[i].starts_with("import ") then
      last_import = i
    end
  end
  if close < 0 or last_import < 0 then
    return none
  end
  let rebuilt: array<string> = []
  for i in 0..lines.len() do
    if i == close then
      rebuilt.push("    " + alias + ".migration(),")
    end
    rebuilt.push(lines[i])
    if i == last_import then
      rebuilt.push(module_line)
    end
  end
  rebuilt.join("\n")
end

--" Works out what `kit make <kind> <name>` would do, without touching any file. --"
fun plan(kind: string, name: string, files: Files, options: Options) -> Result<array<Change>, Error>
  if not kinds().contains(kind) then
    return Result<array<Change>, Error>.Err(Error { message: "unknown kind `{kind}` (one of: " + kinds().join(", ") + ")" })
  end
  if not nm.is_valid(name) then
    return Result<array<Change>, Error>.Err(Error { message: "`{name}` is not a name (letters and digits, starting with a letter)" })
  end
  let vars = variables(kind, name, options.now)
  let stub_kind = if kind == "migration" and not (vars["id"] ?? "").contains("_create_") then "migration_blank" else kind end
  let stub = stub_of(stub_kind, files)
  if stub.is_err() then
    return Result<array<Change>, Error>.Err(stub.unwrap_err())
  end
  let text = render(stub.unwrap(), vars)
  if text.is_err() then
    return Result<array<Change>, Error>.Err(text.unwrap_err())
  end
  let path = path_of(kind, vars)
  let first = change_for(path, text.unwrap(), files, options)
  if first.is_err() then
    return Result<array<Change>, Error>.Err(first.unwrap_err())
  end
  let changes = [first.unwrap()]
  if kind == "controller" and options.with_test then
    let test_stub = stub_of("controller_test", files)
    if test_stub.is_err() then
      return Result<array<Change>, Error>.Err(test_stub.unwrap_err())
    end
    let test_text = render(test_stub.unwrap(), vars)
    if test_text.is_err() then
      return Result<array<Change>, Error>.Err(test_text.unwrap_err())
    end
    let test_change = change_for("tests/" + (vars["names"] ?? "") + "_test.q", test_text.unwrap(), files, options)
    if test_change.is_err() then
      return Result<array<Change>, Error>.Err(test_change.unwrap_err())
    end
    changes.push(test_change.unwrap())
  end
  if (kind == "controller" or kind == "provider") and options.register then
    let app = files.read("app.q")
    let alias = (if kind == "provider" then "providers_" else "controllers_" end) + (if kind == "provider" then (vars["name"] ?? "") else (vars["names"] ?? "") end)
    let updated = if app.is_ok() then register_controller(app.unwrap(), path, alias) else none end
    if updated == none then
      changes.push(Change { path: "app.q", content: "", action: "skip", note: "add `import \"" + path + "\" as " + alias + "` and `.concat(Reflect.declared(" + alias + "))` to App.boot yourself" })
    elseif app.unwrap() != updated then
      changes.push(Change { path: "app.q", content: updated, action: "update", note: "registered" })
    end
  end
  if kind == "migration" and options.register then
    let alias = "m_" + (vars["id"] ?? "")
    let existing = files.read("migrations.q")
    let source = if existing.is_ok() then existing.unwrap() else index_stub(files) end
    let updated = register_migration(source, path, alias)
    if updated == none then
      changes.push(Change { path: "migrations.q", content: "", action: "skip", note: "add `import \"" + path + "\" as " + alias + "` and `" + alias + ".migration()` to the list of all() yourself" })
    elseif existing.is_err() then
      changes.push(Change { path: "migrations.q", content: updated, action: "create", note: "the list of the migrations" })
    elseif existing.unwrap() != updated then
      changes.push(Change { path: "migrations.q", content: updated, action: "update", note: "registered" })
    end
  end
  Result<array<Change>, Error>.Ok(changes)
end

--" Writes the changes (the ones that are not `"skip"`). --"
fun apply(changes: array<Change>, files: Files) -> Result<bool, Error>
  for c in changes do
    if c.action == "skip" then
      continue
    end
    let written = files.write(c.path, c.content)
    if written.is_err() then
      return written
    end
  end
  Result<bool, Error>.Ok(true)
end

--" The built-in stubs copied to `stubs/` of the project, to start from (existing ones are kept). --"
fun publish_stubs(files: Files) -> Result<array<string>, Error>
  let done: array<string> = []
  let all = builtin.builtin_stubs()
  for key in all.keys() do
    let path = "stubs/" + key + ".stub"
    if files.exists(path) then
      continue
    end
    let written = files.write(path, all[key] ?? "")
    if written.is_err() then
      return Result<array<string>, Error>.Err(written.unwrap_err())
    end
    done.push(path)
  end
  Result<array<string>, Error>.Ok(done)
end

export Files, Options, Change, disk_files, memory_files, kinds, timestamp, plan, apply, publish_stubs, register_controller, register_migration
