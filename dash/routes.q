--" # Reading the routes

The routes of an app, read from its OpenAPI document (`openapi_route(app, "/openapi.json", ...)` of
`qlang-std`): the method, the path and the summary of each operation.

```
let routes = parse(text)                  -- array<Route>, sorted by path then method
```
--"

--" One operation. --"
struct Route
  public method: string
  public path: string
  public summary: string
end

--" Reads the document; the error says why it is not one. --"
fun parse(text: string) -> Result<array<Route>, Error>
  let parsed = Json.parse(text)
  if parsed.is_err() then
    return Result<array<Route>, Error>.Err(parsed.unwrap_err())
  end
  let paths = parsed.unwrap().get("paths")
  if paths == none then
    return Result<array<Route>, Error>.Err(Error { message: "no paths in the document" })
  end
  let out: array<Route> = []
  let table = paths.as_object()
  for path in table.keys() do
    let ops = (table[path] ?? Json.null()).as_object()
    for method in ops.keys() do
      let summary = ((ops[method] ?? Json.null()).get("summary") ?? Json.string("")).as_string()
      out.push(Route { method: method.upper(), path: path, summary: summary })
    end
  end
  out.sort_by(fun(a: Route, b: Route) -> int
    if a.path < b.path then
      -1
    elseif a.path > b.path then
      1
    elseif a.method < b.method then
      -1
    elseif a.method > b.method then
      1
    else
      0
    end
  end)
  Result<array<Route>, Error>.Ok(out)
end

export Route, parse
