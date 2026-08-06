{
  lib,
  stdenv,
  callPackage,
  cmake,
  ninja,
  substituteAll,
  swift-unwrapped,
}:

# Data structures the standard library does not provide. Foundation vendors
# its own copy of the sources; this is the toolchain-wide build that SwiftPM,
# swift-build and swift-certificates link against.

let
  sources = callPackage ../sources.nix { };
in
stdenv.mkDerivation {
  pname = "swift-collections";

  version = sources.pinnedVersions.swift-collections;
  src = sources.swift-collections;

  outputs = [
    "out"
    "dev"
  ];

  nativeBuildInputs = [
    cmake
    ninja
  ];

  cmakeFlags = [
    (lib.cmakeFeature "CMAKE_Swift_COMPILER" "${swift-unwrapped}/bin/swiftc")
    (lib.cmakeBool "BUILD_TESTING" false)
  ];

  preConfigure = ''
    # These libraries import nothing from the toolchain beyond the standard
    # library, but they still have to record where it lives: linkers emit
    # DT_RUNPATH, which is not used to resolve the dependencies of a
    # dependency.
    cmakeFlagsArray+=(
      "-DCMAKE_Swift_FLAGS=-Xlinker -rpath -Xlinker ${lib.getLib swift-unwrapped}/lib/swift/${swift-unwrapped.swiftOs}"
    )
  '';

  postInstall = ''
    # Only exports its CMake package into the build tree.
    mkdir -p $dev/lib/cmake/SwiftCollections
    export dylibExt="${stdenv.hostPlatform.extensions.sharedLibrary}"
    export swiftOs="${swift-unwrapped.swiftOs}"
    substituteAll ${./glue.cmake} $dev/lib/cmake/SwiftCollections/SwiftCollectionsConfig.cmake
  '';

  meta = {
    description = "Commonly useful data structures for Swift";
    homepage = "https://github.com/apple/swift-collections";
    platforms = lib.platforms.linux;
    license = lib.licenses.asl20;
    teams = [ lib.teams.swift ];
  };
}
