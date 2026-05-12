{ inputs, ... }:
{
  perSystem =
    { config, pkgs, ... }:
    let
      xrt = config.packages.xrt;
      xrt-amdxdna = config.packages.xrt-amdxdna;
      mlir-aie = config.packages.mlir-aie;

      # Shared NPU detection script for all shells
      npuDetectionScript = ''
        # Check for NPU hardware
        _check_npu() {
          if [ -e /dev/accel/accel0 ]; then
            echo -e "\033[32m[OK]\033[0m NPU device found at /dev/accel/accel0"
            if [ -r /dev/accel/accel0 ]; then
              echo -e "\033[32m[OK]\033[0m NPU device is readable"
            else
              echo -e "\033[33m[WARN]\033[0m NPU device not readable - check group membership"
              echo "       Add yourself to the 'video' group: sudo usermod -aG video $USER"
            fi
          else
            echo -e "\033[33m[WARN]\033[0m NPU device not found at /dev/accel/accel0"
            echo "       - Ensure kernel 6.10+ is running (current: $(uname -r))"
            echo "       - Check if amdxdna module is loaded: lsmod | grep amdxdna"
            echo "       - Verify IOMMU is enabled: dmesg | grep -i iommu"
          fi
        }
      '';
    in
    {
      devShells = {
        # Basic XRT development shell
        default = pkgs.mkShell {
          packages = [
            xrt-amdxdna
          ];

          shellHook = ''
            ${npuDetectionScript}

            echo "=============================================="
            echo "  AMD Ryzen AI NPU Development Environment"
            echo "=============================================="
            echo "XRT version: ${xrt.version}"
            echo ""
            export XILINX_XRT="${xrt-amdxdna}/opt/xilinx/xrt"
            export LD_LIBRARY_PATH="${xrt-amdxdna}/opt/xilinx/xrt/lib:''${LD_LIBRARY_PATH:-}"

            echo "NPU Status:"
            _check_npu
            echo ""
            echo "Commands:"
            echo "  xrt-smi examine    - Show NPU hardware details"
            echo "  xrt-smi validate   - Run NPU validation tests"
            echo ""
          '';
        };

        # Note: ryzen-ai-full shell requires unfree packages
        # Use: NIXPKGS_ALLOW_UNFREE=1 nix develop .#ryzen-ai-full --impure

        # MLIR-AIE / IRON development shell for custom NPU kernels
        iron = pkgs.mkShell {
          packages = [
            xrt-amdxdna
            mlir-aie
            (pkgs.python312.withPackages (
              ps: with ps; [
                numpy
                scipy
                pytest
                # Audio/ML deps
                librosa
                soundfile
                transformers
                torch
                # For MLIR-AIE
                pybind11
                ml-dtypes
              ]
            ))
            pkgs.cmake
            pkgs.ninja
            pkgs.clang
            pkgs.lld
            pkgs.xorg.libXrender
            pkgs.xorg.libXtst
            pkgs.xorg.libXi
          ];

          shellHook = ''
            ${npuDetectionScript}

            echo "=============================================="
            echo "  AMD Ryzen AI NPU - MLIR-AIE / IRON Dev"
            echo "=============================================="
            echo "XRT version: ${xrt.version}"
            echo "MLIR-AIE version: ${mlir-aie.version}"
            echo ""

            export XILINX_XRT="${xrt-amdxdna}/opt/xilinx/xrt"
            export LD_LIBRARY_PATH="${xrt-amdxdna}/opt/xilinx/xrt/lib:''${LD_LIBRARY_PATH:-}"

            # Add mlir-aie site-packages (for aie.pth to work)
            export PYTHONPATH="${mlir-aie}/lib/python3.12/site-packages:${mlir-aie}/lib/python3.12/site-packages/mlir_aie/python:''${PYTHONPATH:-}"

            # Add mlir-aie binaries to PATH
            export PATH="${mlir-aie}/lib/python3.12/site-packages/mlir_aie/bin:''${PATH:-}"

            echo "NPU Status:"
            _check_npu
            echo ""
          '';
        };

        # Full IRON development shell using FHS environment for pip compatibility
        # This allows installing eudsl-python-extras from source
        iron-full =
          let
            # Use XDG_CACHE_HOME for venv to avoid polluting project directory
            venvDir = "\${XDG_CACHE_HOME:-$HOME/.cache}/nix-amd-npu/venv-iron";
            fhsEnv = pkgs.buildFHSEnv {
              name = "iron-fhs";
              targetPkgs = pkgs: [
                xrt-amdxdna
                mlir-aie
                pkgs.python312
                pkgs.python312Packages.pip
                pkgs.python312Packages.virtualenv
                # Toolchain dependencies
                pkgs.cmake
                pkgs.ninja
                pkgs.clang
                pkgs.lld
                pkgs.git
                # Runtime dependencies
                pkgs.zlib
                pkgs.ncurses
                pkgs.libxml2
                pkgs.stdenv.cc.cc.lib
                pkgs.util-linux.dev
              ];
              runScript = "bash";
              profile = ''
                export XILINX_XRT="${xrt-amdxdna}/opt/xilinx/xrt"
                export LD_LIBRARY_PATH="${xrt-amdxdna}/opt/xilinx/xrt/lib:''${LD_LIBRARY_PATH:-}"

                # Add mlir-aie and XRT python modules
                export PYTHONPATH="${xrt-amdxdna}/opt/xilinx/xrt/python:$(paste -sd: ${mlir-aie}/nix-support/python-path):''${PYTHONPATH:-}"

                # Add mlir-aie binaries to PATH
                export PATH="${mlir-aie}/bin:''${PATH:-}"

                # Create virtualenv in cache directory if it doesn't exist
                VENV_DIR="${venvDir}"
                mkdir -p "$(dirname "$VENV_DIR")"
                if [ ! -d "$VENV_DIR" ]; then
                  echo "Creating Python virtual environment at $VENV_DIR..."
                  python3 -m venv "$VENV_DIR"
                fi
                source "$VENV_DIR/bin/activate"

                # Set PEANO_INSTALL_DIR to the llvm-aie package installed in the venv.
                # Use a glob so this works regardless of the Python minor version.
                for _peano_candidate in "$VENV_DIR"/lib/python*/site-packages/llvm-aie; do
                  if [ -x "$_peano_candidate/bin/clang++" ]; then
                    export PEANO_INSTALL_DIR="$_peano_candidate"
                    break
                  fi
                done
                unset _peano_candidate

                # Detect NPU generation; mirrors env_setup.sh logic.
                # NPU2=1 → npu2/aie2p target (Strix, Strix Halo, Krackan, npu4/5/6)
                # NPU2=0 → npu/aie2 target (Phoenix, npu1)
                _NPUPAT='NPU Strix|NPU Strix Halo|NPU Krackan|RyzenAI-npu[456]'
                if xrt-smi examine 2>/dev/null | tr -d '\r' | grep -qE "$_NPUPAT"; then
                  export NPU2=1
                else
                  export NPU2=0
                fi
                unset _NPUPAT

                # Set MLIR_AIE_INSTALL_DIR to the mlir_aie package root.
                export MLIR_AIE_INSTALL_DIR="${mlir-aie}/lib/lib/python3.12/site-packages/mlir_aie"

                # Add mlir-aie bundled runtime libs (mirrors env_setup.sh).
                export LD_LIBRARY_PATH="${mlir-aie}/lib/lib/python3.12/site-packages/mlir_aie.libs:''${LD_LIBRARY_PATH:-}"

                # Automatic first-time setup for IRON Python deps
                SETUP_STAMP="$VENV_DIR/.iron-setup-complete"
                if [ ! -f "$SETUP_STAMP" ]; then
                  echo "Running first-time IRON setup in $VENV_DIR..."
                  pip install numpy==1.26.4 aiofiles cloudpickle ml_dtypes rich
                  pip install llvm-aie -f https://github.com/Xilinx/llvm-aie/releases/expanded_assets/nightly
                  pip install eudsl-python-extras -f https://llvm.github.io/eudsl
                  if python -c 'import pyxrt; from aie.iron import ObjectFifo' >/dev/null 2>&1; then
                    touch "$SETUP_STAMP"
                  else
                    echo "IRON setup validation failed." >&2
                    return 1
                  fi
                fi

                echo "Activated virtualenv: $VENV_DIR"
              '';
            };
          in
          pkgs.mkShell {
            packages = [ fhsEnv ];
            shellHook = ''
              ${npuDetectionScript}

              echo "=============================================="
              echo "  AMD Ryzen AI NPU - Full IRON Dev (FHS)"
              echo "=============================================="
              echo ""
              echo "NPU Status:"
              _check_npu
              echo ""
              echo "Run 'iron-fhs' to enter the FHS environment, test:"
              echo "  python -c 'import pyxrt; from aie.iron import ObjectFifo; print(\"IRON works!\")'"
              echo ""
            '';
          };
      };
    };
}
