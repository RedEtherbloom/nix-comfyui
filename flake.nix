{
  description = "ComfyUI as a Nix expression";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils = {
      url = "github:numtide/flake-utils";
      inputs.systems.follows = "systems";
    };
    systems.url = "github:nix-systems/default";
    poetry2nix = {
      url = "github:nix-community/poetry2nix";
      inputs = {
        flake-utils.follows = "flake-utils";
        nixpkgs.follows = "nixpkgs";
        systems.follows = "systems";
      };
    };
  };

  outputs = {
    flake-utils,
    nixpkgs,
    poetry2nix,
    self,
    ...
  } @ inputs: let
    mkComfyuiPackages = pkgs:
      pkgs.callPackage ./scope.nix {
        poetry2nix = poetry2nix.lib.mkPoetry2Nix {inherit pkgs;};
      };
  in
    {
      lib = {
        inherit mkComfyuiPackages;
      };

      overlays.default = _: prev: {
        comfyuiPackages = mkComfyuiPackages prev;
      };
    }
    // flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = import nixpkgs {
          inherit system;
          config = {
            allowUnfree = true;
          };
        };

        comfyuiPackages = mkComfyuiPackages pkgs;

        mkPackageEntry = path: {
          name = builtins.concatStringsSep "-" path;
          value = pkgs.lib.getAttrFromPath path comfyuiPackages;
        };

        packages = builtins.listToAttrs (pkgs.lib.flatten (
          (map
            (name: mkPackageEntry [name])
            ["krita-with-extensions"])
          ++ (map
            (
              platform: (map
                (name: mkPackageEntry [platform name])
                ["comfyui" "comfyui-with-extensions"])
            )
            ["cuda" "rocm"])
        ));
      in {
        formatter = pkgs.nixpkgs-fmt;

        devShells.default = pkgs.mkShell {
          name = "default";
          buildInputs = [
            pkgs.bash
            pkgs.coreutils
            pkgs.findutils
            pkgs.git
            pkgs.just
            pkgs.nix-prefetch-git
            pkgs.nixpkgs-fmt
            pkgs.prefetch-npm-deps
            pkgs.yapf
            (pkgs.python3.withPackages (p: [p.nix-prefetch-github]))
          ];
        };

        inherit packages;

        checks =
          packages
          // {
            nix-comfyui-sources =
              pkgs.runCommand "nix-comfyui-sources"
              {
                nativeBuildInputs = [
                  pkgs.just
                  pkgs.nixpkgs-fmt
                  pkgs.yapf
                ];
              }
              ''
                cd ${./.}
                just check-fmt
                touch $out
              '';

            cuda-run-check-pkgs = comfyuiPackages.cuda.run-check-pkgs;
            rocm-run-check-pkgs = comfyuiPackages.rocm.run-check-pkgs;
          };

        legacyPackages = comfyuiPackages;
      }
    );
}
