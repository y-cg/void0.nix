{
  description = "void0 toolchain overlay";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    # rolldown's rust-toolchain.toml is ahead of nixpkgs rustc. See pkgs/rolldown.nix.
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { nixpkgs, rust-overlay, ... }:
    let
      lib = nixpkgs.lib;
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = lib.genAttrs systems;

      overlay = final: _prev: {
        vitejs = final.callPackage ./pkgs/vitejs.nix { };
        oxlint = final.callPackage ./pkgs/oxlint.nix { };
        oxfmt = final.callPackage ./pkgs/oxfmt.nix { };
        rolldown = final.callPackage ./pkgs/rolldown.nix { };
        vp = final.callPackage ./pkgs/vp { };
      };

      # rust-overlay must be applied first so rolldown can take rust-bin from pkgs.
      composedOverlay = lib.composeManyExtensions [
        rust-overlay.overlays.default
        overlay
      ];
    in
    {
      overlays.default = composedOverlay;
      overlays.void0 = composedOverlay;

      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ composedOverlay ];
          };
        in
        {
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
        }
      );

      # nix develop  →  nix-update --flake <attr>
      devShells = forAllSystems (system: {
        default = (import nixpkgs { inherit system; }).mkShell {
          packages = [ (import nixpkgs { inherit system; }).nix-update ];
        };
      });
    };
}
