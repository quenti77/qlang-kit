--" # Width of characters on the screen

How many columns of a terminal a character takes: `0` for the ones that join the one before (accents
written apart, zero-width joiners, variation selectors) and for control characters, `2` for Chinese,
Japanese and Korean characters, full-width forms and emoji, `1` for the others. It is read from the
UTF-8 bytes of the character, which covers the usual ranges without a table of the whole of Unicode.
--"

fun between(value: string, low: string, high: string) -> bool
  value >= low and value <= high
end

--" The columns taken by one character (a string of one character). --"
fun char_width(ch: string) -> int
  let bytes = ch.to_bytes()
  let n = bytes.len()
  let hex = bytes.hex()
  if n == 1 then
    let b = hex
    if b < "20" or b == "7f" then
      return 0
    end
    return 1
  end
  if n == 2 then
    let lead = hex.substring(0, 2)
    -- U+0300 to U+036F: accents written apart
    if lead == "cc" or lead == "cd" and hex.substring(2, 4) <= "af" then
      return 0
    end
    return 1
  end
  if n == 3 then
    let lead = hex.substring(0, 2)
    let second = hex.substring(2, 4)
    -- zero-width space, joiners and marks: U+200B to U+200F
    if lead == "e2" and second == "80" and between(hex.substring(4, 6), "8b", "8f") then
      return 0
    end
    -- variation selectors: U+FE00 to U+FE0F
    if lead == "ef" and second == "b8" and hex.substring(4, 6) <= "8f" then
      return 0
    end
    -- CJK, kana, symbols: U+2E80 to U+9FFF
    if between(lead, "e3", "e9") then
      return 2
    end
    if lead == "e2" and second >= "ba" and second <= "bf" then
      return 2
    end
    -- Hangul syllables: U+AC00 to U+D7A3
    if between(lead, "ea", "ec") and not (lead == "ea" and second < "b0") then
      return 2
    end
    if lead == "ed" and second <= "9e" then
      return 2
    end
    -- full-width forms: U+FF01 to U+FF60 and U+FFE0 to U+FFE6
    if lead == "ef" and second == "bc" then
      return 2
    end
    if lead == "ef" and second == "bd" and hex.substring(4, 6) <= "a0" then
      return 2
    end
    if lead == "ef" and second == "bf" and between(hex.substring(4, 6), "a0", "a6") then
      return 2
    end
    return 1
  end
  if n == 4 then
    let lead = hex.substring(0, 2)
    let second = hex.substring(2, 4)
    -- emoji and symbols: U+1F300 to U+1FAFF
    if lead == "f0" and second == "9f" then
      let third = hex.substring(4, 6)
      if between(third, "8c", "99") or between(third, "9a", "9f") or between(third, "a4", "ab") then
        return 2
      end
      return 1
    end
    -- CJK extensions: U+20000 to U+3FFFF
    if lead == "f0" and between(second, "a0", "af") then
      return 2
    end
    return 1
  end
  1
end

--" The columns taken by a text. --"
fun text_width(text: string) -> int
  let total = 0
  for ch in text.chars() do
    total += char_width(ch)
  end
  total
end

export char_width, text_width
