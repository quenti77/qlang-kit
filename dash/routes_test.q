import "routes.q" as r

fun test_operations_are_listed_by_path_then_method()
  let text = "\{\"paths\":\{\"/users\":\{\"post\":\{\"summary\":\"Create\"},\"get\":\{\"summary\":\"List\"}},\"/\":\{\"get\":\{}}}}"
  let routes = r.parse(text).unwrap()
  assert_eq(routes.len(), 3)
  assert_eq(routes[0].path, "/")
  assert_eq(routes[0].summary, "")
  assert_eq(routes[1].method, "GET")
  assert_eq(routes[1].summary, "List")
  assert_eq(routes[2].method, "POST")
end

fun test_a_document_that_is_not_openapi_is_an_error()
  assert(r.parse("not json").is_err())
  assert(r.parse("\{\"info\":\{}}").is_err())
end
