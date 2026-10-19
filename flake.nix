{
  description = "void0 toolchain overlay";

  inputs = {
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.1.*.tar.gz";

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      # Share our nixpkgs lib instead of pulling a second copy.
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{ flake-parts, nixpkgs, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      flake =
        let
          overlay = final: _prev: {
            vitejs = final.callPackage ./pkgs/vitejs.nix { };
            oxlint = final.callPackage ./pkgs/oxlint.nix { };
            oxfmt = final.callPackage ./pkgs/oxfmt.nix { };
            rolldown = final.callPackage ./pkgs/rolldown.nix { };
            vp = final.callPackage ./pkgs/vp { };
          };
        in
        {
          overlays.default = overlay;
          overlays.void0 = overlay;
        };

      perSystem =
        { system, ... }:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ inputs.self.overlays.default ];
          };
        in
        {
          packages = {
            inherit (pkgs)
              vitejs
              oxlint
              oxfmt
              rolldown
              vp
              ;

            # nix profile install .#default
            default = pkgs.buildEnv {
              name = "void0-toolchain";
              paths = with pkgs; [
                vitejs
                oxlint
                oxfmt
                rolldown
                vp
              ];
            };
          };

          devShells.default = pkgs.mkShell {
            packages = [ pkgs.nix-update ];
          };
        };
    };
}
