{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchPnpmDeps,
  pnpmConfigHook,
  pnpm_10,
  nodejs_24,
  makeWrapper,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "vitejs";
  version = "8.2.2";

  src = fetchFromGitHub {
    owner = "vitejs";
    repo = "vite";
    rev = "v${finalAttrs.version}";
    hash = "sha256-29ZluZSReOPhYGNSIR8SDq6euSrLRC8ctwF80oy28EY=";
  };

  pnpmWorkspaces = [ "vite" ];
  # Pin the fetcher's pnpm to match the lockfile (v9.0 → pnpm 10). Without
  # this, fetchPnpmDeps auto-selects the newest pnpm (11.x), which on macOS
  # leaks file descriptors and gets SIGKILLed during the post-install state
  # flush (see warnings about "File descriptor X opened in unmanaged mode").
  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs)
      pname
      version
      src
      pnpmWorkspaces
      ;
    pnpm = pnpm_10;
    fetcherVersion = 3;
    hash = "sha256-O1GZqsKyKSDq2AoshoNcSkAYLtFg06TBplERBy+JY8g=";
  };

  nativeBuildInputs = [
    makeWrapper
    nodejs_24
    pnpmConfigHook
    pnpm_10
  ];

  buildPhase = ''
    runHook preBuild
    pnpm --filter=vite build
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/{bin,lib/vite}
    cp -r {packages,node_modules} $out/lib/vite
    makeWrapper ${lib.getExe nodejs_24} $out/bin/vite \
      --inherit-argv0 \
      --add-flags $out/lib/vite/packages/vite/bin/vite.js
    runHook postInstall
  '';

  meta = {
    description = "Frontend tooling for NodeJS";
    homepage = "https://vitejs.dev";
    changelog = "https://github.com/vitejs/vite/blob/v${finalAttrs.version}/packages/vite/CHANGELOG.md";
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
    mainProgram = "vite";
  };
})
