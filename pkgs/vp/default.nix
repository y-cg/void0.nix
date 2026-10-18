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
# Published `vite-plus` (`bin/vp`), not the native launcher or `vp env`.
# `supportedArchitectures` in package.json fixes the optional-addon set, so one
# pnpmDeps hash is valid on every host. Linux ELF addons need autoPatchelfHook.
stdenv.mkDerivation (finalAttrs: {
  pname = "vp";
  version = "1.3.0";

  src = ./.;

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    pnpm = pnpm_10;
    fetcherVersion = 3;
    hash = "sha256-o4bM9t0MVu9Yw9jj27/cFnXp4hBjvB1G+M8oFZw/Wts=";
  };

  nativeBuildInputs = [
    pnpmConfigHook
    pnpm_10
    nodejs_22
    makeBinaryWrapper
  ]
  ++ lib.optionals stdenv.isLinux [ autoPatchelfHook ];

  buildInputs = lib.optionals stdenv.isLinux [ stdenv.cc.cc.lib ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    local -r pkgRoot="$out/lib/vp"
    mkdir -p "$pkgRoot"
    cp -r node_modules "$pkgRoot/node_modules"

    # copyFileSync keeps the store mode (0444); the following package.json write needs owner-write.
    substituteInPlace "$pkgRoot/node_modules/vite-plus/dist/create/bin.js" \
      --replace-fail \
        'else fs.copyFileSync(src, dest);' \
        'else { fs.copyFileSync(src, dest); fs.chmodSync(dest, fs.statSync(src).mode | 0o200); }'

    # `vpr` is the argv0 alias for `vp run`. $out/bin covers `spawn('vp', ['install'])`.
    mkdir -p "$out/bin"
    for bin in vp vpr; do
      makeBinaryWrapper "${lib.getExe nodejs_22}" "$out/bin/$bin" \
        --add-flags "$pkgRoot/node_modules/vite-plus/bin/$bin" \
        --prefix PATH : "${lib.makeBinPath [ nodejs_22 ]}" \
        --prefix PATH : "$out/bin"
    done

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

  # `src` is `./.`, so nix-update cannot discover a URL.
  passthru.updateScript = [ ./update.sh ];
})
