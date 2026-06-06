{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  installShellFiles,
  makeWrapper,
  patchelf,
}:
let
  version = "0.1.24";

  platformSuffix =
    {
      x86_64-linux =
        if stdenv.hostPlatform.isMusl then
          "linux-x64-musl"
        else
          "linux-x64-gnu";
      aarch64-linux =
        if stdenv.hostPlatform.isMusl then
          "linux-arm64-musl"
        else
          "linux-arm64-gnu";
      x86_64-darwin = "darwin-x64";
      aarch64-darwin = "darwin-arm64";
    }
    .${stdenv.hostPlatform.system}
      or (throw "Unsupported system: ${stdenv.hostPlatform.system}");

in
stdenv.mkDerivation {
  pname = "viteplus";
  inherit version;

  src = fetchurl {
    url = "https://registry.npmjs.org/@voidzero-dev/vite-plus-cli-${platformSuffix}/-/vite-plus-cli-${platformSuffix}-${version}.tgz";
    hash =
      {
        # update-script: platform-hashes-begin
        "linux-x64-gnu" = "sha256-jKEIjFDqjjnYd3DJveQ1McJ0rAGMPoOWgEP9p7Sm9yg=";
        "linux-arm64-gnu" = "sha256-rjVyfgULhwFXzjaPqDiHForQoI8Y8/WGElwrrXNXvfI=";
        "linux-x64-musl" = "sha256-/o4uKI0ffmQMVBab/0CCmpt+EQj1SsBG9jApuCJhNT8=";
        "linux-arm64-musl" = "sha256-/LM9/jzITk6pZVq9pEFHQztkvk14ajvCRisbdC/BkaU=";
        "darwin-x64" = "sha256-wWHssU/vxrgd9erdu1LSslGhDkPKCoz/nZ2I3NOisnM=";
        "darwin-arm64" = "sha256-pnF8lM8plk0OXg5Zzq7XT1iJ53Md0Ao093bBbTdZ1wQ=";
        # update-script: platform-hashes-end
      }
      .${platformSuffix}
        or (throw "No prebuilt binary for platform suffix: ${platformSuffix}");
  };

  sourceRoot = "package";

  nativeBuildInputs = [
    installShellFiles
    makeWrapper
    patchelf
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [
    autoPatchelfHook
  ];

  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    stdenv.cc.cc.lib
  ];

  installPhase = ''
    runHook preInstall

    ${lib.optionalString stdenv.hostPlatform.isLinux ''
      patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" vp
    ''}
    install -Dm755 vp $out/bin/.vp-unwrapped
    makeWrapper $out/bin/.vp-unwrapped $out/bin/vp \
      --run '
        if [ -z "''${VITE_GLOBAL_CLI_JS_SCRIPTS_DIR:-}" ]; then
          __vp_home="''${VP_HOME:-$HOME/.vite-plus}"
          export VITE_GLOBAL_CLI_JS_SCRIPTS_DIR="$__vp_home/current/node_modules/vite-plus/dist"
        fi
      '

    runHook postInstall
  '';

  postInstall = ''
    ${lib.optionalString stdenv.hostPlatform.isLinux ''
      export LD_LIBRARY_PATH="${lib.makeLibraryPath [ stdenv.cc.cc.lib ]}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    ''}

    installShellCompletion --cmd vp \
      --bash <(VP_COMPLETE=bash $out/bin/vp) \
      --fish <(VP_COMPLETE=fish $out/bin/vp) \
      --zsh <(VP_COMPLETE=zsh $out/bin/vp)
  '';

  passthru.updateScript = ./update-viteplus.sh;

  meta = {
    description = "The unified toolchain and entry point for web development";
    homepage = "https://viteplus.dev";
    changelog = "https://github.com/voidzero-dev/vite-plus/releases/tag/v${version}";
    license = lib.licenses.mit;
    mainProgram = "vp";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
  };
}
