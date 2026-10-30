--" # Tree

Nodes that can be opened to show their children (files in folders, routes under a prefix). Nodes are
stored flat: each has a `depth`, and the ones that follow it with a bigger depth are its children.

```
let tree = Tree.create([
    Node.create("app", 0, true),
    Node.create("controllers.q", 1, false),
    Node.create("models.q", 1, false),
    Node.create("main.q", 0, false),
])
tree.handle(event)          -- Up/Down move, Right opens, Left closes (or goes to the parent), Enter toggles
tree.render(screen, area, true)
tree.selected_node()        -- the Node under the cursor
```
--"
import "buffer.q" as b
import "layout.q" as l
import "list.q" as li
import "style.q" as st
import "text.q" as tx

--" One line of the tree: its text, its depth, whether it has children, and whether it is open. --"
struct Node
  public label: string
  public depth: int
  public branch: bool
  public open: bool
end

impl Node
  --" A node; `branch` says that it can be opened (it has children, even if they are not loaded). --"
  public fun create(label: string, depth: int, branch: bool) -> Node
    Node { label: label, depth: depth, branch: branch, open: false }
  end
end

--" Nodes in order, shown as an indented outline. --"
struct Tree
  nodes: array<Node>
  selected: int
  offset: int
  page: int
end

impl Tree
  public fun create(nodes: array<Node>) -> Tree
    Tree { nodes: nodes, selected: 0, offset: 0, page: 10 }
  end

  -- the indexes of the nodes that are shown: those whose parents are all open
  fun visible(self) -> array<int>
    let out: array<int> = []
    let hidden_below = -1
    for i in 0..self.nodes.len() do
      let n = self.nodes[i]
      if hidden_below >= 0 and n.depth > hidden_below then
        continue
      end
      hidden_below = -1
      out.push(i)
      if n.branch and not n.open then
        hidden_below = n.depth
      end
    end
    out
  end

  --" How many lines are shown. --"
  public fun shown(self) -> int
    self.visible().len()
  end

  --" The node under the cursor, or `none` for an empty tree. --"
  public fun selected_node(self) -> Node?
    let rows = self.visible()
    if rows.is_empty() then
      return none
    end
    self.nodes[rows[self.selected]]
  end

  fun move_to(self, row: int)
    let last = self.visible().len() - 1
    if last < 0 then
      self.selected = 0
      return
    end
    self.selected = if row < 0 then 0 elseif row > last then last else row end
  end

  -- the row (among the visible ones) of the parent of the selected node, or -1
  fun parent_row(self) -> int
    let rows = self.visible()
    let depth = self.nodes[rows[self.selected]].depth
    let r = self.selected - 1
    while r >= 0 do
      if self.nodes[rows[r]].depth < depth then
        return r
      end
      r -= 1
    end
    -1
  end

  --" Opens the selected node if it can be opened. --"
  public fun open(self)
    let rows = self.visible()
    if rows.is_empty() then
      return
    end
    let n = self.nodes[rows[self.selected]]
    if n.branch then
      n.open = true
    end
  end

  --" Closes the selected node. --"
  public fun close(self)
    let rows = self.visible()
    if rows.is_empty() then
      return
    end
    self.nodes[rows[self.selected]].open = false
  end

  --" Opens every node. --"
  public fun open_all(self)
    for n in self.nodes do
      if n.branch then
        n.open = true
      end
    end
  end

  --" Uses the event if it moves or opens something. --"
  public fun handle(self, ev: Event) -> bool
    if ev.kind == "mouse" then
      if ev.action == "scroll_down" then
        self.move_to(self.selected + 3)
        return true
      end
      if ev.action == "scroll_up" then
        self.move_to(self.selected - 3)
        return true
      end
      return false
    end
    if ev.kind != "key" or ev.ctrl or ev.alt then
      return false
    end
    let rows = self.visible()
    if rows.is_empty() then
      return false
    end
    let node = self.nodes[rows[self.selected]]
    if ev.key == "Down" or ev.key == "j" then
      self.move_to(self.selected + 1)
    elseif ev.key == "Up" or ev.key == "k" then
      self.move_to(self.selected - 1)
    elseif ev.key == "PageDown" then
      self.move_to(self.selected + self.page)
    elseif ev.key == "PageUp" then
      self.move_to(self.selected - self.page)
    elseif ev.key == "Home" then
      self.move_to(0)
    elseif ev.key == "End" then
      self.move_to(rows.len() - 1)
    elseif ev.key == "Right" or ev.key == "l" then
      if node.branch and not node.open then
        node.open = true
      else
        self.move_to(self.selected + 1)
      end
    elseif ev.key == "Left" or ev.key == "h" then
      if node.branch and node.open then
        node.open = false
      else
        let parent = self.parent_row()
        if parent >= 0 then
          self.move_to(parent)
        end
      end
    elseif ev.key == "Enter" or ev.key == " " then
      if node.branch then
        node.open = not node.open
      else
        return false
      end
    else
      return false
    end
    true
  end

  --" Draws the lines that fit in `area`. --"
  public fun render(self, screen: b.Buffer, area: l.Rect, focused: bool)
    if area.is_empty() then
      return
    end
    let rows = self.visible()
    self.page = area.h
    self.move_to(self.selected)
    if self.selected < self.offset then
      self.offset = self.selected
    end
    if self.selected >= self.offset + area.h then
      self.offset = self.selected - area.h + 1
    end
    let bar = rows.len() > area.h
    let width = if bar then area.w - 1 else area.w end
    for line in 0..area.h do
      let r = self.offset + line
      if r >= rows.len() then
        break
      end
      let n = self.nodes[rows[r]]
      let mark = if n.branch then (if n.open then "▾ " else "▸ " end) else "  " end
      let indent = ""
      for i in 0..n.depth do
        indent += "  "
      end
      let chosen = r == self.selected
      let style = if chosen and focused then st.Style.create().reverse() elseif chosen then st.Style.create().bold() else st.Style.create() end
      screen.put(area.x, area.y + line, tx.fit(indent + mark + n.label, width, "left"), style)
    end
    if bar then
      li.scrollbar(screen, area.x + area.w - 1, area.y, area.h, rows.len(), self.offset)
    end
  end
end

export Node, Tree
