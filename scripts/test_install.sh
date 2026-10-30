#!/bin/sh
# Tests install.sh and the launcher against a release folder on disk (no network): installs, pins, refuses a bad checksum.
set -eu
here=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }

mirror="$work/mirror"
make_release() { # <version> <version.q text>
  v="$1"
  mkdir -p "$mirror/download/v$v" "$work/build-$v"
  sh "$here/scripts/package.sh" "$v" "$work/build-$v" >/dev/null
  if [ -n "${2:-}" ]; then
    (cd "$work/build-$v" && tar xzf "qlang-kit-$v.tar.gz" && printf '%s\n' "$2" > "qlang-kit-$v/version.q" \
      && tar czf "qlang-kit-$v.tar.gz" "qlang-kit-$v" && sha256sum "qlang-kit-$v.tar.gz" > SHA256SUMS)
  fi
  cp "$work/build-$v/qlang-kit-$v.tar.gz" "$work/build-$v/SHA256SUMS" "$mirror/download/v$v/"
}
make_release 0.1.0 'fun version() -> string
  "0.1.0"
end
export version'
make_release 0.2.0 'fun version() -> string
  "0.2.0"
end
export version'

export KIT_BASE_URL="file://$mirror"
export KIT_HOME="$work/home"
export KIT_INSTALL_DIR="$work/bin"
export KIT_INSTALL_URL="file://$here/install.sh"
unset KIT_VERSION

sh "$here/install.sh" --version 0.1.0 >/dev/null
[ -x "$work/bin/kit" ] || fail "the kit command was not installed"
[ "$("$work/bin/kit" version)" = "kit 0.1.0" ] || fail "kit version should say 0.1.0"
"$work/bin/kit" make --list | grep -q controller || fail "kit make --list does not work from the installed version"

sh "$here/install.sh" --version 0.2.0 >/dev/null
[ "$("$work/bin/kit" version)" = "kit 0.2.0" ] || fail "the latest installed version should win"
"$work/bin/kit" versions | grep -q "0.1.0" || fail "kit versions should list 0.1.0"
"$work/bin/kit" versions | grep -q "0.2.0 (latest installed)" || fail "kit versions should mark 0.2.0"

mkdir -p "$work/project/sub"
(cd "$work/project" && "$work/bin/kit" use 0.1.0 >/dev/null)
[ "$(cat "$work/project/.kit-version")" = "0.1.0" ] || fail "kit use should write .kit-version"
[ "$(cd "$work/project/sub" && "$work/bin/kit" version)" = "kit 0.1.0" ] || fail ".kit-version should apply to sub folders"
[ "$(cd "$work/project/sub" && KIT_VERSION=0.2.0 "$work/bin/kit" version)" = "kit 0.2.0" ] || fail "KIT_VERSION should win"
(cd "$work/project" && "$work/bin/kit" use 9.9.9 2>/dev/null) && fail "kit use should refuse a version that is not installed"

sh "$here/install.sh" --version 0.1.0 --keep-current >/dev/null
[ "$("$work/bin/kit" version)" = "kit 0.2.0" ] || fail "--keep-current should not change the latest installed version"

# a replaced download is refused and nothing is installed
make_release 0.3.0 ''
echo "tampered" >> "$mirror/download/v0.3.0/qlang-kit-0.3.0.tar.gz"
if sh "$here/install.sh" --version 0.3.0 >/dev/null 2>"$work/err"; then fail "a bad checksum should be refused"; fi
grep -q "checksum" "$work/err" || fail "the refusal should mention the checksum"
[ ! -d "$work/home/versions/0.3.0" ] || fail "nothing should be installed after a bad checksum"

if sh "$here/install.sh" --version 7.7.7 >/dev/null 2>"$work/err"; then fail "a missing release should fail"; fi
grep -q "no release v7.7.7" "$work/err" || fail "the failure should say which release is missing"
echo "the installer and the launcher are in order"
