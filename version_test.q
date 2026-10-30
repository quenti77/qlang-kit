import "version.q" as v

fun test_the_version_is_the_one_of_qlang_toml()
  let toml = fs.read("qlang.toml").unwrap()
  assert(toml.contains("version = \"" + v.version() + "\""))
end

fun test_the_version_looks_like_a_version()
  assert(regex.matches(v.version(), "^[0-9]+\\.[0-9]+\\.[0-9]+$"))
end
