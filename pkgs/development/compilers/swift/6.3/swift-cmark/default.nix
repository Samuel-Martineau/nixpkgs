{
  lib,
  stdenv,
  callPackage,
  cmake,
  ninja,
}:

# Swift's fork of cmark-gfm, the GitHub-Flavored Markdown parser. The compiler
# builds its own copy in tree for documentation comments; this is the separate
# package swift-markdown and swift-docc are built against.
#
# Unusually for this toolchain, it installs a real CMake package of its own, so
# it needs no hand-written glue.

let
  sources = callPackage ../sources.nix { };
in
stdenv.mkDerivation {
  pname = "swift-cmark";

  inherit (sources) version;
  src = sources.swift-cmark;

  nativeBuildInputs = [
    cmake
    ninja
  ];

  cmakeFlags = [
    (lib.cmakeBool "BUILD_SHARED_LIBS" true)
    (lib.cmakeBool "CMARK_TESTS" false)
  ];

  postInstall = ''
    [ -e $out/lib/cmake/cmark-gfm-config.cmake ] \
      || { echo "error: the CMake package was not installed" >&2; exit 1; }
  '';

  meta = {
    description = "Swift's fork of cmark-gfm, a GitHub-Flavored Markdown parser";
    homepage = "https://github.com/swiftlang/swift-cmark";
    platforms = lib.platforms.linux;
    license = lib.licenses.bsd2;
    teams = [ lib.teams.swift ];
  };
}
