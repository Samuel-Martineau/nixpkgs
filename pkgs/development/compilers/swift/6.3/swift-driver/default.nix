{
  lib,
  stdenv,
  callPackage,
  cmake,
  ninja,
  sqlite,
  swift-unwrapped,
  swiftSearchFlags,
  swift-argument-parser,
  swift-llbuild,
  swift-tools-support-core,
  Foundation,
  Dispatch,
}:

# The Swift compiler driver, written in Swift. Without it the compiler falls
# back to its deprecated built-in driver.
#
# Built with CMake rather than SwiftPM, which keeps it independent of SwiftPM:
# SwiftPM itself needs a driver to build with.

let
  sources = callPackage ../sources.nix { };
in
stdenv.mkDerivation {
  pname = "swift-driver";

  inherit (sources) version;
  src = sources.swift-driver;

  nativeBuildInputs = [
    cmake
    ninja
  ];

  buildInputs = [
    sqlite
    swift-argument-parser
    swift-llbuild
    swift-tools-support-core
    Foundation
    Dispatch
  ];

  cmakeFlags = [
    (lib.cmakeFeature "CMAKE_Swift_COMPILER" "${swift-unwrapped}/bin/swiftc")
    (lib.cmakeFeature "dispatch_DIR" "${lib.getDev Dispatch}/lib/cmake/dispatch")
    (lib.cmakeFeature "Foundation_DIR" "${lib.getDev Foundation}/lib/cmake/Foundation")
    (lib.cmakeFeature "ArgumentParser_DIR" "${lib.getDev swift-argument-parser}/lib/cmake/ArgumentParser")
    (lib.cmakeFeature "TSC_DIR" "${lib.getDev swift-tools-support-core}/lib/cmake/TSC")
    (lib.cmakeFeature "LLBuild_DIR" "${swift-llbuild}/lib/cmake/llbuild")
    (lib.cmakeBool "BUILD_TESTING" false)
  ];

  preConfigure = ''
    cmakeFlagsArray+=(
      "-DCMAKE_Swift_FLAGS=${swiftSearchFlags} -I ${swift-argument-parser}/lib/swift/${swift-unwrapped.swiftOs} -I ${swift-tools-support-core}/lib/swift/${swift-unwrapped.swiftOs} -I ${swift-llbuild}/lib/swift/${swift-unwrapped.swiftOs} -L ${swift-argument-parser}/lib/swift/${swift-unwrapped.swiftOs} -L ${swift-tools-support-core}/lib/swift/${swift-unwrapped.swiftOs} -I ${swift-llbuild}/lib/swift/pm/llbuild -L ${swift-llbuild}/lib/swift/pm/llbuild -L ${swift-llbuild}/lib"
    )
  '';

  meta = {
    description = "Swift compiler driver";
    homepage = "https://github.com/swiftlang/swift-driver";
    mainProgram = "swift-driver";
    platforms = lib.platforms.linux;
    license = lib.licenses.asl20;
    teams = [ lib.teams.swift ];
  };
}
