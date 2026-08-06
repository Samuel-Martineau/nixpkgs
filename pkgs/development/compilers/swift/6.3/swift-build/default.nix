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
  swift-driver,
  swift-llbuild,
  swift-system,
  swift-tools-protocols,
  swift-tools-support-core,
  corelibsBuildInputs,
  corelibsCmakeFlags,
  corelibsRpath,
  Foundation,
  Dispatch,
}:

# Swift Build, the build engine SwiftPM 6 delegates to. Formerly the engine
# behind Xcode, now a separate open-source component SwiftPM links against.

let
  sources = callPackage ../sources.nix { };
  inherit (swift-unwrapped) swiftOs swiftArch;

  # None of these install the Swift modules dependents import in the same
  # place, so collect the search paths once.
  moduleDirs = [
    "${swift-argument-parser}/lib/swift/${swiftOs}"
    "${swift-driver}/lib/swift/${swiftOs}"
    "${swift-llbuild}/lib/swift/pm/llbuild"
    "${swift-system}/lib/swift_static/${swiftOs}"
    "${swift-tools-protocols}/lib/swift/${swiftOs}"
    "${swift-tools-support-core}/lib/swift/${swiftOs}"
  ];

  libraryDirs = [
    "${swift-argument-parser}/lib"
    "${swift-driver}/lib"
    "${swift-llbuild}/lib"
    "${swift-llbuild}/lib/swift/pm/llbuild"
    "${swift-system}/lib"
    "${swift-tools-protocols}/lib"
    "${swift-tools-support-core}/lib"
  ];
in
stdenv.mkDerivation {
  pname = "swift-build";

  inherit (sources) version;
  src = sources.swift-build;

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
    swift-argument-parser
    swift-driver
    swift-llbuild
    swift-system
    swift-tools-protocols
    swift-tools-support-core
  ]
  ++ corelibsBuildInputs;

  cmakeFlags = [
    (lib.cmakeFeature "CMAKE_Swift_COMPILER" "${swift-unwrapped}/bin/swiftc")
  ]
  ++ corelibsCmakeFlags
  ++ [
    (lib.cmakeFeature "ArgumentParser_DIR" "${lib.getDev swift-argument-parser}/lib/cmake/ArgumentParser")
    (lib.cmakeFeature "LLBuild_DIR" "${swift-llbuild}/lib/cmake/llbuild")
    (lib.cmakeFeature "SwiftDriver_DIR" "${swift-driver}/lib/cmake/SwiftDriver")
    (lib.cmakeFeature "SwiftSystem_DIR" "${lib.getDev swift-system}/lib/cmake/SwiftSystem")
    (lib.cmakeFeature "SwiftToolsProtocols_DIR" "${lib.getDev swift-tools-protocols}/lib/cmake/SwiftToolsProtocols")
    (lib.cmakeFeature "TSC_DIR" "${lib.getDev swift-tools-support-core}/lib/cmake/TSC")
    # The install rules use this as their destination, but nothing sets it:
    # upstream builds this project without ever installing it, and points
    # dependents at the build tree instead.
    (lib.cmakeFeature "SwiftBuild_INSTALL_LIBDIR" "lib")
    # For the same reason the install rules only cover ARCHIVE, so a shared
    # build installs no libraries at all. Static is what they were written
    # for, and is how SwiftPM consumes these anyway.
    (lib.cmakeBool "BUILD_SHARED_LIBS" false)
  ];

  preConfigure = ''
    # SWBLLBuild imports llbuild's C API directly, so the Swift module search
    # paths are not enough: the Clang module it overlays has to be reachable
    # too, and llbuild's module map is not on any default search path.
    cmakeFlagsArray+=(
      "-DCMAKE_Swift_FLAGS=${swiftSearchFlags} ${
        lib.concatMapStringsSep " " (dir: "-I ${dir}") moduleDirs
      } ${
        lib.concatMapStringsSep " " (dir: "-L ${dir}") libraryDirs
      } -Xcc -fmodule-map-file=${swift-llbuild}/include/module.modulemap -Xcc -I${swift-llbuild}/include -Xcc -fmodule-map-file=${lib.getDev swift-tools-protocols}/include/ToolsProtocolsCAtomics/module.modulemap -Xcc -I${lib.getDev swift-tools-protocols}/include/ToolsProtocolsCAtomics"
    )
  '';

  postInstall = ''
    # The Swift modules are not installed at all, only the static libraries.
    mkdir -p $out/lib/swift/${swiftOs}
    modules=$(find . \( -name '*.swiftmodule' -o -name '*.swiftdoc' \) -not -path '*/CMakeFiles/*')
    [ -n "$modules" ] || { echo "error: no Swift modules were built" >&2; exit 1; }
    echo "$modules" | xargs -I{} cp -r {} $out/lib/swift/${swiftOs}/

    # SWBCLibc and SWBCSupport are the C modules the Swift ones are overlays
    # on. Their headers are not installed either, and SwiftPM imports them.
    mkdir -p $dev/include/SWBCLibc $dev/include/SWBCSupport
    cp $src/Sources/SWBCLibc/include/* $dev/include/SWBCLibc/
    cp $src/Sources/SWBCSupport/* $dev/include/SWBCSupport/ 2>/dev/null || true
    for expected in SWBCLibc SWBCSupport; do
      [ -e "$dev/include/$expected/module.modulemap" ] \
        || { echo "error: $expected module map was not installed" >&2; exit 1; }
    done

    # Only exports its CMake package into the build tree.
    mkdir -p $dev/lib/cmake/SwiftBuild
    export swiftOs="${swiftOs}"
    substituteAll ${./glue.cmake} $dev/lib/cmake/SwiftBuild/SwiftBuildConfig.cmake
  '';

  # This project sets CMAKE_INSTALL_RPATH, so the paths recorded at link time
  # do not survive installing. The build service is the only executable.
  postFixup = ''
    rpath="${lib.getLib swift-unwrapped}/lib/swift/${swiftOs}"
    rpath="$rpath${corelibsRpath}"
    rpath="$rpath:${lib.concatStringsSep ":" libraryDirs}"

    for binary in $out/bin/*; do
      [ -f "$binary" ] || continue
      patchelf --add-rpath "$rpath" "$binary"
    done
  '';

  meta = {
    description = "Build engine used by the Swift Package Manager";
    homepage = "https://github.com/swiftlang/swift-build";
    platforms = lib.platforms.linux;
    license = lib.licenses.asl20;
    teams = [ lib.teams.swift ];
  };
}
