# swift-system only exports its CMake package into the build tree.
#
# It builds a static library on Linux, which is why the module lands under
# lib/swift_static rather than lib/swift. SystemPackage is a Swift overlay
# over the CSystem shims, so consumers need both the Swift module and the
# Clang module it overlays.
add_library(SwiftSystem::SystemPackage STATIC IMPORTED)
set_property(TARGET SwiftSystem::SystemPackage PROPERTY
  IMPORTED_LOCATION "@out@/lib/libSystemPackage.a")
set_property(TARGET SwiftSystem::SystemPackage PROPERTY
  INTERFACE_INCLUDE_DIRECTORIES
    "@out@/lib/swift_static/@swiftOs@"
    "@dev@/include/CSystem")
