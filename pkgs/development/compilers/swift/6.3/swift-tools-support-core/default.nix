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
  Foundation,
  Dispatch,
}:

# Support library shared by SwiftPM and swift-driver.

let
  sources = callPackage ../sources.nix { };
in
stdenv.mkDerivation {
  pname = "swift-tools-support-core";

  inherit (sources) version;
  src = sources.swift-tools-support-core;

  outputs = [
    "out"
    "dev"
  ];

  nativeBuildInputs = [
    cmake
    ninja
  ];

  buildInputs = [
    sqlite
    Foundation
    Dispatch
  ];

  cmakeFlags = [
    (lib.cmakeFeature "CMAKE_Swift_COMPILER" "${swift-unwrapped}/bin/swiftc")
    (lib.cmakeFeature "dispatch_DIR" "${lib.getDev Dispatch}/lib/cmake/dispatch")
    (lib.cmakeFeature "Foundation_DIR" "${lib.getDev Foundation}/lib/cmake/Foundation")
    (lib.cmakeBool "BUILD_TESTING" false)
  ];

  preConfigure = ''
    cmakeFlagsArray+=("-DCMAKE_Swift_FLAGS=${swiftSearchFlags}")
  '';

  postInstall = ''
    # The static libraries are not installed at all, but dependents link them
    # (TSCLibc in particular is named by an autolink directive).
    for archive in $(find . -name 'libTSC*.a'); do
      cp "$archive" $out/lib/
    done

    # The libraries are installed but not the module interfaces dependents
    # import.
    mkdir -p $out/lib/swift/${swift-unwrapped.swiftOs}
    modules=$(find . -name '*.swiftmodule' -not -path '*/CMakeFiles/*')
    [ -n "$modules" ] || { echo "error: no Swift modules were built" >&2; exit 1; }
    echo "$modules" | xargs -I{} cp -r {} $out/lib/swift/${swift-unwrapped.swiftOs}/

    # Only exports its CMake package into the build tree.
    mkdir -p $dev/lib/cmake/TSC
    export dylibExt="${stdenv.hostPlatform.extensions.sharedLibrary}"
    export swiftOs="${swift-unwrapped.swiftOs}"
    substituteAll ${./glue.cmake} $dev/lib/cmake/TSC/TSCConfig.cmake
  '';

  meta = {
    description = "Common infrastructure for SwiftPM and other Swift tools";
    homepage = "https://github.com/swiftlang/swift-tools-support-core";
    platforms = lib.platforms.linux;
    license = lib.licenses.asl20;
    teams = [ lib.teams.swift ];
  };
}
