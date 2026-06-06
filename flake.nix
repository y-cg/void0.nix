{
  description = "void0 toolchain overlay";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
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
        viteplus = final.callPackage ./pkgs/viteplus.nix { };
      };
    in
    {
      overlays.default = overlay;
      overlays.void0 = overlay;

      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ overlay ];
          };
        in
        {
          inherit (pkgs)
            vitejs
            oxlint
            oxfmt
            rolldown
            viteplus
            ;

          # nix profile install .#default
          default = pkgs.buildEnv {
            name = "void0-toolchain";
            paths = with pkgs; [
              vitejs
              oxlint
              oxfmt
              rolldown
              viteplus
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
