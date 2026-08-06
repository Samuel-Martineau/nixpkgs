{
  lib,
  stdenv,
  callPackage,
  cmake,
  ninja,
  git,
  binutils,
  sqlite,
  ncurses,
  makeWrapper,
  swift-unwrapped,
  swiftSearchFlags,
  swift-argument-parser,
  swift-asn1,
  swift-build,
  swift-certificates,
  swift-collections,
  swift-crypto,
  swift-driver,
  swift-llbuild,
  swift-system,
  swift-tools-protocols,
  swift-tools-support-core,
  Foundation,
  Dispatch,
}:

# The Swift Package Manager.
#
# SwiftPM is itself a SwiftPM package, so it cannot be built by SwiftPM until
# one exists. Upstream breaks the circle by keeping a second build description
# in CMake. In 6.3 that build is complete: `Sources/Runtimes` -- the split
# runtime build -- produces PackageDescription and PackagePlugin, the
# libraries every package manifest and build plugin is compiled against, and
# installs them into lib/swift/pm/{ManifestAPI,PluginAPI} with their Swift
# interfaces. Upstream then rebuilds SwiftPM with itself, but that exercises
# self-hosting rather than producing anything the CMake build lacks, so it is
# not repeated here.
#
# (This differs from 5.10, where the CMake build did not install the manifest
# API and the second stage was needed to get it.)

let
  sources = callPackage ../sources.nix { };
  inherit (swift-unwrapped) swiftOs swiftArch;

  # CMake does not turn the include directories of imported targets into Swift
  # search paths, so every module directory has to be named. No two of these
  # packages install their modules in the same place.
  moduleDirs = [
    "${swift-argument-parser}/lib/swift/${swiftOs}"
    "${swift-asn1}/lib/swift/${swiftOs}/${swiftArch}"
    "${swift-build}/lib/swift/${swiftOs}"
    "${swift-certificates}/lib/swift/${swiftOs}"
    "${swift-collections}/lib/swift_static/${swiftOs}"
    "${swift-crypto}/lib/swift/${swiftOs}/${swiftArch}"
    "${swift-driver}/lib/swift/${swiftOs}"
    "${swift-llbuild}/lib/swift/pm/llbuild"
    "${swift-system}/lib/swift_static/${swiftOs}"
    "${swift-tools-protocols}/lib/swift/${swiftOs}"
    "${swift-tools-support-core}/lib/swift/${swiftOs}"
  ];

  libraryDirs = [
    "${swift-argument-parser}/lib"
    "${swift-asn1}/lib/swift/${swiftOs}"
    "${swift-build}/lib"
    "${swift-certificates}/lib/swift/${swiftOs}"
    "${swift-collections}/lib/swift_static/${swiftOs}"
    "${swift-crypto}/lib/swift/${swiftOs}"
    "${swift-driver}/lib"
    "${swift-llbuild}/lib"
    "${swift-llbuild}/lib/swift/pm/llbuild"
    "${swift-system}/lib"
    "${swift-tools-protocols}/lib"
    "${swift-tools-support-core}/lib"
  ];

  # The C modules the Swift ones are overlays on. None of these module maps sit
  # on a default search path, and none of these packages install them without
  # being told to.
  clangModuleDirs = [
    "${lib.getDev swift-tools-support-core}/include/TSCclibc"
    "${swift-llbuild}/include"
    "${lib.getDev swift-tools-protocols}/include/ToolsProtocolsCAtomics"
    "${lib.getDev swift-build}/include/SWBCLibc"
    "${lib.getDev swift-build}/include/SWBCSupport"
  ];
