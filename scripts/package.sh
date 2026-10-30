#!/bin/sh
# Builds the release archive: scripts/package.sh <version> <output folder>
# It holds what kit needs to run (not the tests, the CI files nor this script) under qlang-kit-<version>/,
# and a SHA256SUMS file next to it.
set -eu
version="${1:?usage: package.sh <version> <output folder>}"
out="${2:?usage: package.sh <version> <output folder>}"
here=$(cd "$(dirname "$0")/.." && pwd)
mkdir -p "$out"
out=$(cd "$out" && pwd)
name="qlang-kit-$version"
cd "$here"
git ls-files -co --exclude-standard \
  | grep -v -e '_test\.q$' -e '^\.github/' -e '^scripts/' -e '^\.gitignore$' -e '^examples/' \
  > "$out/$name.files"
tar czf "$out/$name.tar.gz" --transform "s,^,$name/," -T "$out/$name.files"
rm -f "$out/$name.files"
(cd "$out" && sha256sum "$name.tar.gz" > SHA256SUMS)
echo "$out/$name.tar.gz"
