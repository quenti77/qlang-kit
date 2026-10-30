--" # Names

The same name written the ways code needs it: `UserProfile` (a type), `user_profile` (a function or a file),
`user-profile` (a URL), `user_profiles` (a table). Any of them, or `user profile`, is accepted as input.

```
words("UserProfile")            -- ["user", "profile"]
pascal(words("user-profile"))   -- "UserProfile"
plural(words("category"))       -- ["categories"]
```
--"

fun is_upper(ch: string) -> bool
  ch.upper() == ch and ch.lower() != ch
end

fun is_word_char(ch: string) -> bool
  ch.is_alpha() or ch.is_digit()
end

--" The lower case words of a name: it is cut at `_`, `-`, spaces and where a capital letter follows a small
one. Anything else is dropped. --"
fun words(name: string) -> array<string>
  let out: array<string> = []
  let current = ""
  let previous_small = false
  for ch in name.chars() do
    if not is_word_char(ch) then
      if current != "" then
        out.push(current)
        current = ""
      end
      previous_small = false
      continue
    end
    if is_upper(ch) and previous_small and current != "" then
      out.push(current)
      current = ""
    end
    current += ch.lower()
    previous_small = not is_upper(ch)
  end
  if current != "" then
    out.push(current)
  end
  out
end

--" Whether the name can be turned into code: at least one word, the first not starting with a digit. --"
fun is_valid(name: string) -> bool
  let w = words(name)
  not w.is_empty() and not w[0].substring(0, 1).is_digit()
end

fun capital(word: string) -> string
  if word == "" then
    return ""
  end
  word.substring(0, 1).upper() + word.substring(1, word.len())
end

--" `UserProfile`. --"
fun pascal(parts: array<string>) -> string
  parts.map(fun(w: string) -> string capital(w) end).join("")
end

--" `user_profile`. --"
fun snake(parts: array<string>) -> string
  parts.join("_")
end

--" `user-profile`. --"
fun kebab(parts: array<string>) -> string
  parts.join("-")
end

fun is_vowel(ch: string) -> bool
  ch == "a" or ch == "e" or ch == "i" or ch == "o" or ch == "u"
end

--" The last word in the plural (English rules: `category` -> `categories`, `box` -> `boxes`, `user` -> `users`;
a word that already ends in `s` is left as it is). --"
fun plural(parts: array<string>) -> array<string>
  if parts.is_empty() then
    return parts
  end
  let last = parts[parts.len() - 1]
  let n = last.len()
  let changed = last + "s"
  if last.ends_with("s") then
    changed = last
  elseif last.ends_with("y") and n > 1 and not is_vowel(last.substring(n - 2, n - 1)) then
    changed = last.substring(0, n - 1) + "ies"
  elseif last.ends_with("x") or last.ends_with("z") or last.ends_with("ch") or last.ends_with("sh") then
    changed = last + "es"
  end
  let out = parts.slice(0, parts.len() - 1)
  out.push(changed)
  out
end

export words, is_valid, pascal, snake, kebab, plural
