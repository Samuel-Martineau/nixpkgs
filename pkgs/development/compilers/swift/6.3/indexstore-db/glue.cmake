# indexstore-db only exports its CMake package into the build tree, without a
# namespace, so dependents refer to the target by its bare name.
add_library(IndexStoreDB SHARED IMPORTED)
set_property(TARGET IndexStoreDB PROPERTY
  IMPORTED_LOCATION "@out@/lib/swift/@swiftOs@/libIndexStoreDB@dylibExt@")
set_property(TARGET IndexStoreDB PROPERTY
  INTERFACE_INCLUDE_DIRECTORIES "@out@/lib/swift/@swiftOs@")
