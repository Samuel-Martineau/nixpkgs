{
  lib,
  stdenv,
  swift-unwrapped,
  Foundation,
  Dispatch,
}:

# CMake does not translate the include directories of imported targets into
# Swift search paths, so every package that uses Foundation or libdispatch has
# to be told where to find three separate things: the Swift modules, the module
# maps of the C shims those modules are overlays on, and the same for
# libdispatch.
#
# Importing those modules also makes Swift emit autolink directives naming
# their libraries, so the linker needs to be pointed at them as well, and the
# result needs an rpath to find them at run time.
#
# On Darwin none of that applies: Foundation and libdispatch come with the SDK,
# which the compiler already knows how to find, so only the Swift runtime needs
# naming.

let
  inherit (swift-unwrapped) swiftOs;

  corelibs = lib.optionals (!stdenv.hostPlatform.isDarwin) [
    "-I ${Foundation}/lib/swift/${swiftOs}"
    "-Xcc -I${Foundation}/lib/swift"
    "-I ${Dispatch}/lib/swift/${swiftOs}"
    "-Xcc -fmodule-map-file=${Dispatch}/lib/swift/dispatch/module.modulemap"
    "-Xcc -I${Dispatch}/lib/swift"

    "-L ${Foundation}/lib/swift/${swiftOs}"
    "-L ${Dispatch}/lib/swift/${swiftOs}"
    "-Xlinker -rpath -Xlinker ${Foundation}/lib/swift/${swiftOs}"
    "-Xlinker -rpath -Xlinker ${Dispatch}/lib/swift/${swiftOs}"
  ];
in
builtins.concatStringsSep " " (
  corelibs
  ++ [
    # Linkers record DT_RUNPATH, which unlike DT_RPATH is not used to resolve
    # the dependencies of dependencies, so every library has to name the Swift
    # runtime itself rather than relying on whatever loads it.
    "-Xlinker -rpath -Xlinker ${lib.getLib swift-unwrapped}/lib/swift/${swiftOs}"
  ]
)
