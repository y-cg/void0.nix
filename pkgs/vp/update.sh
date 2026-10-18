#!/usr/bin/env bash
# Bump the vite-plus pin, regenerate pnpm-lock.yaml, refresh pnpmDeps.hash.
# Node 22 comes from nixpkgs; host Node 26 crashes in libuv during install.
#   ./pkgs/vp/update.sh [version]
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"
pkg_json="$script_dir/package.json"
nix_file="$script_dir/default.nix"

# Placeholder so the fixed-output fetch prints the real hash.
fake_hash="sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="

# curl bypasses ~/.npmrc min-release-age.
current="$(grep -oE '"vite-plus": "[^"]+"' "$pkg_json" | cut -d'"' -f4)"
if [[ $# -ge 1 ]]; then
  target="$1"
else
  target="$(curl -fsSL https://registry.npmjs.org/vite-plus/latest | jq -r .version)"
fi

echo "vp: current=$current target=$target"
if [[ "$current" == "$target" ]]; then
  echo "vp: already at $target, nothing to do"
  exit 0
fi

tmp="$(mktemp)"
jq --indent 2 --arg v "$target" '.version = $v | .dependencies["vite-plus"] = $v' "$pkg_json" >"$tmp"
mv "$tmp" "$pkg_json"

sed -i.bak -E "s/(version = \")[^\"]+(\";)/\1$target\2/" "$nix_file" && rm -f "$nix_file.bak"

echo "vp: regenerating pnpm-lock.yaml with Node 22 + pnpm 10 from nixpkgs"
( cd "$script_dir" && nix shell nixpkgs#nodejs_22 nixpkgs#pnpm_10 \
    --command pnpm install --lockfile-only --no-frozen-lockfile )

# Flake builds only see tracked files, so stage before the hash fetch.
sed -i.bak -E "s|(hash = \")sha256-[^\"]+(\";)|\1$fake_hash\2|" "$nix_file" && rm -f "$nix_file.bak"
git -C "$repo_root" add pkgs/vp

echo "vp: building to capture the new FOD hash"
got="$(nix build "$repo_root#vp" -L 2>&1 | grep -oE 'got: +sha256-[A-Za-z0-9+/=]+' | awk '{print $2}' || true)"
if [[ -z "$got" ]]; then
  echo "vp: ERROR could not parse the FOD hash. Either the build already" >&2
  echo "    succeeded with the placeholder (unexpected) or it failed for" >&2
  echo "    another reason. Re-run 'nix build $repo_root#vp -L' to inspect." >&2
  exit 1
fi

sed -i.bak -E "s|(hash = \")sha256-[^\"]+(\";)|\1$got\2|" "$nix_file" && rm -f "$nix_file.bak"
git -C "$repo_root" add pkgs/vp
echo "vp: hash = $got"

echo "vp: verifying build with the new hash"
nix build "$repo_root#vp" -L
echo "vp: updated $current -> $target"
