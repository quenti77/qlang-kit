import "make.q" as m

fun app_source() -> string
  "-- Puts the application together.\nimport \"@std/web/app.q\" as web\nimport \"providers.q\" as providers\nimport \"controllers.q\" as controllers\n\nfun build() -> web.App\n  web.App.boot(Reflect.declared(providers).concat(Reflect.declared(controllers)))\nend\n\nexport build\n"
end

fun project() -> map<string, string>
  {"app.q": app_source()}
end

fun plan_of(kind: string, name: string, store: map<string, string>, options: m.Options) -> array<m.Change>
  m.plan(kind, name, m.memory_files(store), options).unwrap()
end

fun test_a_controller_comes_with_its_test_and_is_registered()
  let changes = plan_of("controller", "BlogPost", project(), m.Options { now: 0 })
  assert_eq(changes.len(), 3)
  assert_eq(changes[0].path, "controllers/blog_posts.q")
  assert_eq(changes[0].action, "create")
  assert(changes[0].content.contains("fun blog_post_index()"))
  assert(changes[0].content.contains("#[web.Get(\"/blog-posts/:id\")]"))
  assert(changes[0].content.contains("\"BlogPost \{id}\""))
  assert_eq(changes[1].path, "tests/blog_posts_test.q")
  assert(changes[1].content.contains("test_blog_post_index_answers"))
  assert_eq(changes[2].path, "app.q")
  assert_eq(changes[2].action, "update")
  assert(changes[2].content.contains("import \"controllers/blog_posts.q\" as controllers_blog_posts"))
  assert(changes[2].content.contains(".concat(Reflect.declared(controllers_blog_posts)))"))
end

fun test_a_provider_is_made_and_registered_like_a_controller()
  let changes = plan_of("provider", "mailer", project(), m.Options { now: 0 })
  assert_eq(changes.len(), 2)
  assert_eq(changes[0].path, "providers/mailer.q")
  assert(changes[0].content.contains("fun make_mailer() -> Mailer"))
  assert_eq(changes[1].path, "app.q")
  assert(changes[1].content.contains("import \"providers/mailer.q\" as providers_mailer"))
  assert(changes[1].content.contains(".concat(Reflect.declared(providers_mailer)))"))
end

fun test_a_migration_is_listed_in_migrations_q_which_is_made_when_missing()
  let first = plan_of("migration", "create_posts_table", project(), m.Options { now: 1767225600000 })
  assert_eq(first.len(), 2)
  assert_eq(first[0].path, "migrations/20260101000000_create_posts_table.q")
  assert_eq(first[1].path, "migrations.q")
  assert_eq(first[1].action, "create")
  assert(first[1].content.contains("import \"migrations/20260101000000_create_posts_table.q\" as m_20260101000000_create_posts_table"))
  assert(first[1].content.contains("    m_20260101000000_create_posts_table.migration(),\n  ]"))
  -- the next one is added to the file that now exists
  let store = project()
  store["migrations.q"] = first[1].content
  let second = plan_of("migration", "add_age_to_users", store, m.Options { now: 1767312000000 })
  assert_eq(second[1].action, "update")
  assert(second[1].content.contains("m_20260102000000_add_age_to_users.migration(),"))
  assert(second[1].content.contains("m_20260101000000_create_posts_table.migration(),"))
end

fun test_registering_a_migration_twice_changes_nothing_and_a_strange_index_is_left_alone()
  let source = "import \"@std/web/migrate.q\" as mig\n\nfun all() -> array<mig.Migration>\n  [\n  ]\nend\n"
  let once = m.register_migration(source, "migrations/a.q", "m_a") ?? ""
  assert(once.contains("m_a.migration(),"))
  assert_eq(m.register_migration(once, "migrations/a.q", "m_a"), once)
  assert_eq(m.register_migration("fun all() -> int\n  1\nend\n", "migrations/a.q", "m_a"), none)
  let changes = plan_of("migration", "create_users_table", {"migrations.q": "fun all() -> int\n  1\nend\n"}, m.Options { now: 0 })
  assert_eq(changes[1].action, "skip")
  assert(changes[1].note.contains("migrations.q") or changes[1].note.contains("all()"))
  let off = plan_of("migration", "create_users_table", project(), m.Options { now: 0, register: false })
  assert_eq(off.len(), 1)
end

