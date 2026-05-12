# Centralized version management for nix-amd-npu packages
#
# This file contains all version information and source hashes.
# Update versions here when upgrading packages.
#
# ============================================================================
# VERSION COMPATIBILITY MATRIX
# ============================================================================
#
# CRITICAL: XRT and XDNA driver versions MUST match exactly!
#   - XRT version format: MAJOR.MINOR.PATCH (e.g., 2.21.75)
#   - XDNA driver uses same version scheme
#   - Mismatched versions will cause runtime failures
#
# Component Dependencies:
#   ┌─────────────────┐
#   │   Applications  │  user apps
#   ├─────────────────┤
#   │   MLIR-AIE      │  v1.1.4 (requires Python 3.12, cp312 wheel)
#   ├─────────────────┤
#   │  XRT + XDNA     │  Must be same version (2.21.75)
#   ├─────────────────┤
#   │  Linux Kernel   │  6.10+ required, 6.14+ has mainline amdxdna
#   └─────────────────┘
#
# Supported Hardware:
#   - AMD Ryzen AI 300 Series (Strix Point) - PHX/HPT
#   - AMD Ryzen 8040 Series (Hawk Point)
#   - AMD Ryzen AI Max (Krackan Point)
#
# ============================================================================
{
  # ==========================================================================
  # XRT (Xilinx Runtime) and XDNA Driver
  # IMPORTANT: These two versions MUST match! Update both together.
  # ==========================================================================
  xrt = {
    version = "2.21.75";
    src = {
      owner = "Xilinx";
      repo = "XRT";
      rev = "2.21.75";
      hash = "sha256-Foj33/U6waL81EzJ0ah66xCXEGWEkvhwmurKobfCevE=";
    };
  };

  xdna-driver = {
    version = "2.21.75"; # MUST match xrt.version above!
    pluginVersion = "2.21.75"; # Shared library version (libxrt_driver_xdna.so.2.21.0)
    src = {
      owner = "amd";
      repo = "xdna-driver";
      rev = "2.21.75";
      hash = "sha256-s06LKWwQNmWlmQSe+XNUOaVclnw1tAJPCFQvgDp/wCY=";
    };
  };

  # MLIR-AIE / IRON
  mlir-aie = {
    version = "1.1.4";
    wheel = {
      url = "https://github.com/Xilinx/mlir-aie/releases/download/v1.1.4/mlir_aie-1.1.4-cp312-cp312-manylinux_2_27_x86_64.manylinux_2_28_x86_64.whl";
      hash = "sha256-kzFJxYjE6xxkefBXRTxjMeSsA2oJz9gvVn5L12OHPOI=";
    };
  };
}
