# swift-build only exports its CMake package into the build tree.
#
# It builds static libraries, installed straight into lib/ because the
# variable its install rules use for a subdirectory is one we set ourselves.
foreach(module
    SWBCSupport
    SWBCLibc
    SWBLibc
    SWBUtil
    SWBMacro
    SWBProtocol
    SWBServiceCore
    SWBCAS
    SWBLLBuild
    SWBCore
    SWBTaskConstruction
    SWBTaskExecution
    SWBBuildSystem
    SWBAndroidPlatform
    SWBApplePlatform
    SWBGenericUnixPlatform
    SWBQNXPlatform
    SWBUniversalPlatform
    SWBWebAssemblyPlatform
    SWBWindowsPlatform
    SWBBuildService
    SWBProjectModel
    SwiftBuild)
  add_library(SwiftBuild::${module} STATIC IMPORTED)
  set_property(TARGET SwiftBuild::${module} PROPERTY
    IMPORTED_LOCATION "@out@/lib/lib${module}.a")
  set_property(TARGET SwiftBuild::${module} PROPERTY
    INTERFACE_INCLUDE_DIRECTORIES "@out@/lib/swift/@swiftOs@")
endforeach()