fun test_registering_twice_changes_nothing()
  let once = m.register_controller(app_source(), "controllers/users.q", "controllers_users") ?? ""
  assert(once.contains("controllers_users"))
  assert_eq(m.register_controller(once, "controllers/users.q", "controllers_users"), once)
end

fun test_an_app_that_is_not_the_usual_one_is_left_alone_with_a_hint()
  let changes = plan_of("controller", "user", {"app.q": "fun build() -> int\n  1\nend\n"}, m.Options { now: 0 })
  assert_eq(changes[2].action, "skip")
  assert(changes[2].note.contains("App.boot"))
  let without = plan_of("controller", "user", {}, m.Options { now: 0 })
  assert_eq(without.len(), 3)
  assert_eq(without[2].action, "skip")
end

fun test_options_turn_off_the_test_and_the_registration()
  let changes = plan_of("controller", "user", project(), m.Options { with_test: false, register: false })
  assert_eq(changes.len(), 1)
end

fun test_a_file_that_exists_is_not_replaced_unless_forced()
  let store = {"models/user.q": "old"}
  let refused = m.plan("model", "user", m.memory_files(store), m.Options {})
  assert(refused.is_err())
  assert(refused.unwrap_err().message.contains("--force"))
  let forced = m.plan("model", "user", m.memory_files(store), m.Options { force: true }).unwrap()
  assert_eq(forced[0].action, "update")
end

fun test_apply_writes_the_files_and_dry_run_is_just_not_calling_it()
  let store = project()
  let files = m.memory_files(store)
  let changes = m.plan("model", "category", files, m.Options {}).unwrap()
  assert_eq(store["models/category.q"], none)
  m.apply(changes, files)
  assert((store["models/category.q"] ?? "").contains("struct Category"))
  assert((store["models/category.q"] ?? "").contains("q.Query.table(\"categories\")"))
end

fun test_a_migration_gets_a_dated_id_and_a_table()
  let changes = plan_of("migration", "create_blog_posts_table", {}, m.Options { now: 1793369700000 })
  assert_eq(changes[0].path, "migrations/20261030141500_create_blog_posts_table.q")
  assert(changes[0].content.contains("CREATE TABLE blog_posts"))
  assert(changes[0].content.contains("DROP TABLE blog_posts"))
  let blank = plan_of("migration", "add_age_to_users", {}, m.Options { now: 1793369700000 })
  assert(blank[0].content.contains("up: []"))
end

fun test_timestamps_are_read_as_utc_dates()
  assert_eq(m.timestamp(0), "19700101000000")
  assert_eq(m.timestamp(1793369700000), "20261030141500")
  assert_eq(m.timestamp(951782400000), "20000229000000")
end

fun test_every_kind_has_a_stub_and_renders_without_a_left_over_placeholder()
  for kind in m.kinds() do
    let changes = plan_of(kind, "order_item", project(), m.Options { now: 0 })
    assert(not changes[0].content.contains("\{\{"))
    assert(changes[0].content.contains("OrderItem") or changes[0].content.contains("order_item") or changes[0].content.contains("order-item") or changes[0].content.contains("order_items"))
  end
end

fun test_a_project_stub_replaces_the_built_in_one()
  let store = {"stubs/job.stub": "-- my job \{\{Name}}\n"}
  let changes = plan_of("job", "send_mail", store, m.Options {})
  assert_eq(changes[0].content, "-- my job SendMail\n")
end

fun test_a_stub_with_an_unknown_placeholder_is_an_error()
  let store = {"stubs/job.stub": "\{\{Nope}}"}
  assert(m.plan("job", "x", m.memory_files(store), m.Options {}).is_err())
end

fun test_bad_kinds_and_names_are_refused()
  assert(m.plan("widget", "x", m.memory_files({}), m.Options {}).is_err())
  assert(m.plan("model", "123", m.memory_files({}), m.Options {}).is_err())
  assert(m.plan("model", "", m.memory_files({}), m.Options {}).is_err())
end

fun test_publish_copies_the_stubs_and_keeps_the_ones_that_exist()
  let store = {"stubs/job.stub": "mine"}
  let published = m.publish_stubs(m.memory_files(store)).unwrap()
  assert(published.len() > 5)
  assert(not published.contains("stubs/job.stub"))
  assert_eq(store["stubs/job.stub"], "mine")
  assert((store["stubs/model.stub"] ?? "").contains("\{\{Name}}"))
end
