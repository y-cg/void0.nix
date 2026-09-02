{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchPnpmDeps,
  pnpmConfigHook,
  pnpm_10,
  nodejs_24,
  nodejs-slim,
  rustPlatform,
  cargo,
  rustc,
  cmake,
  makeBinaryWrapper,
  rust-jemalloc-sys,
  tsgolint,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "oxlint";
  version = "1.81.0";

  src = fetchFromGitHub {
    owner = "oxc-project";
    repo = "oxc";
    tag = "oxlint_v${finalAttrs.version}";
    hash = "sha256-+dWIpUPV0NrDajNXOCHuL+q4RmqjPowjzIbrdI+mBTc=";
  };

  cargoDeps = rustPlatform.fetchCargoVendor {
    inherit (finalAttrs) pname version src;
    hash = "sha256-dCZqFCSMgnU9Kyjxkoqxq2BiTwu82d1HFeFSyFavj38=";
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    pnpm = pnpm_10;
    fetcherVersion = 3;
    hash = "sha256-ASy5rnh201o9DJBNJvL92gWumhKINWj6X5b1JwJ0Mt4=";
  };

  dontUseCmakeConfigure = true;

  nativeBuildInputs = [
    cargo
    cmake
    makeBinaryWrapper
    nodejs_24
    pnpmConfigHook
    pnpm_10
    rustPlatform.cargoSetupHook
    rustc
  ];

  buildInputs = [ rust-jemalloc-sys ];

  env.OXC_VERSION = finalAttrs.version;

  buildPhase = ''
    runHook preBuild
    pnpm --workspace-concurrency=1 --filter oxlint-app run build
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    local -r packageRoot="$out/lib/oxlint"
    mkdir -p "$packageRoot/bin"
    cp npm/oxlint/configuration_schema.json "$packageRoot/"
    cp npm/oxlint/bin/oxlint "$packageRoot/bin/oxlint"
    cp -r apps/oxlint/dist "$packageRoot/dist"
    chmod +x "$packageRoot/bin/oxlint"
    makeBinaryWrapper "${lib.getExe nodejs-slim}" "$out/bin/oxlint" \
      --add-flags "$packageRoot/bin/oxlint" \
      --prefix PATH : "${lib.makeBinPath [ tsgolint ]}"
    runHook postInstall
  '';

  meta = {
    description = "JavaScript linter built in Rust";
    homepage = "https://oxc.rs/docs/guide/usage/linter";
    changelog = "https://github.com/oxc-project/oxc/releases/tag/oxlint_v${finalAttrs.version}";
    license = lib.licenses.mit;
    mainProgram = "oxlint";
    inherit (nodejs-slim.meta) platforms;
  };
})
