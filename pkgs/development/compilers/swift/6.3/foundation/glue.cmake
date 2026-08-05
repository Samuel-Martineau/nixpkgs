# Foundation only exports its CMake package into the build tree, so provide a
# config describing the installed libraries for dependents such as XCTest and
# swift-testing. The core types moved to swift-foundation in 6.x, so the
# umbrella Foundation module is built on top of the Essentials and
# Internationalization libraries.

foreach(component
    Foundation
    FoundationEssentials
    FoundationInternationalization
    FoundationNetworking
    FoundationXML)
  add_library(${component} SHARED IMPORTED)
  set_property(TARGET ${component} PROPERTY
    IMPORTED_LOCATION "@out@/lib/swift/@swiftOs@/lib${component}@dylibExt@")
  set_property(TARGET ${component} PROPERTY
    INTERFACE_INCLUDE_DIRECTORIES "@out@/lib/swift/@swiftOs@")
endforeach()

add_library(_FoundationICU SHARED IMPORTED)
set_property(TARGET _FoundationICU PROPERTY
  IMPORTED_LOCATION "@out@/lib/swift/@swiftOs@/lib_FoundationICU@dylibExt@")
