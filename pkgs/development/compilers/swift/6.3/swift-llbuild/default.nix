{
  lib,
  stdenv,
  callPackage,
  cmake,
  ninja,
  sqlite,
  ncurses,
  swift-unwrapped,
  swiftSearchFlags,
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
    Foundation
    Dispatch
  ];

  cmakeFlags = [
    (lib.cmakeFeature "CMAKE_Swift_COMPILER" "${swift-unwrapped}/bin/swiftc")
    (lib.cmakeFeature "dispatch_DIR" "${lib.getDev Dispatch}/lib/cmake/dispatch")
    (lib.cmakeFeature "Foundation_DIR" "${lib.getDev Foundation}/lib/cmake/Foundation")
    (lib.cmakeBool "BUILD_TESTING" false)
    # Build the Swift bindings that SwiftPM and swift-driver import.
    (lib.cmakeBool "LLBUILD_SUPPORT_BINDINGS" true)
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

  meta = {
    description = "Low-level build system, used by the Swift Package Manager";
    homepage = "https://github.com/swiftlang/swift-llbuild";
    platforms = lib.platforms.linux;
    license = lib.licenses.asl20;
    teams = [ lib.teams.swift ];
  };
}
