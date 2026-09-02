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
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "oxfmt";
  version = "0.66.0";

  src = fetchFromGitHub {
    owner = "oxc-project";
    repo = "oxc";
    tag = "oxfmt_v${finalAttrs.version}";
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

  env.OXC_VERSION = finalAttrs.version;

  buildPhase = ''
    runHook preBuild
    pnpm --filter oxfmt-app run build
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    local outPath=$out/lib/oxfmt
    mkdir -p $outPath $out/bin
    find -name 'node_modules' -type d -exec rm -rf {} \; || true
    pnpm --filter oxfmt-app install --offline --prod --ignore-scripts
    cp -r apps/oxfmt/dist $outPath/
    cp -rL apps/oxfmt/node_modules $outPath/
    cp npm/oxfmt/configuration_schema.json $outPath/
    makeWrapper ${lib.getExe nodejs-slim} $out/bin/oxfmt \
      --add-flags $outPath/dist/cli.js
    runHook postInstall
  '';

  meta = {
    description = "High-performance formatter for the JavaScript ecosystem";
    homepage = "https://oxc.rs/docs/guide/usage/formatter";
    changelog = "https://github.com/oxc-project/oxc/blob/oxfmt_v${finalAttrs.version}/apps/oxfmt/CHANGELOG.md";
    license = lib.licenses.mit;
    mainProgram = "oxfmt";
    inherit (nodejs-slim.meta) platforms;
  };
})
