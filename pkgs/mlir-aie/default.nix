{ lib
, python312
, python312Packages
, fetchurl
, autoPatchelfHook
, stdenv
, zlib
, ncurses
, libxml2
, makeWrapper
}:

let
  pname = "mlir-aie";
  version = "1.1.4";
  pythonSitePackages = python312.sitePackages;
in
python312Packages.buildPythonPackage {
  inherit pname version;
  format = "wheel";

  src = fetchurl {
    url = "https://github.com/Xilinx/mlir-aie/releases/download/v${version}/mlir_aie-${version}-cp312-cp312-manylinux_2_35_x86_64.whl";
    sha256 = "sha256-zjuN9QVPcVrMRgXrWkSZ3ewU+hG4USzgVV3Z6/uRQlU=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = [
    stdenv.cc.cc.lib  # libstdc++
    zlib
    ncurses
    libxml2
  ];

  # The wheel bundles LLVM/MLIR/Clang libraries; autoPatchelf cannot resolve
  # them from the Nix store, so we allow them to remain unpatched.
  autoPatchelfIgnoreMissingDeps = [
    "libllvm*"
    "libclang*"
    "libMLIR*"
  ];

  postInstall = ''
    sp=$out/${pythonSitePackages}

    # Expose aie/ at the top level of site-packages so that
    # 'import aie' works both via PYTHONPATH and python.withPackages.
    if [ -d "$sp/mlir_aie/python/aie" ]; then
      ln -s "$sp/mlir_aie/python/aie" "$sp/aie"
    fi

    # Also install a .pth file pointing at mlir_aie/python so that any
    # code inside that sub-directory (e.g. aie.backend, aie.compiler)
    # that imports neighbouring packages by absolute name still resolves
    # correctly when the caller adds site-packages to sys.path manually.
    echo "$sp/mlir_aie/python" > "$sp/mlir_aie_python.pth"

    # Wrap the binary tools bundled inside the wheel with a PYTHONPATH
    # that covers both site-packages roots.
    if [ -d "$sp/mlir_aie/bin" ]; then
      mkdir -p $out/bin
      for tool in "$sp/mlir_aie/bin"/*; do
        if [ -x "$tool" ]; then
          makeWrapper "$tool" "$out/bin/$(basename "$tool")" \
            --prefix PYTHONPATH : "$sp:$sp/mlir_aie/python"
        fi
      done
    fi
  '';

  # pythonImportsCheck is intentionally omitted: aie.ir loads bundled
  # LLVM/MLIR shared libraries whose RPATHs cannot be resolved inside the
  # Nix build sandbox.  The import is verified at the flake-check level
  # (parts/packages.nix mlir-aie-python-layout check).

  meta = with lib; {
    description = "MLIR-based toolchain for AMD AI Engine";
    homepage = "https://github.com/Xilinx/mlir-aie";
    license = licenses.asl20;
    platforms = [ "x86_64-linux" ];
    # Note: The high-level IRON API requires eudsl-python-extras which
    # needs to be built from source with LLVM. Basic MLIR bindings work.
  };
}