in
stdenv.mkDerivation {
  pname = "swiftpm";

  inherit (sources) version;
  src = sources.swift-package-manager;

  nativeBuildInputs = [
    cmake
    ninja
    makeWrapper
  ];

  buildInputs = [
    ncurses
    sqlite
    swift-argument-parser
    swift-asn1
    swift-build
    swift-certificates
    swift-collections
    swift-crypto
    swift-driver
    swift-llbuild
    swift-system
    swift-tools-protocols
    swift-tools-support-core
    Foundation
    Dispatch
  ];

  postPatch = ''
    # The location of xcrun is hardcoded; PATH lookup is what works here.
    find Sources -name '*.swift' | xargs sed -i -e 's|/usr/bin/xcrun|xcrun|g'
  '';

  cmakeFlags = [
    (lib.cmakeFeature "CMAKE_Swift_COMPILER" "${swift-unwrapped}/bin/swiftc")
    # Upstream builds against a Foundation that comes with the toolchain
    # rather than as a CMake package, so its `find_package(Foundation QUIET)`
    # fails and the blocks guarded by `Foundation_FOUND` never run. Those
    # blocks refer to a target `Dispatch` that no Foundation package defines,
    # and to `Fooundation`, which is a typo -- neither can work, so letting
    # the package be found only turns dead code into a configure failure.
    # Nixpkgs does ship CMake packages for both, and the setup hook puts every
    # build input on CMAKE_PREFIX_PATH, so they have to be hidden explicitly.
    # Foundation is found through the Swift search flags instead.
    (lib.cmakeBool "CMAKE_DISABLE_FIND_PACKAGE_Foundation" true)
    (lib.cmakeBool "CMAKE_DISABLE_FIND_PACKAGE_dispatch" true)
    (lib.cmakeFeature "ArgumentParser_DIR" "${lib.getDev swift-argument-parser}/lib/cmake/ArgumentParser")
    (lib.cmakeFeature "LLBuild_DIR" "${swift-llbuild}/lib/cmake/llbuild")
    (lib.cmakeFeature "SwiftASN1_DIR" "${lib.getDev swift-asn1}/lib/cmake/SwiftASN1")
    (lib.cmakeFeature "SwiftBuild_DIR" "${lib.getDev swift-build}/lib/cmake/SwiftBuild")
    (lib.cmakeFeature "SwiftCertificates_DIR" "${lib.getDev swift-certificates}/lib/cmake/SwiftCertificates")
    (lib.cmakeFeature "SwiftCollections_DIR" "${lib.getDev swift-collections}/lib/cmake/SwiftCollections")
    (lib.cmakeFeature "SwiftCrypto_DIR" "${lib.getDev swift-crypto}/lib/cmake/SwiftCrypto")
    (lib.cmakeFeature "SwiftDriver_DIR" "${swift-driver}/lib/cmake/SwiftDriver")
    (lib.cmakeFeature "SwiftSystem_DIR" "${lib.getDev swift-system}/lib/cmake/SwiftSystem")
    (lib.cmakeFeature "SwiftToolsProtocols_DIR" "${lib.getDev swift-tools-protocols}/lib/cmake/SwiftToolsProtocols")
    (lib.cmakeFeature "TSC_DIR" "${lib.getDev swift-tools-support-core}/lib/cmake/TSC")
    # Without this, CMake clones swift-syntax from GitHub while configuring,
    # to build the macros the manifest API uses.
    (lib.cmakeFeature "SWIFTPM_PATH_TO_SWIFT_SYNTAX_SOURCE" "${sources.swift-syntax}")
    (lib.cmakeBool "FETCHCONTENT_FULLY_DISCONNECTED" true)
  ];

  # The vendored swift-syntax marks SwiftCompilerPlugin EXCLUDE_FROM_ALL, so
  # the default target never builds it, but its install rule runs regardless
  # and then fails on the missing library.
  ninjaFlags = [
    "all"
    "SwiftCompilerPlugin"
  ];

  preConfigure = ''
    cmakeFlagsArray+=(
      "-DCMAKE_Swift_FLAGS=${swiftSearchFlags} ${
        lib.concatMapStringsSep " " (dir: "-I ${dir}") moduleDirs
      } ${lib.concatMapStringsSep " " (dir: "-L ${dir}") libraryDirs} ${
        lib.concatMapStringsSep " " (
          dir: "-Xcc -fmodule-map-file=${dir}/module.modulemap -Xcc -I${dir}"
        ) clangModuleDirs
      }"
    )
  '';

  postInstall = ''
    # SwiftPM shells out to git to fetch package dependencies, and refuses to
    # start unless it can find the archiver, which it looks for on PATH rather
    # than taking from the compiler it was told to use.
    for tool in $out/bin/swift-*; do
      [ -f "$tool" ] || continue
      wrapProgram "$tool" --prefix PATH : ${
        lib.makeBinPath [
          git
          binutils
        ]
      }
    done
  '';

  postFixup = ''
    # SwiftPM's own libraries, and the swift-syntax it vendors for the
    # manifest API, are installed here rather than in a dependency.
    rpath="$out/lib:$out/lib/swift/host"
    rpath="$rpath:${lib.getLib swift-unwrapped}/lib/swift/${swiftOs}"
    rpath="$rpath:${Foundation}/lib/swift/${swiftOs}:${Dispatch}/lib/swift/${swiftOs}"
    rpath="$rpath:${lib.concatStringsSep ":" libraryDirs}"
    # Linked by bare name, so nothing records where they live.
    rpath="$rpath:${lib.getLib sqlite}/lib:${lib.getLib ncurses}/lib"

    for binary in $out/bin/.*-wrapped $out/lib/*.so $out/lib/swift/host/*.so $out/lib/swift/pm/*/*.so; do
      [ -f "$binary" ] || continue
      patchelf --print-rpath "$binary" >/dev/null 2>&1 || continue
      patchelf --add-rpath "$rpath" "$binary"
    done

    # The manifest API is what every package's Package.swift compiles against,
    # so a build that silently omits it is worse than one that fails.
    for expected in ManifestAPI/libPackageDescription.so PluginAPI/libPackagePlugin.so; do
      [ -e "$out/lib/swift/pm/$expected" ] \
        || { echo "error: $expected was not installed" >&2; exit 1; }
    done

    $out/bin/swift-package --help > /dev/null
  '';

  meta = {
    description = "Package manager for the Swift programming language";
    homepage = "https://github.com/swiftlang/swift-package-manager";
    mainProgram = "swift-package";
    platforms = lib.platforms.linux;
    license = lib.licenses.asl20;
    teams = [ lib.teams.swift ];
  };
}
