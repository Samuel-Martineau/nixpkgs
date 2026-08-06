# swift-driver only exports its CMake package into the build tree. It exports
# without a namespace, so dependents refer to the targets by their bare names.
foreach(module SwiftDriver SwiftDriverExecution SwiftOptions)
  add_library(${module} SHARED IMPORTED)
  set_property(TARGET ${module} PROPERTY
    IMPORTED_LOCATION "@out@/lib/lib${module}@dylibExt@")
  set_property(TARGET ${module} PROPERTY
    INTERFACE_INCLUDE_DIRECTORIES "@out@/lib/swift/@swiftOs@")
endforeach()

set_property(TARGET SwiftDriver PROPERTY
  INTERFACE_LINK_LIBRARIES SwiftOptions)
set_property(TARGET SwiftDriverExecution PROPERTY
  INTERFACE_LINK_LIBRARIES SwiftDriver)
