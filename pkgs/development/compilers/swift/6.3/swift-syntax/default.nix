{
  lib,
  stdenv,
  callPackage,
  cmake,
  ninja,
  swift-unwrapped,
}:

# Swift parser and macro support, built as a library for the tools that need
# it (Foundation's macro plugin, sourcekit-lsp, swift-format). The compiler
# builds its own private copy of these sources, installed under
# `lib/swift/host/compiler`, which is deliberately not shared.

let
  sources = callPackage ../sources.nix { };
in
stdenv.mkDerivation {
  pname = "swift-syntax";

  inherit (sources) version;
  src = sources.swift-syntax;

  nativeBuildInputs = [
    cmake
    ninja
  ];

  cmakeFlags = [
    (lib.cmakeFeature "CMAKE_Swift_COMPILER" "${swift-unwrapped}/bin/swiftc")
    (lib.cmakeBool "BUILD_SHARED_LIBS" true)
  ];

  # SwiftCompilerPlugin is EXCLUDE_FROM_ALL upstream (it is meant to be
  # consumed as a package dependency), but the install rules expect it, and
  # macro plugins such as Foundation's need it.
  ninjaFlags = [
    "all"
    "SwiftCompilerPlugin"
  ];

  postInstall = ''
    # The project exports its CMake package into the build directory rather
    # than installing it; dependents need it on disk.
    mkdir -p $out/lib/cmake/SwiftSyntax
    cp SwiftSyntaxConfig.cmake $out/lib/cmake/SwiftSyntax/ 2>/dev/null \
      || cp cmake/modules/SwiftSyntaxConfig.cmake $out/lib/cmake/SwiftSyntax/
  '';

  meta = {
    description = "Set of Swift libraries for parsing, inspecting, generating, and transforming Swift source code";
    homepage = "https://github.com/swiftlang/swift-syntax";
    platforms = lib.platforms.linux;
    license = lib.licenses.asl20;
    teams = [ lib.teams.swift ];
  };
}
