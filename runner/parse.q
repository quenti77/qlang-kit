--" # Reading the output of `qlang test`

```
ok   tests/posts_test.q::test_index
FAIL tests/posts_test.q::test_show
     error[R050]: panic: assert_eq failed
       --> tests/posts_test.q:12:3
...
3 passed, 1 failed
```

`parse` turns that text into a `Report`: the cases with their verdict, the lines that explain a failure and the
place it happened (`file:line`).
--"

--" One test. --"
struct Case
  public file: string
  public name: string
  public ok: bool
  --" What `qlang test` printed under a failure. --"
  public detail: array<string>
  --" Where the failure was raised (`""` when unknown) and the line. --"
  public at_file: string
  public at_line: int
end

--" All the tests of a run. --"
struct Report
  public cases: array<Case>
  public passed: int
  public failed: int
  --" Lines that belong to no test (a file that does not compile, for instance). --"
  public other: array<string>
end

fun split_case(rest: string) -> array<string>
  let cut = rest.index_of("::")
  if cut == none then
    return [rest, ""]
  end
  [rest.substring(0, cut), rest.substring(cut + 2, rest.len())]
end

-- the first `--> file:line:col` of the lines
fun location(lines: array<string>) -> array<string>
  for line in lines do
    let t = line.trim()
    if t.starts_with("--> ") then
      let spot = t.substring(4, t.len())
      let parts = spot.split(":")
      if parts.len() >= 2 then
        return [parts[0], parts[1]]
      end
    end
  end
  ["", "0"]
end

fun is_summary(line: string) -> bool
  regex.matches(line, "^[0-9]+ passed, [0-9]+ failed")
end

--" Reads the whole output of `qlang test`. --"
fun parse(text: string) -> Report
  let cases: array<Case> = []
  let other: array<string> = []
  let passed = 0
  let failed = 0
  let current: array<string> = []
  let open_case = -1
  let lines = text.split("\n")
  for line in lines do
    if line.starts_with("ok   ") or line.starts_with("FAIL ") then
      if open_case >= 0 then
        let spot = location(current)
        cases[open_case].detail = current
        cases[open_case].at_file = spot[0]
        cases[open_case].at_line = int.parse(spot[1]) ?? 0
      end
      current = []
      open_case = -1
      let ok = line.starts_with("ok   ")
      let names = split_case(line.substring(5, line.len()).trim())
      cases.push(Case { file: names[0], name: names[1], ok: ok, detail: [], at_file: "", at_line: 0 })
      if not ok then
        open_case = cases.len() - 1
      end
      continue
    end
    if is_summary(line) then
      let parts = line.split(" ")
      passed = int.parse(parts[0]) ?? 0
      failed = int.parse(parts[2]) ?? 0
      continue
    end
    if open_case >= 0 then
      if line.trim() != "" then
        current.push(line)
      end
    elseif line.trim() != "" then
      other.push(line)
    end
  end
  if open_case >= 0 then
    let spot = location(current)
    cases[open_case].detail = current
    cases[open_case].at_file = spot[0]
    cases[open_case].at_line = int.parse(spot[1]) ?? 0
  end
  Report { cases: cases, passed: passed, failed: failed, other: other }
end

export Case, Report, parse
