{ inputs, ... }:
{
  perSystem =
    {
      config,
      pkgs,
      system,
      ...
    }:
    let
      inherit (pkgs)
        unilog
        xir
        target-factory
        vart
        trace-logging
        graph-engine
        xaiengine
        dynamic-dispatch
        ;

      xrt = pkgs.callPackage ../pkgs/xrt { };

      xrt-plugin-amdxdna = pkgs.callPackage ../pkgs/xrt-plugin-amdxdna {
        inherit xrt;
      };

      xrt-amdxdna = pkgs.callPackage ../pkgs/xrt-amdxdna {
        inherit xrt xrt-plugin-amdxdna;
      };

      # Firmware and kernel driver (local packages, not yet in nixpkgs)
      amdxdna-driver = pkgs.callPackage ../pkgs/amdxdna-driver {
        kernel = pkgs.linuxPackages_6_18.kernel;
      };

      amdxdna-firmware = pkgs.callPackage ../pkgs/amdxdna-firmware { };

      # ONNX Runtime with VitisAI EP (C++ library) - not yet in nixpkgs
      onnxruntime-vitisai = pkgs.callPackage ../pkgs/onnxruntime-vitisai { };

      # Python bindings for ONNX Runtime with VitisAI EP
      python-onnxruntime-vitisai = pkgs.callPackage ../pkgs/python-onnxruntime-vitisai {
        inherit onnxruntime-vitisai;
      };

      # AMD pre-built components (unfree, requires manual download)
      ryzen-ai-software = pkgs.callPackage ../pkgs/ryzen-ai-software { };

      ryzen-ai-xclbin = pkgs.callPackage ../pkgs/ryzen-ai-xclbin { };

      # MLIR-AIE for NPU kernel development
      mlir-aie = pkgs.callPackage ../pkgs/mlir-aie { };

      # Whisper-IRON speech recognition demo
      whisper-iron = pkgs.callPackage ../pkgs/whisper-iron {
        inherit mlir-aie;
      };

      # FastFlowLM NPU-optimized LLM runtime
      fastflowlm = pkgs.callPackage ../pkgs/fastflowlm { };

      # Complete Ryzen AI stack (combines from-source + pre-built)
      ryzen-ai-full = pkgs.callPackage ../pkgs/ryzen-ai-full {
        inherit onnxruntime-vitisai;
      };
    in
    {
      packages = {
        # Free/open-source packages (built from source)
        inherit
          amdxdna-driver
          amdxdna-firmware
          xrt
          xrt-plugin-amdxdna
          xrt-amdxdna
          unilog
          xir
          target-factory
          vart
          trace-logging
          graph-engine
          xaiengine
          dynamic-dispatch
          onnxruntime-vitisai
          python-onnxruntime-vitisai
          mlir-aie
          whisper-iron
          fastflowlm
          ;
        default = xrt-amdxdna;
      };

      # Unfree packages available via legacyPackages (requires NIXPKGS_ALLOW_UNFREE=1)
      legacyPackages = {
        inherit ryzen-ai-software ryzen-ai-xclbin ryzen-ai-full;
      };

      # Integration tests - run with `nix flake check`
      checks = {
        # Verify XRT builds and has expected binaries
        xrt-binaries = pkgs.runCommand "check-xrt-binaries" { } ''
          echo "Checking XRT binaries..."
          test -x ${xrt}/bin/unwrapped/xrt-smi || (echo "FAIL: xrt-smi not found" && exit 1)
          test -x ${xrt}/bin/unwrapped/xclbinutil || (echo "FAIL: xclbinutil not found" && exit 1)
          echo "PASS: XRT binaries present"
          touch $out
        '';

        # Verify plugin library exists and has correct soname
        plugin-library = pkgs.runCommand "check-plugin-library" { } ''
          echo "Checking plugin library..."
          pluginLib="${xrt-plugin-amdxdna}/opt/xilinx/xrt/lib"
          test -f "$pluginLib/libxrt_driver_xdna.so.2" || (echo "FAIL: plugin .so.2 not found" && exit 1)
          test -f "$pluginLib/libxrt_driver_xdna.so.${xrt-plugin-amdxdna.pluginVersion}" || (echo "FAIL: plugin .so.${xrt-plugin-amdxdna.pluginVersion} not found" && exit 1)
          echo "PASS: Plugin library present with correct versions"
          touch $out
        '';

        # Verify combined package has plugin discoverable by XRT
        plugin-discovery = pkgs.runCommand "check-plugin-discovery" { } ''
          echo "Checking plugin discovery in combined package..."
          xrtLib="${xrt-amdxdna}/opt/xilinx/xrt/lib"
          test -L "$xrtLib/libxrt_driver_xdna.so.2" || (echo "FAIL: plugin symlink not in combined package" && exit 1)
          # Verify symlink resolves correctly
          readlink -f "$xrtLib/libxrt_driver_xdna.so.2" > /dev/null || (echo "FAIL: plugin symlink broken" && exit 1)
          echo "PASS: Plugin discoverable in combined package"
          touch $out
        '';

        # Verify pkg-config files are generated
        pkg-config-files = pkgs.runCommand "check-pkg-config" { } ''
          echo "Checking pkg-config files..."
          test -f ${xrt}/lib/pkgconfig/xrt.pc || (echo "FAIL: xrt.pc not found" && exit 1)
          test -f ${xrt-plugin-amdxdna}/lib/pkgconfig/xrt-amdxdna.pc || (echo "FAIL: xrt-amdxdna.pc not found" && exit 1)
          echo "PASS: pkg-config files present"
          touch $out
        '';

        # Verify environment setup works
        environment-setup = pkgs.runCommand "check-environment" { } ''
          echo "Checking environment setup..."
          export XILINX_XRT="${xrt-amdxdna}/opt/xilinx/xrt"
          test -d "$XILINX_XRT" || (echo "FAIL: XILINX_XRT directory doesn't exist" && exit 1)
          test -d "$XILINX_XRT/lib" || (echo "FAIL: XRT lib directory doesn't exist" && exit 1)
          test -d "$XILINX_XRT/bin" || (echo "FAIL: XRT bin directory doesn't exist" && exit 1)
          echo "PASS: Environment directories valid"
          touch $out
        '';
      };
    };
}
