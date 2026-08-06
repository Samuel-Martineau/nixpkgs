{
  lib,
  stdenv,
  callPackage,
  cmake,
  ninja,
  substituteAll,
  sqlite,
  swift-unwrapped,
  swiftSearchFlags,
  swift-argument-parser,
  swift-llbuild,
  swift-tools-support-core,
  corelibsCmakeFlags,
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
  ]
  ++ corelibsCmakeFlags
  ++ [
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

  postInstall = ''
    # The Swift modules dependents import are not installed, only the
    # libraries.
    mkdir -p $out/lib/swift/${swift-unwrapped.swiftOs}
    modules=$(find . -name '*.swiftmodule' -not -path '*/CMakeFiles/*')
    [ -n "$modules" ] || { echo "error: no Swift modules were built" >&2; exit 1; }
    echo "$modules" | xargs -I{} cp -r {} $out/lib/swift/${swift-unwrapped.swiftOs}/

    # Only exports its CMake package into the build tree, so describe the
    # installed libraries for swift-build and SwiftPM.
    mkdir -p $out/lib/cmake/SwiftDriver
    export dylibExt="${stdenv.hostPlatform.extensions.sharedLibrary}"
    export swiftOs="${swift-unwrapped.swiftOs}"
    substituteAll ${./glue.cmake} $out/lib/cmake/SwiftDriver/SwiftDriverConfig.cmake
  '';

  # The build records no path to the libraries it links, so add them. The
  # driver cannot be run from here to check: it looks for the rest of the
  # toolchain next to itself, which only holds once the wrapper has placed it
  # there, so that is where it is exercised.
  postFixup = ''
    rpath="${swift-argument-parser}/lib:${swift-tools-support-core}/lib"
    rpath="$rpath:${swift-llbuild}/lib:${swift-llbuild}/lib/swift/pm/llbuild"
    rpath="$rpath:${Foundation}/lib/swift/${swift-unwrapped.swiftOs}"
    rpath="$rpath:${Dispatch}/lib/swift/${swift-unwrapped.swiftOs}"
    rpath="$rpath:${lib.getLib swift-unwrapped}/lib/swift/${swift-unwrapped.swiftOs}"

    for binary in $out/bin/* $out/lib/*.so; do
      [ -f "$binary" ] || continue
      patchelf --print-rpath "$binary" >/dev/null 2>&1 || continue
      patchelf --add-rpath "$rpath" "$binary"
    done

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
