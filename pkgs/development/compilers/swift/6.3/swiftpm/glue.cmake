# SwiftPM only exports its CMake package into the build tree.
#
# sourcekit-lsp links these to read a package's structure. They are shared
# libraries installed in lib/, with the modules placed alongside by the
# derivation because SwiftPM installs only the libraries.
set(SwiftPM_MODULES
    _AsyncFileSystem
    Basics
    Build
    Commands
    CoreCommands
    DriverSupport
    PackageCollections
    PackageCollectionsModel
    PackageCollectionsSigning
    PackageGraph
    PackageLoading
    PackageModel
    PackageRegistryCommand
    QueryEngine
    SourceControl
    SPMBuildCore
    SwiftSDKCommand
    Workspace)

foreach(module ${SwiftPM_MODULES})
  add_library(SwiftPM::${module} SHARED IMPORTED)
  set_property(TARGET SwiftPM::${module} PROPERTY
    IMPORTED_LOCATION "@out@/lib/lib${module}@dylibExt@")
  set_property(TARGET SwiftPM::${module} PROPERTY
    INTERFACE_INCLUDE_DIRECTORIES "@out@/lib/swift/@swiftOs@")
endforeach()

# SourceKitLSPAPI is a module without a library of its own: its code is built
# into Build, so dependents need the module path and that library.
add_library(SwiftPM::SourceKitLSPAPI INTERFACE IMPORTED)
set_property(TARGET SwiftPM::SourceKitLSPAPI PROPERTY
  INTERFACE_INCLUDE_DIRECTORIES "@out@/lib/swift/@swiftOs@")
set_property(TARGET SwiftPM::SourceKitLSPAPI PROPERTY
  INTERFACE_LINK_LIBRARIES SwiftPM::Build)
