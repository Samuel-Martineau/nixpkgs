{
  lib,
  stdenv,
  callPackage,
  cmake,
  ninja,
  substituteAll,
  swift-unwrapped,
  swiftSearchFlags,
  swift-lmdb,
  Foundation,
  Dispatch,
}:

# The index database sourcekit-lsp queries for cross-references and symbol
# definitions.

let
  sources = callPackage ../sources.nix { };
  inherit (swift-unwrapped) swiftOs;
in
stdenv.mkDerivation {
  pname = "indexstore-db";

  inherit (sources) version;
  src = sources.indexstore-db;

  outputs = [
    "out"
    "dev"
  ];

  nativeBuildInputs = [
    cmake
    ninja
  ];

  buildInputs = [
    swift-lmdb
    Foundation
    Dispatch
  ];

  cmakeFlags = [
    (lib.cmakeFeature "CMAKE_Swift_COMPILER" "${swift-unwrapped}/bin/swiftc")
    (lib.cmakeFeature "dispatch_DIR" "${lib.getDev Dispatch}/lib/cmake/dispatch")
    (lib.cmakeFeature "Foundation_DIR" "${lib.getDev Foundation}/lib/cmake/Foundation")
    (lib.cmakeFeature "LMDB_DIR" "${lib.getDev swift-lmdb}/lib/cmake/LMDB")
    (lib.cmakeBool "BUILD_SHARED_LIBS" true)
  ];

  preConfigure = ''
    cmakeFlagsArray+=("-DCMAKE_Swift_FLAGS=${swiftSearchFlags}")
  '';

  postInstall = ''
    # The C API's headers are what sourcekit-lsp imports the module through,
    # and they are not installed.
    # Dereference on copy: one of these headers is a symlink into a sibling
    # source directory, which would dangle once out of the source tree.
    mkdir -p $dev/include
    cp -rL $src/Sources/IndexStoreDB_CIndexStoreDB/include/* $dev/include/

    # Only exports its CMake package into the build tree.
    mkdir -p $dev/lib/cmake/IndexStoreDB
    export dylibExt="${stdenv.hostPlatform.extensions.sharedLibrary}"
    export swiftOs="${swiftOs}"
    substituteAll ${./glue.cmake} $dev/lib/cmake/IndexStoreDB/IndexStoreDBConfig.cmake
  '';

  meta = {
    description = "Index database for Swift and C-family languages";
    homepage = "https://github.com/swiftlang/indexstore-db";
    platforms = lib.platforms.linux;
    license = lib.licenses.asl20;
    teams = [ lib.teams.swift ];
  };
}
