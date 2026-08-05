{ Foundation, Dispatch }:

# CMake does not translate the include directories of imported targets into
# Swift search paths, so every package that uses Foundation or libdispatch has
# to be told where to find three separate things: the Swift modules, the module
# maps of the C shims those modules are overlays on, and the same for
# libdispatch.

#
# Importing those modules also makes Swift emit autolink directives naming
# their libraries, so the linker needs to be pointed at them as well, and the
# result needs an rpath to find them at run time.

builtins.concatStringsSep " " [
  "-I ${Foundation}/lib/swift/linux"
  "-Xcc -I${Foundation}/lib/swift"
  "-I ${Dispatch}/lib/swift/linux"
  "-Xcc -fmodule-map-file=${Dispatch}/lib/swift/dispatch/module.modulemap"
  "-Xcc -I${Dispatch}/lib/swift"

  "-L ${Foundation}/lib/swift/linux"
  "-L ${Dispatch}/lib/swift/linux"
  "-Xlinker -rpath -Xlinker ${Foundation}/lib/swift/linux"
  "-Xlinker -rpath -Xlinker ${Dispatch}/lib/swift/linux"
]
