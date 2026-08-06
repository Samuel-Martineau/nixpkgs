{
  lib,
  stdenv,
  callPackage,
  cmake,
  ninja,
  substituteAll,
}:

# The LMDB key-value store, vendored by the DocC project as a C target. Used
# by swift-docc's index.

let
  sources = callPackage ../sources.nix { };
in
stdenv.mkDerivation {
  pname = "swift-lmdb";

  inherit (sources) version;
  src = sources.swift-lmdb;

  outputs = [
    "out"
    "dev"
  ];

  nativeBuildInputs = [
    cmake
    ninja
  ];

  # Like the rest of the DocC projects, this has no install rules: upstream
  # builds it inside a larger tree and refers to the build directory.
  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib $dev/include/CLMDB
    cp lib/libCLMDB.* $out/lib/
    cp $src/Sources/CLMDB/include/* $dev/include/CLMDB/

    [ -e $dev/include/CLMDB/module.modulemap ] \
      || { echo "error: the CLMDB module map was not installed" >&2; exit 1; }

    runHook postInstall
  '';

  postInstall = ''
    # Only exports its CMake package into the build tree.
    mkdir -p $dev/lib/cmake/LMDB
    substituteAll ${./glue.cmake} $dev/lib/cmake/LMDB/LMDBConfig.cmake
  '';

  meta = {
    description = "LMDB key-value store, as vendored by the Swift DocC project";
    homepage = "https://github.com/swiftlang/swift-lmdb";
    platforms = lib.platforms.linux;
    license = lib.licenses.asl20;
    teams = [ lib.teams.swift ];
  };
}
