import "make.q" as mk
import "project.q" as p

fun test_the_dependency_is_added_under_dependencies()
  let toml = "[package]\nname = \"app\"\n\n[dependencies]\nstd = \{ git = \"x\", tag = \"v1\" }\n"
  let out = p.with_dependency(toml, "0.1.0") ?? ""
  assert(out.contains("[dependencies]\nkit = \{ git = \"https://github.com/quenti77/qlang-kit\", tag = \"v0.1.0\" }\nstd"))
end

fun test_a_project_without_dependencies_gets_the_section()
  let out = p.with_dependency("[package]\nname = \"app\"\n", "0.1.0") ?? ""
  assert(out.ends_with("[dependencies]\nkit = \{ git = \"https://github.com/quenti77/qlang-kit\", tag = \"v0.1.0\" }\n"))
end

fun test_a_project_that_has_kit_already_is_left_alone()
  assert(p.with_dependency("[dependencies]\nkit = \{ path = \"../kit\" }\n", "0.1.0") == none)
end

fun test_init_adds_the_dependency_and_writes_the_launcher()
  let store = {"qlang.toml": "[package]\nname = \"app\"\n"}
  let files = mk.memory_files(store)
  let changes = p.plan_init(files, "0.1.0", false).unwrap()
  assert_eq(changes.len(), 2)
  mk.apply(changes, files)
  assert((store["qlang.toml"] ?? "").contains("tag = \"v0.1.0\""))
  assert((store["kit.q"] ?? "").contains("import \"@kit/cli.q\" as cli"))
end

fun test_init_keeps_a_kit_q_that_exists_unless_forced()
  let files = mk.memory_files({"qlang.toml": "[package]\n", "kit.q": "mine"})
  let kept = p.plan_init(files, "0.1.0", false).unwrap()
  assert_eq(kept[kept.len() - 1].action, "skip")
  let forced = p.plan_init(files, "0.1.0", true).unwrap()
  assert_eq(forced[forced.len() - 1].action, "update")
end

fun test_init_needs_a_project()
  assert(p.plan_init(mk.memory_files({}), "0.1.0", false).is_err())
end
