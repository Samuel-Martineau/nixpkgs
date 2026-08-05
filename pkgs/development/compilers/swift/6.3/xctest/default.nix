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

let
  sources = callPackage ../sources.nix { };
in
stdenv.mkDerivation {
  pname = "swift-corelibs-xctest";

  inherit (sources) version;
  src = sources.swift-corelibs-xctest;

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
  ];

  preConfigure = ''
    # CMake does not translate the imported targets' include directories into
    # Swift search paths, so spell out where the modules, the module maps of
    # the C shims they overlay, and libdispatch's own module live.
    cmakeFlagsArray+=(
      "-DCMAKE_Swift_FLAGS=-I ${Foundation}/lib/swift/linux -Xcc -I${Foundation}/lib/swift -I ${Dispatch}/lib/swift/linux -Xcc -fmodule-map-file=${Dispatch}/lib/swift/dispatch/module.modulemap -Xcc -I${Dispatch}/lib/swift"
    )
  '';

  meta = {
    description = "Unit testing framework for Swift";
    homepage = "https://github.com/swiftlang/swift-corelibs-xctest";
    platforms = lib.platforms.linux;
    license = lib.licenses.asl20;
    teams = [ lib.teams.swift ];
  };
}
