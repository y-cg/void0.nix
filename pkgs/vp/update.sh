#!/usr/bin/env bash
# ==============================================================================
# vp updater
# ==============================================================================
#
# Bumps the pinned `vite-plus` release and refreshes everything that pin touches.
# Standard `nix-update` cannot drive this package: a version bump needs three
# linked steps, and nix-update only does the last one.
#
#   1. rewrite the pinned version   (package.json + default.nix)
#   2. regenerate the pnpm lockfile (the dependency tree changes between releases,
#      so a stale lockfile fails the build's --frozen-lockfile install)
#   3. refresh the pnpmDeps FOD hash
#
# Thanks to `pnpm.supportedArchitectures` in package.json the fetched addon set —
# and therefore the hash — is the same on every platform, so this script fully
# completes the update on a single machine (no per-platform / CI round-trip).
#
# Node/pnpm are always taken from nixpkgs: the host's Node 26 + pnpm crashes in
# libuv (kqueue) during install, so we pin Node 22 via `nix shell`.
#
# Usage:
#   ./pkgs/vp/update.sh            # bump to the latest npm release
#   ./pkgs/vp/update.sh 0.3.0      # bump to an explicit version
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"
pkg_json="$script_dir/package.json"
nix_file="$script_dir/default.nix"

# All-zero placeholder that forces `nix build` to report the real FOD hash.
fake_hash="sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="

# ------------------------------------------------------------------------------
# 1. Resolve the target version
# ------------------------------------------------------------------------------
# Hit the registry directly with curl: the user's ~/.npmrc `min-release-age`
# policy is an npm/pnpm client filter and never affects a raw HTTP request, so we
# always see the true latest.
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

# ------------------------------------------------------------------------------
# 2. Rewrite the pinned version
# ------------------------------------------------------------------------------
# package.json: only the vite-plus dependency pin (jq preserves the rest,
# including the pnpm.supportedArchitectures block).
tmp="$(mktemp)"
jq --indent 2 --arg v "$target" '.dependencies["vite-plus"] = $v' "$pkg_json" >"$tmp"
mv "$tmp" "$pkg_json"

# default.nix: the derivation's own `version = "...";`.
sed -i.bak -E "s/(version = \")[^\"]+(\";)/\1$target\2/" "$nix_file" && rm -f "$nix_file.bak"

# ------------------------------------------------------------------------------
# 3. Regenerate the lockfile
# ------------------------------------------------------------------------------
# --lockfile-only: resolve and write pnpm-lock.yaml without materialising
# node_modules. The cwd .npmrc pins min-release-age=0 so a just-published release
# is not hidden from the resolver.
echo "vp: regenerating pnpm-lock.yaml with Node 22 + pnpm 10 from nixpkgs"
( cd "$script_dir" && nix shell nixpkgs#nodejs_22 nixpkgs#pnpm_10 \
    --command pnpm install --lockfile-only --no-frozen-lockfile )

# ------------------------------------------------------------------------------
# 4. Refresh the pnpmDeps hash
# ------------------------------------------------------------------------------
# Set the hash to the placeholder, let the FOD fetch fail, and read back the
# `got:` value. flake builds only see git-tracked files, so stage first.
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

# ------------------------------------------------------------------------------
# 5. Verify
# ------------------------------------------------------------------------------
echo "vp: verifying build with the new hash"
nix build "$repo_root#vp" -L
echo "vp: updated $current -> $target (single hash valid on all platforms)"
