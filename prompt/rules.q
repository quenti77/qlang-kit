--" # Rules for answers

A rule is a function that looks at what was typed and gives `none` when it is fine, or the message to show.
`check_all` runs several in order and stops at the first that complains.

```
let rules = [required(), min_length(3), matches("^[a-z_]+$", "lower case letters and _ only")]
check_all(rules, "ab")        -- "at least 3 characters"
```
--"
import "../tui/text.q" as tx

type Rule = fun(string) -> string?

--" Something must be typed. --"
fun required() -> Rule
  fun(text: string) -> string?
    if text.trim() == "" then "this is required" else none end
  end
end

--" At least `n` characters. --"
fun min_length(n: int) -> Rule
  fun(text: string) -> string?
    if text.chars().len() < n then "at least {n} characters" else none end
  end
end

--" At most `n` characters. --"
fun max_length(n: int) -> Rule
  fun(text: string) -> string?
    if text.chars().len() > n then "at most {n} characters" else none end
  end
end

--" Must match a regular expression; `message` is shown otherwise. --"
fun matches(pattern: string, message: string) -> Rule
  fun(text: string) -> string?
    if regex.matches(text, pattern) then none else message end
  end
end

--" Must be a whole number. --"
fun integer() -> Rule
  fun(text: string) -> string?
    if int.parse(text.trim()) == none then "a whole number, please" else none end
  end
end

--" Must be one of these. --"
fun one_of(options: array<string>) -> Rule
  fun(text: string) -> string?
    if options.contains(text) then none else "one of: " + options.join(", ") end
  end
end

--" The first complaint of the rules, or `none`. --"
fun check_all(rules: array<Rule>, text: string) -> string?
  for rule in rules do
    let problem = rule(text)
    if problem != none then
      return problem
    end
  end
  none
end

export Rule, required, min_length, max_length, matches, integer, one_of, check_all
