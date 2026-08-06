{
  lib,
  stdenv,
  callPackage,
  cmake,
  ninja,
  substituteAll,
  swift-unwrapped,
}:

# Idiomatic Swift interfaces to system calls. Used by swift-tools-support-core,
# swift-driver, swift-build and SwiftPM.

let
  sources = callPackage ../sources.nix { };
in
stdenv.mkDerivation {
  pname = "swift-system";

  version = sources.pinnedVersions.swift-system;
  src = sources.swift-system;

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
    # This package imports nothing from the toolchain beyond the standard
    # library, but its library still has to record where that lives: linkers
    # emit DT_RUNPATH, which is not used to resolve the dependencies of a
    # dependency.
    cmakeFlagsArray+=(
      "-DCMAKE_Swift_FLAGS=-Xlinker -rpath -Xlinker ${lib.getLib swift-unwrapped}/lib/swift/${swift-unwrapped.swiftOs}"
    )
  '';

  postInstall = ''
    # Only exports its CMake package into the build tree.
    mkdir -p $dev/lib/cmake/SwiftSystem
    export dylibExt="${stdenv.hostPlatform.extensions.sharedLibrary}"
    export swiftOs="${swift-unwrapped.swiftOs}"
    substituteAll ${./glue.cmake} $dev/lib/cmake/SwiftSystem/SwiftSystemConfig.cmake
  '';

  meta = {
    description = "Idiomatic Swift interfaces to system calls and low-level currency types";
    homepage = "https://github.com/apple/swift-system";
    platforms = lib.platforms.linux;
    license = lib.licenses.asl20;
    teams = [ lib.teams.swift ];
  };
}
