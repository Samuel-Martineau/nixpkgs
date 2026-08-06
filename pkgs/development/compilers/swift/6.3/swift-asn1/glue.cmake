# swift-asn1 only exports its CMake package into the build tree. It exports
# without a namespace, so dependents refer to the target by its bare name.
add_library(SwiftASN1 SHARED IMPORTED)
set_property(TARGET SwiftASN1 PROPERTY
  IMPORTED_LOCATION "@out@/lib/swift/@swiftOs@/libSwiftASN1@dylibExt@")
# The Swift modules are installed under an architecture subdirectory, unlike
# the library beside them.
set_property(TARGET SwiftASN1 PROPERTY
  INTERFACE_INCLUDE_DIRECTORIES "@out@/lib/swift/@swiftOs@/@swiftArch@")
