{
  lib,
  stdenv,
  fetchPnpmDeps,
  pnpmConfigHook,
  pnpm_10,
  nodejs_22,
  makeBinaryWrapper,
  autoPatchelfHook,
}:
# ==============================================================================
# Vite+ (`vp`) — the unified web toolchain CLI
# ==============================================================================
#
# Unlike the other packages in this flake, `vp` is not built from source. The
# upstream `curl -fsSL https://vite.plus | bash` installer downloads a native
# launcher binary and then shells out to pnpm at runtime to materialise a JS
# dependency tree under `~/.vite-plus`. That whole flow — runtime downloads,
# writes to a mutable home dir, a built-in Node version manager — fights Nix at
# every step.
#
# What makes a clean derivation possible is that the launcher is *optional*: the
# published `vite-plus` npm package already ships a plain Node entrypoint
# (`bin/vp` → `dist/bin.js`) plus a napi native addon pulled in as a
# platform-specific optional dependency (`@voidzero-dev/vite-plus-<platform>`).
# Run that entrypoint against a normal `node_modules` and you get the full CLI —
# no launcher, no `~/.vite-plus`, no version manager. So we package it exactly
# like any other pnpm-based tool: fetch the dependency tree offline, then wrap
# the JS entrypoint with a pinned Node.
#
# We deliberately do NOT package the native launcher or vp's Node version
# management (`vp env`): Node is provided by Nix.
#
# ------------------------------------------------------------------------------
# Cross-platform note
# ------------------------------------------------------------------------------
# `vite-plus` pulls its native addon (and a long tail of other native addons:
# lightningcss, rolldown, oxlint, oxfmt, …) as platform-specific *optional*
# dependencies. By default `pnpmConfigHook` sets npm_config_arch/platform to the
# build platform, so `fetchPnpmDeps` would download only the current platform's
# addons — giving a different FOD hash on every system.
#
# Instead we pin `pnpm.supportedArchitectures` in ./package.json to darwin+linux
# on x64+arm64. pnpm then resolves the *same* set of optional addons regardless
# of which host runs the fetch (verified: a darwin build fetches the linux addons
# too), so a single `pnpmDeps.hash` is valid on all platforms — no per-system
# hashes, no CI round-trip to learn the Linux hashes. The cost is a fatter
# closure: every system ships all these addons (only its own is ever loaded).
# That is a deliberate trade — hash simplicity over closure size.
#
# The resolved set is darwin-{arm64,x64} + linux-{arm64,x64}-{gnu,musl} (six
# variants per native dep); pnpm pulls both libc flavours here regardless of the
# `libc` field, so musl Linux comes along for free. win32/android are excluded.
#
# On Linux the addons are prebuilt ELF `.node` files, so we run autoPatchelfHook
# to fix their interpreter/RPATH; darwin's Mach-O addons need no such step (and
# autoPatchelf skips the foreign-arch addons it cannot patch).
stdenv.mkDerivation (finalAttrs: {
  pname = "vp";
  version = "0.2.6";

  # `src` is a tiny pnpm project (./package.json + ./pnpm-lock.yaml + ./.npmrc)
  # that pins `vite-plus@<version>`. pnpm fetches the CLI and its entire
  # dependency tree — including the matching native addon — from the npm
  # registry. There is no first-party source tree to build.
  src = ./.;

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    pnpm = pnpm_10;
    fetcherVersion = 3;
    # One hash for every platform: `supportedArchitectures` in ./package.json
    # fixes the fetched optional-addon set, so this is host-independent.
    hash = "sha256-U/rC1uDkaXUyhMt6JQwavhY7tUm1oZJCNBcUe7pRxTQ=";
  };

  nativeBuildInputs = [
    pnpmConfigHook
    pnpm_10
    nodejs_22
    makeBinaryWrapper
  ]
  # The native addons ship as prebuilt ELF on Linux and need their
  # interpreter/RPATH patched to the Nix store; darwin Mach-O addons do not.
  ++ lib.optionals stdenv.isLinux [ autoPatchelfHook ];

  # autoPatchelfHook resolves the addons' DT_NEEDED (libstdc++/libgcc_s) against
  # this. Empty on darwin.
  buildInputs = lib.optionals stdenv.isLinux [ stdenv.cc.cc.lib ];

  # pnpmConfigHook installs `node_modules` during configurePhase; there is
  # nothing to compile.
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    # Ship the dependency tree verbatim. The `.npmrc` pins `node-linker=hoisted`
    # so this is a flat, relocatable directory with no symlinks into a virtual
    # store — safe to drop into the read-only /nix/store.
    local -r pkgRoot="$out/lib/vp"
    mkdir -p "$pkgRoot"
    cp -r node_modules "$pkgRoot/node_modules"

    # Make `vp create` work from a read-only store. It scaffolds projects by
    # copying bundled templates with fs.copyFileSync, which preserves the source
    # mode — and every file under /nix/store is read-only (0444). The generated
    # files would therefore be read-only too, and the immediately-following step
    # that rewrites the new package.json fails with EACCES. Restore owner-write
    # on each copied file (upstream re-applies the executable bit where needed).
    substituteInPlace "$pkgRoot/node_modules/vite-plus/dist/create/bin.js" \
      --replace-fail \
        'else fs.copyFileSync(src, dest);' \
        'else { fs.copyFileSync(src, dest); fs.chmodSync(dest, fs.statSync(src).mode | 0o200); }'

    # `bin/vp` is `#!/usr/bin/env node` importing `../dist/bin.js`; resolution of
    # the native addon and tool packages is relative to this file, so it must run
    # from inside the shipped tree. The wrapper also puts our Node on PATH for any
    # child processes vp spawns (dev server, test runner, …), and $out/bin so vp's
    # post-scaffold self-invocation (`spawn('vp', ['install'])`) resolves even when
    # vp was launched by absolute path rather than from PATH.
    mkdir -p "$out/bin"
    makeBinaryWrapper "${lib.getExe nodejs_22}" "$out/bin/vp" \
      --add-flags "$pkgRoot/node_modules/vite-plus/bin/vp" \
      --prefix PATH : "${lib.makeBinPath [ nodejs_22 ]}" \
      --prefix PATH : "$out/bin"

    runHook postInstall
  '';

  meta = {
    description = "Vite+ — the unified toolchain CLI for the web";
    homepage = "https://viteplus.dev";
    license = lib.licenses.mit;
    mainProgram = "vp";
    platforms = [
      "aarch64-darwin"
      "x86_64-darwin"
      "x86_64-linux"
      "aarch64-linux"
    ];
  };

  # `nix-update` discovers upstream versions from `src.url` / `src.urls`, which
  # only fetchers like `fetchFromGitHub` expose. Our `src` is a local pnpm
  # project (./.), so the URL probe has nothing to read. Declare the existing
  # three-step updater here; `nix-update --flake vp` will invoke it instead of
  # raising "Could not find a url in the derivations src attribute".
  passthru.updateScript = [ ./update.sh ];
})
