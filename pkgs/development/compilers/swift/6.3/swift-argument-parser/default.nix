{
  lib,
  stdenv,
  callPackage,
  cmake,
  ninja,
  substituteAll,
  swift-unwrapped,
  swiftSearchFlags,
  Foundation,
  Dispatch,
}:

let
  sources = callPackage ../sources.nix { };
in
stdenv.mkDerivation {
  pname = "swift-argument-parser";

  version = sources.pinnedVersions.swift-argument-parser;
  src = sources.swift-argument-parser;

  outputs = [
    "out"
    "dev"
  ];

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
    (lib.cmakeBool "BUILD_TESTING" false)
    (lib.cmakeBool "BUILD_EXAMPLES" false)
  ];

  preConfigure = ''
    cmakeFlagsArray+=("-DCMAKE_Swift_FLAGS=${swiftSearchFlags}")
  '';

  postInstall = ''
    # Only exports its CMake package into the build tree, so describe the
    # installed library for dependents (swift-driver, swiftpm).
    mkdir -p $dev/lib/cmake/ArgumentParser
    export dylibExt="${stdenv.hostPlatform.extensions.sharedLibrary}"
    export swiftOs="${swift-unwrapped.swiftOs}"
    substituteAll ${./glue.cmake} $dev/lib/cmake/ArgumentParser/ArgumentParserConfig.cmake
  '';

  meta = {
    description = "Straightforward, type-safe argument parsing for Swift";
    homepage = "https://github.com/apple/swift-argument-parser";
    platforms = lib.platforms.linux;
    license = lib.licenses.asl20;
    teams = [ lib.teams.swift ];
  };
}
