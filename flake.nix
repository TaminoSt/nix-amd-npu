{
  description = "AMD Ryzen AI NPU support for NixOS (XRT + XDNA driver)";

  inputs = {
    # Use fork with vitis-ai branch containing xrt, xrt-plugin-amdxdna, and NixOS module
    nixpkgs.url = "github:z4m1n0/nixpkgs/vitis-ai";
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
      # XRT and Vitis AI packages now come from nixpkgs fork (vitis-ai branch)
      flake.overlays.default = final: prev: {
        # Firmware and kernel driver (not yet in nixpkgs)
        amdxdna-firmware = final.callPackage ./pkgs/amdxdna-firmware { };

        # ONNX Runtime with VitisAI EP (not yet in nixpkgs)
        onnxruntime-vitisai = final.callPackage ./pkgs/onnxruntime-vitisai { };

        # MLIR-AIE for NPU kernel development (not yet in nixpkgs)
        mlir-aie = final.callPackage ./pkgs/mlir-aie { };

        # Whisper-IRON speech recognition (not yet in nixpkgs)
        whisper-iron = final.callPackage ./pkgs/whisper-iron {
          inherit (final) mlir-aie;
        };

        # FastFlowLM NPU-optimized LLM runtime (not yet in nixpkgs)
        fastflowlm = final.callPackage ./pkgs/fastflowlm { };
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
