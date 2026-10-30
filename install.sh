#!/bin/sh
# Install or update kit, the command line tool of the qlang framework (https://github.com/quenti77/qlang-kit).
#
#   curl -fsSL https://raw.githubusercontent.com/quenti77/qlang-kit/main/install.sh | sh
#   curl -fsSL .../install.sh | sh -s -- --version 0.1.0
#
# Running it again installs the latest release next to the others (they are kept: `kit versions`, `kit use X`).
# kit is written in qlang and needs the `qlang` command (https://github.com/quenti77/qlang).
#
# Options:
#   --version X      install this version instead of the latest one
#   --dir DIR        put the `kit` command in DIR (default: $HOME/.local/bin, or $KIT_INSTALL_DIR)
#   --home DIR       keep the versions in DIR (default: $HOME/.local/share/kit, or $KIT_HOME)
#   --keep-current   do not make this version the latest one installed
#   --help
#
# Environment: KIT_BASE_URL overrides https://github.com/quenti77/qlang-kit/releases (a mirror, or tests).
set -eu

repo="quenti77/qlang-kit"
base_url="${KIT_BASE_URL:-https://github.com/$repo/releases}"
dir="${KIT_INSTALL_DIR:-$HOME/.local/bin}"
home="${KIT_HOME:-$HOME/.local/share/kit}"
version="latest"
keep_current=0

say() { printf '%s\n' "$*"; }
fail() { printf 'install.sh: %s\n' "$*" >&2; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --version) [ $# -ge 2 ] || fail "--version needs a value"; version="${2#v}"; shift 2 ;;
    --dir) [ $# -ge 2 ] || fail "--dir needs a value"; dir="$2"; shift 2 ;;
    --home) [ $# -ge 2 ] || fail "--home needs a value"; home="$2"; shift 2 ;;
    --keep-current) keep_current=1; shift ;;
    --help|-h) sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) fail "unknown option $1 (try --help)" ;;
  esac
done

download() {
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$1" -o "$2"
  elif command -v wget >/dev/null 2>&1; then
    wget -q "$1" -O "$2"
  else
    fail "curl or wget is needed"
  fi
}

if [ "$version" = "latest" ]; then
  command -v curl >/dev/null 2>&1 || fail "curl is needed to find the latest version (or use --version)"
  tag=$(curl -fsSLI -o /dev/null -w '%{url_effective}' "$base_url/latest") || fail "cannot reach $base_url"
  version="${tag##*/}"
  version="${version#v}"
  [ -n "$version" ] && [ "$version" != "latest" ] || fail "cannot find the latest version at $base_url"
fi

asset="qlang-kit-$version.tar.gz"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

say "downloading kit $version"
download "$base_url/download/v$version/$asset" "$tmp/$asset" || fail "no release v$version at $base_url"
download "$base_url/download/v$version/SHA256SUMS" "$tmp/SHA256SUMS" || fail "cannot download SHA256SUMS"

# the checksum, so that a damaged or replaced download is refused
if command -v sha256sum >/dev/null 2>&1; then
  (cd "$tmp" && sha256sum -c --ignore-missing SHA256SUMS >/dev/null 2>&1) || fail "the checksum of $asset does not match"
elif command -v shasum >/dev/null 2>&1; then
  want=$(grep " $asset\$" "$tmp/SHA256SUMS" | awk '{print $1}')
  got=$(shasum -a 256 "$tmp/$asset" | awk '{print $1}')
  [ -n "$want" ] && [ "$want" = "$got" ] || fail "the checksum of $asset does not match"
else
  fail "sha256sum or shasum is needed to check the download"
fi
grep -q " $asset\$" "$tmp/SHA256SUMS" || fail "$asset is not in SHA256SUMS"

target="$home/versions/$version"
rm -rf "$target"
mkdir -p "$target"
tar xzf "$tmp/$asset" -C "$target" --strip-components=1

mkdir -p "$dir"
install -m755 "$target/bin/launcher" "$dir/kit"
if [ "$keep_current" -eq 0 ]; then
  printf '%s\n' "$version" > "$home/current"
fi

say "installed kit $version in $target"
say "the command is $dir/kit"
case ":$PATH:" in
  *":$dir:"*) ;;
  *) say "add $dir to your PATH:  export PATH=\"$dir:\$PATH\"" ;;
esac
command -v qlang >/dev/null 2>&1 || say "kit needs qlang: https://github.com/quenti77/qlang#install"
