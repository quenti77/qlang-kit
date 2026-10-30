--" # Reading Prometheus metrics

`qlang-std` serves its counters in the Prometheus text format (`web/metrics.q`). This module reads that text
and sums it up per route: how many requests, how many errors, and how long they took (p50 and p95 from the
histogram buckets).

```
let samples = parse(text)                      -- every line as a Sample
let routes = route_stats(samples)              -- one RouteStat per route
```
--"

--" One line of the text: `http_requests_total{method="GET",route="/",status="2xx"} 42`. --"
struct Sample
  public name: string
  public labels: map<string, string>
  public value: float
end

--" What a route has done so far. --"
struct RouteStat
  public route: string
  public requests: int
  public errors: int
  public p50: float
  public p95: float
end

fun parse_labels(text: string) -> map<string, string>
  let out: map<string, string> = {}
  if text == "" then
    return out
  end
  for pair in text.split("\",") do
    let cut = pair.index_of("=\"")
    if cut == none then
      continue
    end
    let key = pair.substring(0, cut).trim()
    let value = pair.substring(cut + 2, pair.len())
    out[key] = if value.ends_with("\"") then value.substring(0, value.len() - 1) else value end
  end
  out
end

--" Reads the text; comments and lines it cannot read are skipped. --"
fun parse(text: string) -> array<Sample>
  let out: array<Sample> = []
  for raw in text.split("\n") do
    let line = raw.trim()
    if line == "" or line.starts_with("#") then
      continue
    end
    let open = line.index_of("\{")
    let space = line.last_index_of(" ")
    if space == none then
      continue
    end
    let value = float.parse(line.substring(space + 1, line.len()))
    if value == none then
      continue
    end
    let name = ""
    let labels: map<string, string> = {}
    if open != none then
      let close = line.last_index_of("\}")
      if close == none then
        continue
      end
      name = line.substring(0, open)
      labels = parse_labels(line.substring(open + 1, close))
    else
      name = line.substring(0, space)
    end
    out.push(Sample { name: name, labels: labels, value: value })
  end
  out
end

fun label(s: Sample, key: string) -> string
  s.labels[key] ?? ""
end

-- the smallest bucket that holds `ratio` of the requests, in milliseconds
fun quantile(buckets: array<Sample>, total: float, ratio: float) -> float
  if total <= 0.0 then
    return 0.0
  end
  let best = -1.0
  let best_value = 0.0
  for s in buckets do
    let le = label(s, "le")
    if le == "+Inf" then
      continue
    end
    let bound = float.parse(le) ?? 0.0
    if s.value >= total * ratio and (best < 0.0 or bound < best) then
      best = bound
      best_value = bound
    end
  end
  if best < 0.0 then
    -- more than the largest bucket
    let largest = 0.0
    for s in buckets do
      let bound = float.parse(label(s, "le")) ?? 0.0
      if bound > largest then
        largest = bound
      end
    end
    return largest
  end
  best_value
end

--" The routes found in the samples, busiest first. --"
fun route_stats(samples: array<Sample>) -> array<RouteStat>
  let names: array<string> = []
  for s in samples do
    if s.name == "http_requests_total" then
      let route = label(s, "route")
      if not names.contains(route) then
        names.push(route)
      end
    end
  end
  let stats: array<RouteStat> = []
  for route in names do
    let requests = 0.0
    let errors = 0.0
    let buckets: array<Sample> = []
    let count = 0.0
    for s in samples do
      if label(s, "route") != route then
        continue
      end
      if s.name == "http_requests_total" then
        requests += s.value
        if label(s, "status") == "5xx" then
          errors += s.value
        end
      elseif s.name == "http_request_duration_ms_bucket" then
        buckets.push(s)
      elseif s.name == "http_request_duration_ms_count" then
        count = s.value
      end
    end
    stats.push(RouteStat { route: route, requests: requests as int, errors: errors as int, p50: quantile(buckets, count, 0.5), p95: quantile(buckets, count, 0.95) })
  end
  stats.sort_by(fun(a: RouteStat, b: RouteStat) -> int b.requests - a.requests end)
  stats
end

--" The value of a metric without labels (`queue_jobs_pending`), or 0. --"
fun gauge(samples: array<Sample>, name: string) -> float
  for s in samples do
    if s.name == name and s.labels.is_empty() then
      return s.value
    end
  end
  0.0
end

export Sample, RouteStat, parse, route_stats, gauge
