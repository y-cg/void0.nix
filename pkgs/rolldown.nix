{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchPnpmDeps,
  pnpmConfigHook,
  pnpm_10,
  nodejs_22,
  rustPlatform,
  cargo,
  rustc,
  cmake,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "rolldown";
  version = "1.1.1";

  src = fetchFromGitHub {
    owner = "rolldown";
    repo = "rolldown";
    tag = "v${finalAttrs.version}";
    hash = "sha256-6UijakWelvABxLMxcfd6OEaUeijqPTXP4HguARJAXGo=";
  };

  cargoDeps = rustPlatform.fetchCargoVendor {
    inherit (finalAttrs) pname version src;
    hash = "sha256-Tm6Mt1HC8UmOoGhxFZhxE/IcrD3UVN37RPu2Mn6/SZc=";
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    pnpm = pnpm_10;
    fetcherVersion = 3;
    hash = "sha256-wLgdvR+WxcFXQoOi0cntXnMUXfpOPmjJv6rYWUGJsXA=";
  };

  dontUseCmakeConfigure = true;

  nativeBuildInputs = [
    pnpmConfigHook
    pnpm_10
    nodejs_22
    rustPlatform.cargoSetupHook
    cargo
    rustc
    cmake
  ];

  buildPhase = ''
    runHook preBuild
    pnpm run --filter "@rolldown/pluginutils" build
    pnpm run --filter rolldown build-native:release
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    local -r nodeModules="$out/lib/node_modules"
    mkdir -p "$nodeModules"

    local -r outPath="$nodeModules/rolldown"
    mkdir -p "$outPath"
    cp packages/rolldown/package.json "$outPath/"
    for d in bin cli dist; do
      [[ -d packages/rolldown/$d ]] && cp -r "packages/rolldown/$d" "$outPath/"
    done
    cp packages/rolldown/*.node "$outPath/" 2>/dev/null || true
    cp packages/rolldown/dist/*.node "$outPath/dist/" 2>/dev/null || true
    cp packages/rolldown/dist/*.mjs "$outPath/dist/" 2>/dev/null || true

    mkdir -p "$nodeModules/@rolldown/pluginutils"
    cp packages/pluginutils/package.json "$nodeModules/@rolldown/pluginutils/"
    [[ -d packages/pluginutils/dist ]] && cp -r packages/pluginutils/dist "$nodeModules/@rolldown/pluginutils/"

    mkdir -p "$out/bin"
    ln -s "$out/lib/node_modules/rolldown/bin/cli.mjs" "$out/bin/rolldown"

    runHook postInstall
  '';

  meta = {
    description = "Fast Rust-based bundler for JavaScript";
    homepage = "https://rolldown.rs";
    changelog = "https://github.com/rolldown/rolldown/blob/v${finalAttrs.version}/CHANGELOG.md";
    license = lib.licenses.mit;
    inherit (nodejs_22.meta) platforms;
  };
})
