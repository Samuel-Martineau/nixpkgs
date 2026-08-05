{
  lib,
  stdenv,
  callPackage,
  cmake,
  ninja,
  swift-unwrapped,
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
    Foundation
    Dispatch
  ];

  cmakeFlags = [
    (lib.cmakeFeature "CMAKE_Swift_COMPILER" "${swift-unwrapped}/bin/swiftc")
    (lib.cmakeFeature "dispatch_DIR" "${lib.getDev Dispatch}/lib/cmake/dispatch")
    (lib.cmakeFeature "Foundation_DIR" "${lib.getDev Foundation}/lib/cmake/Foundation")
    # The macro plugin needs swift-syntax, which is consumed from a checkout
    # rather than an installed package.
    (lib.cmakeFeature "FETCHCONTENT_SOURCE_DIR_SWIFTSYNTAX" "${sources.swift-syntax}")
    (lib.cmakeBool "FETCHCONTENT_FULLY_DISCONNECTED" true)
  ];

  meta = {
    description = "Modern testing library for Swift";
    homepage = "https://github.com/swiftlang/swift-testing";
    platforms = lib.platforms.linux;
    license = lib.licenses.asl20;
    teams = [ lib.teams.swift ];
  };
}
