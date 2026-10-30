--" # Text that fits

Cutting, padding and wrapping text by its **width on the screen**, not by its number of characters: a
Chinese character or an emoji takes two columns.

```
truncate("a long title", 8)            -- "a long …"
fit("ab", 5, "right")                  -- "   ab"
wrap("one two three", 7)               -- ["one two", "three"]
```
--"
import "width.q" as w

--" The text cut to `max` columns, with `…` where it was cut. --"
fun truncate(text: string, max: int) -> string
  if max <= 0 then
    return ""
  end
  if w.text_width(text) <= max then
    return text
  end
  if max == 1 then
    return "…"
  end
  clip(text, max - 1) + "…"
end

--" The text cut to `max` columns, without any mark. A wide character that would be cut in two is dropped. --"
fun clip(text: string, max: int) -> string
  let out = ""
  let used = 0
  for ch in text.chars() do
    let width = w.char_width(ch)
    if used + width > max then
      break
    end
    out += ch
    used += width
  end
  out
end

fun spaces(n: int) -> string
  let out = ""
  for i in 0..n do
    out += " "
  end
  out
end

--" The text exactly `width` columns wide: cut with `…` if too long, else padded with spaces.
`align` is `"left"`, `"right"` or `"center"`. --"
fun fit(text: string, width: int, align: string) -> string
  let cut = truncate(text, width)
  let free = width - w.text_width(cut)
  if free <= 0 then
    return cut
  end
  if align == "right" then
    return spaces(free) + cut
  end
  if align == "center" then
    let left = free div 2
    return spaces(left) + cut + spaces(free - left)
  end
  cut + spaces(free)
end

-- a word longer than the width is cut into pieces that fit
fun break_word(word: string, width: int) -> array<string>
  let pieces: array<string> = []
  let current = ""
  let used = 0
  for ch in word.chars() do
    let cw = w.char_width(ch)
    if used + cw > width and current != "" then
      pieces.push(current)
      current = ""
      used = 0
    end
    current += ch
    used += cw
  end
  if current != "" then
    pieces.push(current)
  end
  pieces
end

--" The text cut into lines of at most `width` columns, at spaces; a newline starts a new line and a word
longer than a line is cut. Empty lines are kept. --"
fun wrap(text: string, width: int) -> array<string>
  let lines: array<string> = []
  if width <= 0 then
    return lines
  end
  for paragraph in text.split("\n") do
    let line = ""
    let used = 0
    for word in paragraph.split(" ") do
      if word == "" then
        continue
      end
      let size = w.text_width(word)
      if size > width then
        if line != "" then
          lines.push(line)
          line = ""
          used = 0
        end
        let pieces = break_word(word, width)
        for i in 0..(pieces.len() - 1) do
          lines.push(pieces[i])
        end
        line = pieces[pieces.len() - 1]
        used = w.text_width(line)
        continue
      end
      if line == "" then
        line = word
        used = size
      elseif used + 1 + size <= width then
        line += " " + word
        used += 1 + size
      else
        lines.push(line)
        line = word
        used = size
      end
    end
    lines.push(line)
  end
  lines
end

export truncate, clip, fit, wrap, spaces
