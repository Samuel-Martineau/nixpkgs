# swift-docc only exports its CMake package into the build tree, and installs
# only its executable, so this describes what the derivation placed alongside.
# The libraries are static.
foreach(module SwiftDocC DocCCommon DocCHTML DocCCommandLine)
  add_library(SwiftDocC::${module} STATIC IMPORTED)
  set_property(TARGET SwiftDocC::${module} PROPERTY
    IMPORTED_LOCATION "@out@/lib/lib${module}.a")
  set_property(TARGET SwiftDocC::${module} PROPERTY
    INTERFACE_INCLUDE_DIRECTORIES "@out@/lib/swift/@swiftOs@")
endforeach()
