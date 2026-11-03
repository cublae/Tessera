{
  description = "Tessera — a desktop shell for niri and Hyprland, built on Quickshell";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      forAllSystems =
        f:
        nixpkgs.lib.genAttrs systems (
          system:
          f {
            inherit system;
            pkgs = nixpkgs.legacyPackages.${system};
          }
        );
    in
    {
      packages = forAllSystems (
        { pkgs, ... }:
        let
          tessera = pkgs.callPackage ./nix/package.nix { };
        in
        {
          inherit tessera;
          default = tessera;
        }
      );

      devShells = forAllSystems (
        { pkgs, ... }:
        {
          default = pkgs.mkShell {
            name = "tessera-dev";

            packages = [
              pkgs.quickshell
              # qmllint and qmlformat, for checking the shell without running it
              pkgs.kdePackages.qtdeclarative
            ];

            shellHook = ''
              echo "Tessera dev shell"
              echo "  TESSERA_DEV=1 ./nix/tessera.sh   — run the shell against this checkout"
            '';
          };
        }
      );

      homeManagerModules = {
        tessera = import ./modules/home-manager.nix self;
        default = self.homeManagerModules.tessera;
      };

      overlays.default = final: prev: {
        tessera = final.callPackage ./nix/package.nix { };
      };

      formatter = forAllSystems ({ pkgs, ... }: pkgs.nixfmt-rfc-style);
    };
}
