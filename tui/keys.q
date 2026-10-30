--" # Key bindings and focus

A **chord** is a key with modifiers written as text: `"q"`, `"ctrl+s"`, `"alt+Enter"`, `"shift+Tab"`, `"F5"`, `"G"`
(a capital letter means Shift). A `Keymap` maps chords to the name of an action, so the keys of a program are
data you can show in a help bar or let the user change. A `FocusRing` says which of several widgets has the
focus and moves it with `Tab` and `Shift+Tab`.

```
let keys = Keymap.create().bind("q", "quit").bind("ctrl+s", "save").bind("?", "help")
let action = keys.action_for(event)            -- "quit", "save", "help" or ""
HelpBar.create(keys.hints(["quit", "save"]))    -- [["q", "quit"], ["ctrl+s", "save"]]

let focus = FocusRing.create(["list", "search", "details"])
focus.handle(event)                             -- Tab moves it
if focus.has("search") then ... end
```
--"

--" A key with modifiers. --"
struct Chord
  public key: string
  public ctrl: bool
  public alt: bool
  public shift: bool
  spec: string
end

impl Chord
  --" Reads `"ctrl+shift+x"`. A trailing `+` is the key `+` itself (`"ctrl++"`). --"
  public fun parse(spec: string) -> Chord
    let ctrl = false
    let alt = false
    let shift = false
    let key = spec
    let parts = spec.split("+")
    if spec == "+" then
      return Chord { key: "+", ctrl: false, alt: false, shift: false, spec: spec }
    end
    let wanted = if spec.ends_with("++") then parts.len() - 2 else parts.len() - 1 end
    for i in 0..wanted do
      let m = parts[i].lower()
      if m == "ctrl" or m == "control" then
        ctrl = true
      elseif m == "alt" or m == "meta" then
        alt = true
      elseif m == "shift" then
        shift = true
      end
    end
    key = if spec.ends_with("++") then "+" else parts[parts.len() - 1] end
    if key.chars().len() == 1 and key.lower() != key then
      shift = true
      key = key.lower()
    end
    Chord { key: key, ctrl: ctrl, alt: alt, shift: shift, spec: spec }
  end

  public fun text(self) -> string
    self.spec
  end

  --" Whether the event is this key. Letters are compared without regard to case (Shift is what tells `g`
    from `G`); for the other single characters (`?`, `:`) Shift is not looked at, since keyboards differ. --"
  public fun matches(self, ev: Event) -> bool
    if ev.kind != "key" or ev.ctrl != self.ctrl or ev.alt != self.alt then
      return false
    end
    let pressed = ev.key
    if self.key.chars().len() != 1 or pressed.chars().len() != 1 then
      return pressed == self.key and ev.shift == self.shift
    end
    let letter = self.key.lower() != self.key.upper()
    if not letter then
      return pressed == self.key
    end
    let shifted = ev.shift or pressed.lower() != pressed
    pressed.lower() == self.key and shifted == self.shift
  end
end

--" Chords and the actions they trigger. --"
struct Keymap
  chords: array<Chord>
  actions: array<string>
end

impl Keymap
  public fun create() -> Keymap
    Keymap { chords: [], actions: [] }
  end

  --" Binds a chord to an action (the chord written as text). A chord bound twice goes to the later action. --"
  public fun bind(self, spec: string, action: string) -> Keymap
    for i in 0..self.chords.len() do
      if self.chords[i].text() == spec then
        self.actions[i] = action
        return self
      end
    end
    self.chords.push(Chord.parse(spec))
    self.actions.push(action)
    self
  end

  --" The action for an event, or `""`. --"
  public fun action_for(self, ev: Event) -> string
    for i in 0..self.chords.len() do
      if self.chords[i].matches(ev) then
        return self.actions[i]
      end
    end
    ""
  end

  --" The chord (as text) bound to an action, or `""`. --"
  public fun chord_of(self, action: string) -> string
    for i in 0..self.actions.len() do
      if self.actions[i] == action then
        return self.chords[i].text()
      end
    end
    ""
  end

  --" `[chord, action]` pairs for the actions you list, in that order: what a `HelpBar` takes. --"
  public fun hints(self, actions: array<string>) -> array<array<string>>
    let out: array<array<string>> = []
    for action in actions do
      let chord = self.chord_of(action)
      if chord != "" then
        out.push([chord, action])
      end
    end
    out
  end
end

--" Which of several named widgets has the focus. --"
struct FocusRing
  ids: array<string>
  current: int
end

impl FocusRing
  public fun create(ids: array<string>) -> FocusRing
    FocusRing { ids: ids, current: 0 }
  end

  --" The name of the widget that has the focus (`""` if there is none). --"
  public fun focused(self) -> string
    if self.ids.is_empty() then
      return ""
    end
    self.ids[self.current]
  end

  public fun has(self, id: string) -> bool
    self.focused() == id
  end

  --" Gives the focus to a widget by name; false if there is no such widget. --"
  public fun focus(self, id: string) -> bool
    for i in 0..self.ids.len() do
      if self.ids[i] == id then
        self.current = i
        return true
      end
    end
    false
  end

  public fun next(self)
    if not self.ids.is_empty() then
      self.current = (self.current + 1) % self.ids.len()
    end
  end

  public fun prev(self)
    if not self.ids.is_empty() then
      self.current = (self.current + self.ids.len() - 1) % self.ids.len()
    end
  end

  --" `Tab` and `Shift+Tab` move the focus; says whether it used the event. A widget that needs `Tab`
    for itself (a text area) must get the event first. --"
  public fun handle(self, ev: Event) -> bool
    if ev.kind != "key" or ev.key != "Tab" or ev.ctrl or ev.alt then
      return false
    end
    if ev.shift then
      self.prev()
    else
      self.next()
    end
    true
  end
end

export Chord, Keymap, FocusRing
