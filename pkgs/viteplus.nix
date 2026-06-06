{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  installShellFiles,
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
        "linux-x64-gnu" = "sha256-jKEIjFDqjjnYd3DJveQ1McJ0rAGMPoOWgEP9p7Sm9yg=";
        "linux-arm64-gnu" = "sha256-rjVyfgULhwFXzjaPqDiHForQoI8Y8_WGElwrrXNXvfI=";
        "linux-x64-musl" = "sha256-_o4uKI0ffmQMVBab_0CCmpt-EQj1SsBG9jApuCJhNT8=";
        "linux-arm64-musl" = "sha256-_LM9_jzITk6pZVq9pEFHQztkvk14ajvCRisbdC_BkaU=";
        "darwin-x64" = "sha256-wWHssU_vxrgd9erdu1LSslGhDkPKCoz_nZ2I3NOisnM=";
        "darwin-arm64" = "sha256-pnF8lM8plk0OXg5Ztq7XT1iJ53Md0Ao093bBbTdZ1wQ=";
      }
      .${platformSuffix}
        or (throw "No prebuilt binary for platform suffix: ${platformSuffix}");
  };

  sourceRoot = "package";

  nativeBuildInputs = [
    installShellFiles
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

    install -Dm755 vp $out/bin/vp

    runHook postInstall
  '';

  postInstall = ''
    # Patch the interpreter before generating completions (autoPatchelf runs later).
    ${lib.optionalString stdenv.hostPlatform.isLinux ''
      patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" $out/bin/vp
      export LD_LIBRARY_PATH="${lib.makeLibraryPath [ stdenv.cc.cc.lib ]}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    ''}

    installShellCompletion --cmd vp \
      --bash <(VP_COMPLETE=bash $out/bin/vp) \
      --fish <(VP_COMPLETE=fish $out/bin/vp) \
      --zsh <(VP_COMPLETE=zsh $out/bin/vp)
  '';

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
