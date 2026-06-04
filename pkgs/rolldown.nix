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
  version = "1.0.0";

  src = fetchFromGitHub {
    owner = "rolldown";
    repo = "rolldown";
    tag = "v${finalAttrs.version}";
    hash = lib.fakeHash;
  };

  cargoDeps = rustPlatform.fetchCargoVendor {
    inherit (finalAttrs) pname version src;
    hash = lib.fakeHash;
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    pnpm = pnpm_10;
    fetcherVersion = 3;
    hash = lib.fakeHash;
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

    mkdir -p "$nodeModules/@rolldown/pluginutils"
    cp packages/pluginutils/package.json "$nodeModules/@rolldown/pluginutils/"
    [[ -d packages/pluginutils/dist ]] && cp -r packages/pluginutils/dist "$nodeModules/@rolldown/pluginutils/"

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
