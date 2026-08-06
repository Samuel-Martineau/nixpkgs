# swift-build only exports its CMake package into the build tree.
#
# It builds static libraries, installed straight into lib/ because the
# variable its install rules use for a subdirectory is one we set ourselves.
set(SwiftBuild_MODULES
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

foreach(module ${SwiftBuild_MODULES})
  add_library(SwiftBuild::${module} STATIC IMPORTED)
  set_property(TARGET SwiftBuild::${module} PROPERTY
    IMPORTED_LOCATION "@out@/lib/lib${module}.a")
  set_property(TARGET SwiftBuild::${module} PROPERTY
    INTERFACE_INCLUDE_DIRECTORIES "@out@/lib/swift/@swiftOs@")
endforeach()

# The project compiles with -disable-autolink-library for every one of these
# modules, so nothing records which archives a dependent needs and the linker
# is given no way to discover them. Rather than restate a dependency graph
# that upstream never writes down, let each module pull in all the others:
# these are static archives from a single project, so the linker discards what
# no one references.
foreach(module ${SwiftBuild_MODULES})
  set(_interface)
  foreach(other ${SwiftBuild_MODULES})
    if(NOT module STREQUAL other)
      list(APPEND _interface SwiftBuild::${other})
    endif()
  endforeach()
  set_property(TARGET SwiftBuild::${module} PROPERTY
    INTERFACE_LINK_LIBRARIES ${_interface})
endforeach()

# SWBCSupport is C++ (it wraps libclang), and swiftc does not put the C++
# runtime on the link line of a Swift executable.
set_property(TARGET SwiftBuild::SWBCSupport APPEND PROPERTY
  INTERFACE_LINK_LIBRARIES stdc++)
