{
  lib,
  stdenv,
  callPackage,
  cmake,
  ninja,
  substituteAll,
  swift-unwrapped,
  swiftSearchFlags,
  swift-argument-parser,
  swift-asn1,
  swift-cmark,
  swift-crypto,
  swift-docc-symbolkit,
  swift-lmdb,
  swift-markdown,
  corelibsCmakeFlags,
  Foundation,
  Dispatch,
}:

# The documentation compiler for Swift.

let
  sources = callPackage ../sources.nix { };
  inherit (swift-unwrapped) swiftOs swiftArch;

  moduleDirs = [
    "${swift-argument-parser}/lib/swift/${swiftOs}"
    "${swift-asn1}/lib/swift/${swiftOs}/${swiftArch}"
    "${swift-crypto}/lib/swift/${swiftOs}/${swiftArch}"
    "${swift-docc-symbolkit}/lib/swift/${swiftOs}"
    "${swift-markdown}/lib/swift/${swiftOs}"
  ];

  libraryDirs = [
    "${swift-argument-parser}/lib"
    "${swift-asn1}/lib/swift/${swiftOs}"
    "${swift-crypto}/lib/swift/${swiftOs}"
    "${swift-docc-symbolkit}/lib"
    "${swift-lmdb}/lib"
    "${swift-markdown}/lib"
  ];

  clangModuleDirs = [
    "${lib.getDev swift-markdown}/include/CAtomic"
    "${lib.getDev swift-lmdb}/include/CLMDB"
  ];
in
stdenv.mkDerivation {
  pname = "swift-docc";

  inherit (sources) version;
  src = sources.swift-docc;

  nativeBuildInputs = [
    cmake
    ninja
  ];

  buildInputs = [
    swift-argument-parser
    swift-asn1
    swift-cmark
    swift-crypto
    swift-docc-symbolkit
    swift-lmdb
    swift-markdown
    Foundation
    Dispatch
  ];

  cmakeFlags = [
    (lib.cmakeFeature "CMAKE_Swift_COMPILER" "${swift-unwrapped}/bin/swiftc")
  ]
  ++ corelibsCmakeFlags
  ++ [
    (lib.cmakeFeature "ArgumentParser_DIR" "${lib.getDev swift-argument-parser}/lib/cmake/ArgumentParser")
    (lib.cmakeFeature "SwiftASN1_DIR" "${lib.getDev swift-asn1}/lib/cmake/SwiftASN1")
    (lib.cmakeFeature "SwiftCrypto_DIR" "${lib.getDev swift-crypto}/lib/cmake/SwiftCrypto")
    (lib.cmakeFeature "SwiftMarkdown_DIR" "${lib.getDev swift-markdown}/lib/cmake/SwiftMarkdown")
    (lib.cmakeFeature "LMDB_DIR" "${lib.getDev swift-lmdb}/lib/cmake/LMDB")
    (lib.cmakeFeature "SymbolKit_DIR" "${lib.getDev swift-docc-symbolkit}/lib/cmake/SymbolKit")
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

  # Only the docc executable is installed, but sourcekit-lsp imports this
  # project's libraries to serve documentation, so they and their modules have
  # to be placed by hand.
  postInstall = ''
    mkdir -p $out/lib $out/lib/swift/${swiftOs}
    cp lib/*.a $out/lib/
    cp swift/*.swiftmodule swift/*.swiftdoc $out/lib/swift/${swiftOs}/

    for expected in SwiftDocC DocCCommon; do
      [ -e "$out/lib/swift/${swiftOs}/$expected.swiftmodule" ] \
        || { echo "error: the $expected module was not installed" >&2; exit 1; }
    done

    # Only exports its CMake package into the build tree.
    mkdir -p $out/lib/cmake/SwiftDocC
    export swiftOs="${swiftOs}"
    substituteAll ${./glue.cmake} $out/lib/cmake/SwiftDocC/SwiftDocCConfig.cmake
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

    # docc takes no --version, so exercise it through its help output.
    $out/bin/docc --help > /dev/null
  '';

  meta = {
    description = "Documentation compiler for Swift";
    homepage = "https://github.com/swiftlang/swift-docc";
    mainProgram = "docc";
    platforms = lib.platforms.linux;
    license = lib.licenses.asl20;
    teams = [ lib.teams.swift ];
  };
}
