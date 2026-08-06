{
  lib,
  stdenv,
  callPackage,
  cmake,
  ninja,
  substituteAll,
  swift-unwrapped,
  swiftSearchFlags,
  corelibsCmakeFlags,
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
  ]
  ++ corelibsCmakeFlags
  ++ [
    (lib.cmakeBool "BUILD_TESTING" false)
    (lib.cmakeBool "BUILD_EXAMPLES" false)
  ];

  preConfigure = ''
    cmakeFlagsArray+=("-DCMAKE_Swift_FLAGS=${swiftSearchFlags}")
  '';

  postInstall = ''
    # ArgumentParserToolInfo is built but not installed, and swift-help
    # imports it.
    for lib in $(find . -name 'libArgumentParserToolInfo.*'); do
      cp "$lib" $out/lib/
    done
    for module in $(find . -name 'ArgumentParserToolInfo.swiftmodule' -not -path '*/CMakeFiles/*'); do
      cp -r "$module" $out/lib/swift/${swift-unwrapped.swiftOs}/
    done
    [ -e $out/lib/swift/${swift-unwrapped.swiftOs}/ArgumentParserToolInfo.swiftmodule ] \
      || { echo "error: ArgumentParserToolInfo was not built" >&2; exit 1; }

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
