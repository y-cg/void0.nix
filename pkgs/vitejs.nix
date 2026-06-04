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
  version = "8.0.16";

  src = fetchFromGitHub {
    owner = "vitejs";
    repo = "vite";
    rev = "v${finalAttrs.version}";
    hash = "sha256-seQ3MYiVMypWC0+Om87XSP4qI1s6Agazq//mQJbf0jA=";
  };

  pnpmWorkspaces = [ "vite" ];
  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src pnpmWorkspaces;
    fetcherVersion = 3;
    hash = "sha256-GjtaDM4B8DhGizjUTCRnZe1idzM4iRQ32e+AK/RsAWI=";
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
