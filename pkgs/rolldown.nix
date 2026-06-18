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
  makeBinaryWrapper,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "rolldown";
  version = "1.1.2";

  src = fetchFromGitHub {
    owner = "rolldown";
    repo = "rolldown";
    tag = "v${finalAttrs.version}";
    hash = "sha256-1bA1K4LXeT91IplS8yjDPSWMU7zqA8Bs7qtxuQMxxPQ=";
  };

  cargoDeps = rustPlatform.fetchCargoVendor {
    inherit (finalAttrs) pname version src;
    hash = "sha256-iCdjD1i0DcCM54Byo0rFJQtWcUTIbNQKX12u2083mTU=";
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    pnpm = pnpm_10;
    fetcherVersion = 3;
    hash = "sha256-lKqPo4vsY9RXpVvXJtQ564Rfs9r2pu4r91+NXSOdLOE=";
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
    makeBinaryWrapper
  ];

  buildPhase = ''
    runHook preBuild
    pnpm run --filter rolldown build-native:release
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    local -r pkgRoot="$out/lib/rolldown"
    mkdir -p "$pkgRoot/bin"

    cp packages/rolldown/package.json "$pkgRoot/"
    cp -r packages/rolldown/bin/. "$pkgRoot/bin/"
    cp -r packages/rolldown/dist "$pkgRoot/"
    cp packages/rolldown/*.node "$pkgRoot/" 2>/dev/null || true

    # runtime dep of dist/*.mjs (marked external by upstream build, same as npm install)
    mkdir -p "$pkgRoot/node_modules/@rolldown"
    cp -rL packages/rolldown/node_modules/@rolldown/pluginutils "$pkgRoot/node_modules/@rolldown/"

    mkdir -p "$out/bin"
    makeBinaryWrapper "${lib.getExe nodejs_22}" "$out/bin/rolldown" \
      --add-flags "$pkgRoot/bin/cli.mjs"

    runHook postInstall
  '';

  meta = {
    description = "Fast Rust-based bundler for JavaScript";
    homepage = "https://rolldown.rs";
    changelog = "https://github.com/rolldown/rolldown/blob/v${finalAttrs.version}/CHANGELOG.md";
    license = lib.licenses.mit;
    mainProgram = "rolldown";
    inherit (nodejs_22.meta) platforms;
  };
})
