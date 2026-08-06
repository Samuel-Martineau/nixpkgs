{
  lib,
  stdenv,
  callPackage,
  cmake,
  ninja,
  substituteAll,
  swift-unwrapped,
  swiftSearchFlags,
  swift-cmark,
  swift-argument-parser,
  corelibsCmakeFlags,
  Foundation,
  Dispatch,
}:

# Swift's Markdown parser, built on swift-cmark. swift-docc, swift-format and
# sourcekit-lsp all read documentation through it.

let
  sources = callPackage ../sources.nix { };
  inherit (swift-unwrapped) swiftOs;
in
stdenv.mkDerivation {
  pname = "swift-markdown";

  inherit (sources) version;
  src = sources.swift-markdown;

  outputs = [
    "out"
    "dev"
  ];

  nativeBuildInputs = [
    cmake
    ninja
  ];

  buildInputs = [
    swift-cmark
    swift-argument-parser
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
  ];

  preConfigure = ''
    cmakeFlagsArray+=(
      "-DCMAKE_Swift_FLAGS=${swiftSearchFlags} -I ${swift-argument-parser}/lib/swift/${swiftOs} -L ${swift-argument-parser}/lib"
    )
  '';

  # Like the other DocC projects, this has no install rules at all: upstream
  # builds it inside a larger tree and refers to the build directory.
  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib $out/lib/swift/${swiftOs}
    cp lib/libMarkdown.* lib/libCAtomic.* $out/lib/
    cp swift/Markdown.swiftmodule swift/Markdown.swiftdoc $out/lib/swift/${swiftOs}/

    runHook postInstall
  '';

  postInstall = ''
    # CAtomic is the C shim the Markdown module is an overlay on. Its headers
    # are not installed, but dependents that import Markdown need them.
    mkdir -p $dev/include/CAtomic
    cp $src/Sources/CAtomic/include/* $dev/include/CAtomic/
    [ -e $dev/include/CAtomic/module.modulemap ] \
      || { echo "error: the CAtomic module map was not installed" >&2; exit 1; }

    # Only exports its CMake package into the build tree.
    mkdir -p $dev/lib/cmake/SwiftMarkdown
    export swiftOs="${swiftOs}"
    substituteAll ${./glue.cmake} $dev/lib/cmake/SwiftMarkdown/SwiftMarkdownConfig.cmake
  '';

  meta = {
    description = "Swift library for parsing, building and formatting Markdown";
    homepage = "https://github.com/swiftlang/swift-markdown";
    platforms = lib.platforms.linux;
    license = lib.licenses.asl20;
    teams = [ lib.teams.swift ];
  };
}
