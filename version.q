--" # Version

The version of kit. It must be the one of `qlang.toml` and of the tag of the release (the release workflow checks it).
--"

fun version() -> string
    "1.0.0"
end

export version
