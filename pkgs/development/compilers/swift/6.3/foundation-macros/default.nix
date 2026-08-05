{
  lib,
  stdenv,
  callPackage,
  cmake,
  ninja,
  swift-unwrapped,
}:

# Compiler plugin providing Foundation's macros (`#Predicate`, `#Expression`,
# `#bundle`). Foundation is built against it via SwiftFoundation_MACRO.
#
# swift-syntax is consumed the way upstream intends, through FetchContent
# against a local checkout: its CMake install ships only shared libraries,
# with no .swiftmodule interfaces, so it cannot be used as an installed
# package.

let
  sources = callPackage ../sources.nix { };
in
stdenv.mkDerivation {
  pname = "swift-foundation-macros";

  inherit (sources) version;
  src = sources.swift-foundation;

  sourceRoot = "${sources.swift-foundation.name}/Sources/FoundationMacros";

  nativeBuildInputs = [
    cmake
    ninja
  ];

  cmakeFlags = [
    (lib.cmakeFeature "CMAKE_Swift_COMPILER" "${swift-unwrapped}/bin/swiftc")
    (lib.cmakeFeature "FETCHCONTENT_SOURCE_DIR_SWIFTSYNTAX" "${sources.swift-syntax}")
    (lib.cmakeBool "FETCHCONTENT_FULLY_DISCONNECTED" true)
  ];

  meta = {
    description = "Macro implementations for Swift Foundation";
    homepage = "https://github.com/swiftlang/swift-foundation";
    platforms = lib.platforms.linux;
    license = lib.licenses.asl20;
    teams = [ lib.teams.swift ];
  };
}
