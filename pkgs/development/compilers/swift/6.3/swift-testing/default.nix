{
  lib,
  stdenv,
  callPackage,
  cmake,
  ninja,
  swift-unwrapped,
  corelibsBuildInputs,
  corelibsCmakeFlags,
  Foundation,
  Dispatch,
}:

# Swift Testing, the macro-based testing library introduced in Swift 6. Used
# by SwiftPM's `swift test` alongside XCTest.

let
  sources = callPackage ../sources.nix { };
in
stdenv.mkDerivation {
  pname = "swift-testing";

  inherit (sources) version;
  src = sources.swift-testing;

  nativeBuildInputs = [
    cmake
    ninja
  ];

  buildInputs = [
  ]
  ++ corelibsBuildInputs;

  cmakeFlags = [
    (lib.cmakeFeature "CMAKE_Swift_COMPILER" "${swift-unwrapped}/bin/swiftc")
  ]
  ++ corelibsCmakeFlags
  ++ [
  ];

  # The macro plugin is configured as a nested project with its own, filtered
  # set of CMake arguments, so FETCHCONTENT_SOURCE_DIR_SWIFTSYNTAX does not
  # reach it. Point the declaration at the checkout instead of a clone.
  postPatch = ''
    substituteInPlace Sources/TestingMacros/CMakeLists.txt \
      --replace-fail \
        'GIT_REPOSITORY https://github.com/swiftlang/swift-syntax' \
        'SOURCE_DIR ${sources.swift-syntax}' \
      --replace-fail \
        'GIT_TAG 07bf225e198119c23b2b9a0a3432bdb534498873)' \
        ')'
  '';

  meta = {
    description = "Modern testing library for Swift";
    homepage = "https://github.com/swiftlang/swift-testing";
    platforms = lib.platforms.linux;
    license = lib.licenses.asl20;
    teams = [ lib.teams.swift ];
  };
}
