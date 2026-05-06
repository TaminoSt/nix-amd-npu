{ lib
, python312
, fetchurl
, autoPatchelfHook
, stdenv
, zlib
, ncurses
, libxml2
, unzip
, makeWrapper
}:

let
  pname = "mlir-aie";
  version = "1.1.4";
  pythonVersion = "cp312";
  pythonSitePackages = python312.sitePackages;

  wheel = fetchurl {
    url = "https://github.com/Xilinx/mlir-aie/releases/download/v${version}/mlir_aie-${version}-${pythonVersion}-${pythonVersion}-manylinux_2_35_x86_64.whl";
    sha256 = "sha256-zjuN9QVPcVrMRgXrWkSZ3ewU+hG4USzgVV3Z6/uRQlU=";
  };
in
stdenv.mkDerivation {
  inherit pname version;

  src = wheel;

  nativeBuildInputs = [
    autoPatchelfHook
    python312
    unzip
    makeWrapper
  ];

  buildInputs = [
    stdenv.cc.cc.lib  # libstdc++
    zlib
    ncurses
    libxml2
  ];

  dontUnpack = true;

  # Expose Python modules to consuming Python environments.
  propagatedBuildInputs = [ python312 ];

  # The wheel contains native libraries that need patching
  autoPatchelfIgnoreMissingDeps = [
    "libllvm*"
    "libclang*"
    "libMLIR*"
  ];

  installPhase = ''
    runHook preInstall

    # Create the output directory structure
    mkdir -p $out/lib/${pythonSitePackages}

    # Unpack the wheel
    unzip -q $src -d $out/lib/${pythonSitePackages}/

    # Make everything writable
    chmod -R u+w $out

    # Ensure the wheel's extra python path is automatically loaded
    cat > $out/lib/${pythonSitePackages}/aie.pth <<EOF
$out/lib/${pythonSitePackages}/mlir_aie/python
EOF

    # Create bin directory with tools
    mkdir -p $out/bin
    for tool in $out/lib/${pythonSitePackages}/mlir_aie/bin/*; do
      if [ -x "$tool" ]; then
        makeWrapper "$tool" "$out/bin/$(basename "$tool")" \
          --prefix PYTHONPATH : "$out/lib/${pythonSitePackages}:$out/lib/${pythonSitePackages}/mlir_aie/python"
      fi
    done

    runHook postInstall
  '';

  meta = with lib; {
    description = "MLIR-based toolchain for AMD AI Engine";
    homepage = "https://github.com/Xilinx/mlir-aie";
    license = licenses.asl20;
    platforms = [ "x86_64-linux" ];
    # Note: The high-level IRON API requires eudsl-python-extras which
    # needs to be built from source with LLVM. Basic MLIR bindings work.
  };
}
