# swift-tools-support-core only exports its CMake package into the build tree.
foreach(component TSCBasic TSCUtility)
  add_library(${component} SHARED IMPORTED)
  set_property(TARGET ${component} PROPERTY
    IMPORTED_LOCATION "@out@/lib/lib${component}@dylibExt@")
  set_property(TARGET ${component} PROPERTY
    INTERFACE_INCLUDE_DIRECTORIES "@out@/lib/swift/@swiftOs@")
endforeach()

# These are built static and are not installed by upstream.
foreach(component TSCLibc TSCclibc)
  add_library(${component} STATIC IMPORTED)
  set_property(TARGET ${component} PROPERTY
    IMPORTED_LOCATION "@out@/lib/lib${component}.a")
  set_property(TARGET ${component} PROPERTY
    INTERFACE_INCLUDE_DIRECTORIES "@out@/lib/swift/@swiftOs@")
endforeach()
