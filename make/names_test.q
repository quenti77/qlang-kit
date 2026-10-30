import "names.q" as n

fun test_a_name_is_cut_in_words_whatever_its_style()
  assert_eq(n.words("UserProfile"), ["user", "profile"])
  assert_eq(n.words("user_profile"), ["user", "profile"])
  assert_eq(n.words("user-profile"), ["user", "profile"])
  assert_eq(n.words("user profile"), ["user", "profile"])
  assert_eq(n.words("user"), ["user"])
  assert_eq(n.words("Oauth2Token"), ["oauth2", "token"])
  assert_eq(n.words("../x"), ["x"])
end

fun test_the_styles_are_built_from_the_words()
  let w = n.words("blog_post")
  assert_eq(n.pascal(w), "BlogPost")
  assert_eq(n.snake(w), "blog_post")
  assert_eq(n.kebab(w), "blog-post")
end

fun test_plurals()
  assert_eq(n.snake(n.plural(n.words("user"))), "users")
  assert_eq(n.snake(n.plural(n.words("category"))), "categories")
  assert_eq(n.snake(n.plural(n.words("day"))), "days")
  assert_eq(n.snake(n.plural(n.words("box"))), "boxes")
  assert_eq(n.snake(n.plural(n.words("blog_post"))), "blog_posts")
  assert_eq(n.snake(n.plural(n.words("news"))), "news")
end

fun test_a_name_that_is_not_code_is_refused()
  assert(n.is_valid("User"))
  assert(not n.is_valid(""))
  assert(not n.is_valid("---"))
  assert(not n.is_valid("9lives"))
end
