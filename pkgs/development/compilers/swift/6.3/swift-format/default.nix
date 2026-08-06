{
  lib,
  stdenv,
  callPackage,
  cmake,
  ninja,
  swift-unwrapped,
  swiftSearchFlags,
  swift-argument-parser,
  swift-cmark,
  swift-markdown,
  swift-syntax,
  corelibsCmakeFlags,
  Foundation,
  Dispatch,
}:

# The formatter for Swift source code.

let
  sources = callPackage ../sources.nix { };
  inherit (swift-unwrapped) swiftOs;

  moduleDirs = [
    "${swift-argument-parser}/lib/swift/${swiftOs}"
    "${swift-markdown}/lib/swift/${swiftOs}"
    "${swift-syntax}/lib/swift/host"
  ];

  libraryDirs = [
    "${swift-argument-parser}/lib"
    "${swift-markdown}/lib"
    "${swift-syntax}/lib/swift/host"
  ];
in
stdenv.mkDerivation {
  pname = "swift-format";

  inherit (sources) version;
  src = sources.swift-format;

  nativeBuildInputs = [
    cmake
    ninja
  ];

  buildInputs = [
    swift-argument-parser
    swift-cmark
    swift-markdown
    swift-syntax
    Foundation
    Dispatch
  ];

  cmakeFlags = [
    (lib.cmakeFeature "CMAKE_Swift_COMPILER" "${swift-unwrapped}/bin/swiftc")
  ]
  ++ corelibsCmakeFlags
  ++ [
    (lib.cmakeFeature "ArgumentParser_DIR" "${lib.getDev swift-argument-parser}/lib/cmake/ArgumentParser")
    (lib.cmakeFeature "cmark-gfm_DIR" "${swift-cmark}/lib/cmake")
    (lib.cmakeFeature "SwiftMarkdown_DIR" "${lib.getDev swift-markdown}/lib/cmake/SwiftMarkdown")
    (lib.cmakeFeature "SwiftSyntax_DIR" "${lib.getDev swift-syntax}/lib/cmake/SwiftSyntax")
  ];

  preConfigure = ''
    cmakeFlagsArray+=(
      "-DCMAKE_Swift_FLAGS=${swiftSearchFlags} ${
        lib.concatMapStringsSep " " (dir: "-I ${dir}") moduleDirs
      } ${lib.concatMapStringsSep " " (dir: "-L ${dir}") libraryDirs} ${
        lib.concatMapStringsSep " " (
          dir: "-Xcc -fmodule-map-file=${dir}/module.modulemap -Xcc -I${dir}"
        ) [
          "${lib.getDev swift-syntax}/include/_SwiftSyntaxCShims"
          "${lib.getDev swift-markdown}/include/CAtomic"
        ]
      }"
    )
  '';

  # No install rules, as with the other projects here.
  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    cp bin/swift-format $out/bin/

    runHook postInstall
  '';

  postFixup = ''
    rpath="${lib.getLib swift-unwrapped}/lib/swift/${swiftOs}"
    rpath="$rpath:${Foundation}/lib/swift/${swiftOs}:${Dispatch}/lib/swift/${swiftOs}"
    rpath="$rpath:${lib.concatStringsSep ":" libraryDirs}"
    patchelf --add-rpath "$rpath" $out/bin/swift-format

    $out/bin/swift-format --version > /dev/null
  '';

  meta = {
    description = "Formatting technology for Swift source code";
    homepage = "https://github.com/swiftlang/swift-format";
    mainProgram = "swift-format";
    platforms = lib.platforms.linux;
    license = lib.licenses.asl20;
    teams = [ lib.teams.swift ];
  };
}
