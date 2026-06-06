#!/usr/bin/env nix-shell
#!nix-shell -i bash -p nix curl jq nodejs prefetch-npm-deps
# shellcheck shell=bash
#
# Bump viteplus to the latest vite-plus release on npm and refresh:
# - @voidzero-dev/vite-plus-cli-* platform tarball hashes
# - vite-plus npm dependency lockfile + npmDepsHash
#
# Usage (from repo root):
#   nix develop
#   nix-update --flake viteplus
#
# Or run directly:
#   ./viteplus/update-viteplus.sh
#   VERSION=0.1.25 ./viteplus/update-viteplus.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NIX_FILE="$SCRIPT_DIR/default.nix"
NPM_DIR="$SCRIPT_DIR/npm"

version="${VERSION:-$(curl -fsSL https://registry.npmjs.org/vite-plus/latest | jq -r .version)}"
if [[ -z "$version" || "$version" == "null" ]]; then
  echo "error: could not resolve vite-plus version from npm registry" >&2
  exit 1
fi

echo "Updating viteplus to $version"

platforms=(
  linux-x64-gnu
  linux-arm64-gnu
  linux-x64-musl
  linux-arm64-musl
  darwin-x64
  darwin-arm64
)

hash_lines=""
for suffix in "${platforms[@]}"; do
  url="https://registry.npmjs.org/@voidzero-dev/vite-plus-cli-${suffix}/-/vite-plus-cli-${suffix}-${version}.tgz"
  echo "  prefetching $suffix"
  sha256=$(curl -fsSL "$url" | sha256sum | awk '{print $1}')
  sri=$(nix hash convert --to sri --hash-algo sha256 "$sha256")
  hash_lines+="        \"$suffix\" = \"$sri\";"$'\n'
done

cat >"$NPM_DIR/package.json" <<EOF
{
  "name": "viteplus-npm-deps",
  "version": "0.0.0",
  "dependencies": {
    "vite-plus": "$version"
  }
}
EOF

echo "  refreshing npm lockfile"
(
  cd "$NPM_DIR"
  export HOME="$TMPDIR"
  npm install --package-lock-only --ignore-scripts >/dev/null
)

echo "  prefetching npm deps"
npm_deps_hash=$(prefetch-npm-deps "$NPM_DIR/package-lock.json")

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

awk -v version="$version" -v hashes="$hash_lines" -v npm_deps_hash="$npm_deps_hash" '
  /^  version = / {
    print "  version = \"" version "\";"
    next
  }
  /# update-script: platform-hashes-begin/ {
    print
    printf "%s", hashes
    skip = 1
    next
  }
  skip && /# update-script: platform-hashes-end/ {
    print
    skip = 0
    next
  }
  /# update-script: npm-deps-hash/ {
    print
    getline
    print "    hash = \"" npm_deps_hash "\";"
    next
  }
  !skip { print }
' "$NIX_FILE" >"$tmp"

mv "$tmp" "$NIX_FILE"
trap - EXIT

echo "Updated $NIX_FILE"
echo "Updated $NPM_DIR/package.json and package-lock.json"
echo "npmDepsHash = $npm_deps_hash"
