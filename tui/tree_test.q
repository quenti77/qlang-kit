import "buffer.q" as b
import "layout.q" as l
import "tree.q" as t

fun key(name: string) -> Event
  Event { kind: "key", key: name }
end

fun files() -> t.Tree
  t.Tree.create([t.Node.create("app", 0, true), t.Node.create("controllers", 1, true), t.Node.create("users.q", 2, false), t.Node.create("models.q", 1, false), t.Node.create("main.q", 0, false)])
end

fun label_of(tree: t.Tree) -> string
  let node = tree.selected_node()
  if node == none then
    return ""
  end
  node.label
end

fun screen_of(tree: t.Tree) -> array<string>
  let screen = b.Buffer.create(24, 8)
  tree.render(screen, l.Rect.create(0, 0, 24, 8), true)
  screen.lines()
end

fun test_closed_branches_hide_their_children()
  let tree = files()
  assert_eq(tree.shown(), 2)
  assert_eq(screen_of(tree), ["▸ app", "  main.q", "", "", "", "", "", ""])
end

fun test_right_opens_and_then_goes_to_the_first_child()
  let tree = files()
  tree.handle(key("Right"))
  assert_eq(tree.shown(), 4)
  tree.handle(key("Right"))
  assert_eq(label_of(tree), "controllers")
  assert_eq(screen_of(tree)[0], "▾ app")
  assert_eq(screen_of(tree)[1], "  ▸ controllers")
end

fun test_a_child_stays_hidden_while_its_own_parent_is_closed()
  let tree = files()
  tree.open_all()
  assert_eq(tree.shown(), 5)
  tree.handle(key("Down"))
  tree.handle(key("Left"))
  assert_eq(tree.shown(), 4)
  assert_eq(label_of(tree), "controllers")
end

fun test_left_on_a_leaf_goes_to_the_parent()
  let tree = files()
  tree.open_all()
  tree.handle(key("Down"))
  tree.handle(key("Down"))
  assert_eq(label_of(tree), "users.q")
  tree.handle(key("Left"))
  assert_eq(label_of(tree), "controllers")
  tree.handle(key("Left"))
  tree.handle(key("Left"))
  assert_eq(label_of(tree), "app")
end

fun test_enter_toggles_a_branch_and_leaves_a_leaf_to_the_program()
  let tree = files()
  assert(tree.handle(key("Enter")))
  assert_eq(tree.shown(), 4)
  assert(tree.handle(key("Enter")))
  assert_eq(tree.shown(), 2)
  tree.handle(key("Down"))
  assert(not tree.handle(key("Enter")))
  assert_eq(label_of(tree), "main.q")
end

fun test_an_empty_tree_is_harmless()
  let tree = t.Tree.create([])
  assert(not tree.handle(key("Down")))
  assert_eq(label_of(tree), "")
  assert_eq(screen_of(tree)[0], "")
end
