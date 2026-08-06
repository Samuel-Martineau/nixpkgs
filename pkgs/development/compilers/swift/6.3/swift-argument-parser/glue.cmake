# swift-argument-parser only exports its CMake package into the build tree.
add_library(ArgumentParser SHARED IMPORTED)
set_property(TARGET ArgumentParser PROPERTY
  IMPORTED_LOCATION "@out@/lib/libArgumentParser@dylibExt@")
set_property(TARGET ArgumentParser PROPERTY
  INTERFACE_INCLUDE_DIRECTORIES "@out@/lib/swift/@swiftOs@")
