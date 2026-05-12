{
  description = "AMD Ryzen AI NPU support for NixOS (XRT + XDNA driver)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs =
    inputs@{ flake-parts, nixpkgs, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" ];

      imports = [
        ./parts/packages.nix
        ./parts/devshell.nix
        ./parts/nixos-module.nix
      ];

      # Overlay adds packages not yet in nixpkgs fork
      flake.overlays.default = final: prev: {

        xrt = final.callPackage ./pkgs/xrt { };

        xrt-plugin-amdxdna = final.callPackage ./pkgs/xrt-plugin-amdxdna {
          inherit (final) xrt;
        };

        xrt-amdxdna = final.callPackage ./pkgs/xrt-amdxdna {
          inherit (final) xrt xrt-plugin-amdxdna;
        };

        # Firmware and kernel driver (not yet in nixpkgs)
        amdxdna-firmware = final.callPackage ./pkgs/amdxdna-firmware { };

        # MLIR-AIE for NPU kernel development (not yet in nixpkgs)
        mlir-aie = final.callPackage ./pkgs/mlir-aie { };

      };

      perSystem =
        { system, ... }:
        {
          _module.args.pkgs = import nixpkgs {
            inherit system;
            # Note: XRT is Apache-2.0 licensed, no unfree components required
          };
        };
    };
}
