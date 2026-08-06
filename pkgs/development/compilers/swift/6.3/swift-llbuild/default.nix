{
  lib,
  stdenv,
  callPackage,
  cmake,
  ninja,
  substituteAll,
  sqlite,
  ncurses,
  swift-unwrapped,
  swiftSearchFlags,
  corelibsBuildInputs,
  corelibsCmakeFlags,
  Foundation,
  Dispatch,
}:

# Low-level build system used by SwiftPM and swift-driver.

let
  sources = callPackage ../sources.nix { };
in
stdenv.mkDerivation {
  pname = "swift-llbuild";

  inherit (sources) version;
  src = sources.swift-llbuild;

  nativeBuildInputs = [
    cmake
    ninja
  ];

  buildInputs = [
    sqlite
    # llbuild links -lcurses for its build progress UI.
    (ncurses.override { unicodeSupport = false; })
  ]
  ++ corelibsBuildInputs;

  cmakeFlags = [
    (lib.cmakeFeature "CMAKE_Swift_COMPILER" "${swift-unwrapped}/bin/swiftc")
  ]
  ++ corelibsCmakeFlags
  ++ [
    (lib.cmakeBool "BUILD_TESTING" false)
    # A list of bindings to build, not a boolean: SwiftPM and swift-driver
    # import the Swift ones.
    (lib.cmakeFeature "LLBUILD_SUPPORT_BINDINGS" "Swift")
  ];

  # llbuild links the curses library by its historical name in several
  # places, but Nixpkgs only provides libncurses.
  postPatch = ''
    files=$(grep -rl '^\s*curses)\?$' --include=CMakeLists.txt .)
    [ -n "$files" ] || { echo "no curses references found" >&2; exit 1; }
    echo "$files" | xargs sed -i 's/^\(\s*\)curses\()\?\)$/\1ncurses\2/'
    substituteInPlace lib/llvm/Support/CMakeLists.txt \
      --replace-fail 'PRIVATE curses)' 'PRIVATE ncurses)'
  '';

  preConfigure = ''
    cmakeFlagsArray+=("-DCMAKE_Swift_FLAGS=${swiftSearchFlags}")
  '';

  postInstall = ''
    # The Swift bindings install their library but not the module interface
    # that dependents import.
    modules=$(find . -name '*.swiftmodule' -not -path '*/CMakeFiles/*')
    [ -n "$modules" ] || { echo "error: no Swift modules were built" >&2; exit 1; }
    echo "$modules" | xargs -I{} cp -r {} $out/lib/swift/pm/llbuild/

    # The C API's module map is not installed, but `import llbuild` needs it.
    cp ${sources.swift-llbuild}/products/libllbuild/include/module.modulemap \
      $out/include/

    # Only exports its CMake package into the build tree.
    mkdir -p $out/lib/cmake/llbuild
    export dylibExt="${stdenv.hostPlatform.extensions.sharedLibrary}"
    export swiftOs="${swift-unwrapped.swiftOs}"
    substituteAll ${./glue.cmake} $out/lib/cmake/llbuild/LLBuildConfig.cmake
  '';

  meta = {
    description = "Low-level build system, used by the Swift Package Manager";
    homepage = "https://github.com/swiftlang/swift-llbuild";
    platforms = lib.platforms.linux;
    license = lib.licenses.asl20;
    teams = [ lib.teams.swift ];
  };
}
