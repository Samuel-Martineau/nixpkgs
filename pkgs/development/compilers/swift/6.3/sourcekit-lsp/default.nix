{
  lib,
  stdenv,
  callPackage,
  cmake,
  ninja,
  swift-unwrapped,
  swiftSearchFlags,
  swift-argument-parser,
  swift-asn1,
  swift-cmark,
  swift-collections,
  swift-crypto,
  swift-docc-symbolkit,
  swift-llbuild,
  swift-lmdb,
  swift-markdown,
  swift-syntax,
  swift-tools-protocols,
  swift-tools-support-core,
  swiftpm,
  indexstore-db,
  Foundation,
  Dispatch,
}:

# The language server for Swift and C-family languages.

let
  sources = callPackage ../sources.nix { };
  inherit (swift-unwrapped) swiftOs swiftArch;

  moduleDirs = [
    "${swift-argument-parser}/lib/swift/${swiftOs}"
    "${swift-asn1}/lib/swift/${swiftOs}/${swiftArch}"
    "${swift-collections}/lib/swift_static/${swiftOs}"
    "${swift-crypto}/lib/swift/${swiftOs}/${swiftArch}"
    "${swift-docc-symbolkit}/lib/swift/${swiftOs}"
    "${swift-llbuild}/lib/swift/pm/llbuild"
    "${swift-markdown}/lib/swift/${swiftOs}"
    "${swift-syntax}/lib/swift/host"
    "${swift-tools-protocols}/lib/swift/${swiftOs}"
    "${swift-tools-support-core}/lib/swift/${swiftOs}"
    "${swiftpm}/lib/swift/${swiftOs}"
    "${indexstore-db}/lib/swift/${swiftOs}"
  ];

  libraryDirs = [
    "${swift-argument-parser}/lib"
    "${swift-asn1}/lib/swift/${swiftOs}"
    "${swift-collections}/lib/swift_static/${swiftOs}"
    "${swift-crypto}/lib/swift/${swiftOs}"
    "${swift-docc-symbolkit}/lib"
    "${swift-llbuild}/lib"
    "${swift-llbuild}/lib/swift/pm/llbuild"
    "${swift-lmdb}/lib"
    "${swift-markdown}/lib"
    "${swift-syntax}/lib/swift/host"
    "${swift-tools-protocols}/lib"
    "${swift-tools-support-core}/lib"
    "${swiftpm}/lib"
    "${indexstore-db}/lib/swift/${swiftOs}"
  ];

  clangModuleDirs = [
    "${lib.getDev swift-tools-support-core}/include/TSCclibc"
    "${swift-llbuild}/include"
    "${lib.getDev swift-tools-protocols}/include/ToolsProtocolsCAtomics"
    "${lib.getDev swift-syntax}/include/_SwiftSyntaxCShims"
    "${lib.getDev swift-markdown}/include/CAtomic"
    "${lib.getDev swift-lmdb}/include/CLMDB"
  ];
in
stdenv.mkDerivation {
  pname = "sourcekit-lsp";

  inherit (sources) version;
  src = sources.sourcekit-lsp;

  nativeBuildInputs = [
    cmake
    ninja
  ];

  buildInputs = [
    swift-argument-parser
    swift-asn1
    swift-cmark
    swift-collections
    swift-crypto
    swift-docc-symbolkit
    swift-llbuild
    swift-lmdb
    swift-markdown
    swift-syntax
    swift-tools-protocols
    swift-tools-support-core
    swiftpm
    indexstore-db
    Foundation
    Dispatch
  ];

  cmakeFlags = [
    (lib.cmakeFeature "CMAKE_Swift_COMPILER" "${swift-unwrapped}/bin/swiftc")
    (lib.cmakeFeature "dispatch_DIR" "${lib.getDev Dispatch}/lib/cmake/dispatch")
    (lib.cmakeFeature "Foundation_DIR" "${lib.getDev Foundation}/lib/cmake/Foundation")
    (lib.cmakeFeature "ArgumentParser_DIR" "${lib.getDev swift-argument-parser}/lib/cmake/ArgumentParser")
    (lib.cmakeFeature "SwiftASN1_DIR" "${lib.getDev swift-asn1}/lib/cmake/SwiftASN1")
    (lib.cmakeFeature "SwiftCollections_DIR" "${lib.getDev swift-collections}/lib/cmake/SwiftCollections")
    (lib.cmakeFeature "SwiftCrypto_DIR" "${lib.getDev swift-crypto}/lib/cmake/SwiftCrypto")
    (lib.cmakeFeature "SwiftMarkdown_DIR" "${lib.getDev swift-markdown}/lib/cmake/SwiftMarkdown")
    (lib.cmakeFeature "SwiftSyntax_DIR" "${lib.getDev swift-syntax}/lib/cmake/SwiftSyntax")
    (lib.cmakeFeature "SymbolKit_DIR" "${lib.getDev swift-docc-symbolkit}/lib/cmake/SymbolKit")
    (lib.cmakeFeature "SwiftToolsProtocols_DIR" "${lib.getDev swift-tools-protocols}/lib/cmake/SwiftToolsProtocols")
    (lib.cmakeFeature "TSC_DIR" "${lib.getDev swift-tools-support-core}/lib/cmake/TSC")
    (lib.cmakeFeature "LLBuild_DIR" "${swift-llbuild}/lib/cmake/llbuild")
    (lib.cmakeFeature "LMDB_DIR" "${lib.getDev swift-lmdb}/lib/cmake/LMDB")
    (lib.cmakeFeature "IndexStoreDB_DIR" "${lib.getDev indexstore-db}/lib/cmake/IndexStoreDB")
    (lib.cmakeFeature "SwiftPM_DIR" "${swiftpm}/lib/cmake/SwiftPM")
    (lib.cmakeFeature "cmark-gfm_DIR" "${swift-cmark}/lib/cmake")
  ];

  preConfigure = ''
    cmakeFlagsArray+=(
      "-DCMAKE_Swift_FLAGS=${swiftSearchFlags} ${
        lib.concatMapStringsSep " " (dir: "-I ${dir}") moduleDirs
      } ${lib.concatMapStringsSep " " (dir: "-L ${dir}") libraryDirs} ${
        lib.concatMapStringsSep " " (
          dir: "-Xcc -fmodule-map-file=${dir}/module.modulemap -Xcc -I${dir}"
        ) clangModuleDirs
      }"
    )
  '';

  postFixup = ''
    rpath="${lib.getLib swift-unwrapped}/lib/swift/${swiftOs}"
    rpath="$rpath:${Foundation}/lib/swift/${swiftOs}:${Dispatch}/lib/swift/${swiftOs}"
    rpath="$rpath:${lib.concatStringsSep ":" libraryDirs}:${swift-cmark}/lib"

    for binary in $out/bin/* $out/lib/*.so; do
      [ -f "$binary" ] || continue
      patchelf --print-rpath "$binary" >/dev/null 2>&1 || continue
      patchelf --add-rpath "$rpath" "$binary"
    done

    $out/bin/sourcekit-lsp --help > /dev/null
  '';

  meta = {
    description = "Language Server Protocol implementation for Swift and C-family languages";
    homepage = "https://github.com/swiftlang/sourcekit-lsp";
    mainProgram = "sourcekit-lsp";
    platforms = lib.platforms.linux;
    license = lib.licenses.asl20;
    teams = [ lib.teams.swift ];
  };
}
