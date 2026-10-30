import "../make/make.q" as mk
import "../tui/testing.q" as t
import "app.q" as w

fun app_source() -> string
  "import \"@std/web/app.q\" as web\nimport \"controllers.q\" as controllers\n\nfun build() -> web.App\n  web.App.boot(Reflect.declared(controllers))\nend\n\nexport build\n"
end

fun start(store: map<string, string>) -> t.Harness
  t.Harness.start(110, 30, w.create(mk.memory_files(store), fun() -> int 1793369700000 end))
end

fun test_the_screen_asks_for_a_name_first()
  let app = start({})
  assert(app.contains("Kind"))
  assert(app.contains("controller"))
  assert(app.contains("type a name to see the files"))
end

fun test_typing_a_name_previews_the_files_and_their_content()
  let app = start({"app.q": app_source()})
  app.key("Tab")
  app.text("BlogPost")
  assert(app.contains("create  controllers/blog_posts.q"))
  assert(app.contains("create  tests/blog_posts_test.q"))
  assert(app.contains("update  app.q"))
  assert(app.contains("fun blog_post_index()"))
end

fun test_choosing_another_kind_changes_the_preview()
  let app = start({})
  app.key("Tab")
  app.text("Post")
  app.key("Esc")
  app.key("Down")
  assert(app.contains("models/post.q"))
  assert(app.contains("struct Post"))
  assert(not app.contains("controllers/posts.q"))
end

fun test_options_are_toggled_with_letters_when_the_name_is_not_being_typed()
  let app = start({"app.q": app_source()})
  app.key("Tab")
  app.text("Post")
  app.key("Esc")
  assert(app.contains("tests/posts_test.q"))
  app.key("t")
  assert(not app.contains("tests/posts_test.q"))
  app.key("r")
  assert(not app.contains("update  app.q"))
  assert(app.contains("[ ] t"))
end

fun test_a_letter_typed_in_the_name_is_part_of_the_name_not_an_option()
  let app = start({})
  app.key("Tab")
  app.text("tfq")
  assert(not app.finished())
  assert(app.contains("tfq"))
end

fun test_ctrl_s_writes_the_files_and_says_so()
  let store = {"app.q": app_source()}
  let app = start(store)
  app.key("Tab")
  app.text("Post")
  app.ctrl("s")
  assert(app.contains("wrote 3 file(s)"))
  assert((store["controllers/posts.q"] ?? "").contains("fun post_index()"))
  assert((store["app.q"] ?? "").contains("controllers_posts"))
  assert(app.contains("type a name to see the files"))
end

fun test_an_existing_file_is_reported_and_f_replaces_it()
  let store = {"controllers/posts.q": "old", "app.q": app_source()}
  let app = start(store)
  app.key("Tab")
  app.text("Post")
  assert(app.contains("already exists"))
  app.key("Esc")
  app.key("f")
  assert(app.contains("update  controllers/posts.q"))
  app.ctrl("s")
  assert((store["controllers/posts.q"] ?? "").contains("post_index"))
end

fun test_the_preview_scrolls_and_the_file_list_changes_what_is_shown()
  let app = start({"app.q": app_source()})
  app.key("Tab")
  app.text("Post")
  app.key("Tab")
  app.key("Down")
  assert(app.contains("Tests of the Post controller"))
  app.key("Tab")
  app.key("PageDown")
  assert(not app.contains("Tests of the Post controller"))
end

fun test_nothing_to_write_is_said()
  let app = start({})
  app.ctrl("s")
  assert(app.contains("nothing to write"))
end

fun test_q_quits_when_not_typing()
  let app = start({})
  app.key("q")
  assert(app.finished())
end
