{
  lib,
  stdenv,
  callPackage,
  cmake,
  ninja,
  substituteAll,
  swift-unwrapped,
}:

# The Swift parser and syntax tree library that macros are written against.
# The compiler builds its own copy in tree for the macro plugin server; this
# is the separate package swift-format and sourcekit-lsp are built against.

let
  sources = callPackage ../sources.nix { };
in
stdenv.mkDerivation {
  pname = "swift-syntax";

  inherit (sources) version;
  src = sources.swift-syntax;

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
    (lib.cmakeBool "BUILD_SHARED_LIBS" true)
    (lib.cmakeBool "SWIFTSYNTAX_ENABLE_ASSERTIONS" false)
  ];

  # SwiftCompilerPlugin is EXCLUDE_FROM_ALL, so the default target never
  # builds it, but its install rule runs regardless and then fails on the
  # missing library.
  ninjaFlags = [
    "all"
    "SwiftCompilerPlugin"
  ];

  preConfigure = ''
    # Imports nothing from the toolchain beyond the standard library, but the
    # libraries still have to record where it lives: linkers emit DT_RUNPATH,
    # which is not used to resolve the dependencies of a dependency.
    cmakeFlagsArray+=(
      "-DCMAKE_Swift_FLAGS=-Xlinker -rpath -Xlinker ${lib.getLib swift-unwrapped}/lib/swift/${swift-unwrapped.swiftOs}"
    )
  '';

  postInstall = ''
    # The libraries are installed but not the module interfaces dependents
    # import, which is the whole point of the package for them.
    modules=$(find . -name '*.swiftmodule' -not -path '*/CMakeFiles/*' -maxdepth 3)
    [ -n "$modules" ] || { echo "error: no Swift modules were built" >&2; exit 1; }
    echo "$modules" | xargs -I{} cp -r {} $out/lib/swift/host/

    # Only exports its CMake package into the build tree.
    mkdir -p $dev/lib/cmake/SwiftSyntax
    export dylibExt="${stdenv.hostPlatform.extensions.sharedLibrary}"
    substituteAll ${./glue.cmake} $dev/lib/cmake/SwiftSyntax/SwiftSyntaxConfig.cmake
  '';

  meta = {
    description = "Swift parser and syntax tree library, used to write macros";
    homepage = "https://github.com/swiftlang/swift-syntax";
    platforms = lib.platforms.linux;
    license = lib.licenses.asl20;
    teams = [ lib.teams.swift ];
  };
}
