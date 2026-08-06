# swift-tools-protocols only exports its CMake package into the build tree.
#
# It builds static libraries, installed straight into lib/ because the
# variable its install rules use for a subdirectory is one we set ourselves.
foreach(module
    ToolsProtocolsSwiftExtensions
    SKLogging
    LanguageServerProtocol
    LanguageServerProtocolTransport
    BuildServerProtocol)
  add_library(SwiftToolsProtocols::${module} STATIC IMPORTED)
  set_property(TARGET SwiftToolsProtocols::${module} PROPERTY
    IMPORTED_LOCATION "@out@/lib/lib${module}.a")
  set_property(TARGET SwiftToolsProtocols::${module} PROPERTY
    INTERFACE_INCLUDE_DIRECTORIES "@out@/lib/swift/@swiftOs@")
endforeach()

# A header-only C module, so there is no library to point at.
add_library(SwiftToolsProtocols::ToolsProtocolsCAtomics INTERFACE IMPORTED)
set_property(TARGET SwiftToolsProtocols::ToolsProtocolsCAtomics PROPERTY
  INTERFACE_INCLUDE_DIRECTORIES "@dev@/include/ToolsProtocolsCAtomics")

# BuildServerProtocol is built on top of the LSP types, and both log through
# SKLogging.
set_property(TARGET SwiftToolsProtocols::BuildServerProtocol PROPERTY
  INTERFACE_LINK_LIBRARIES SwiftToolsProtocols::LanguageServerProtocol)
set_property(TARGET SwiftToolsProtocols::LanguageServerProtocolTransport PROPERTY
  INTERFACE_LINK_LIBRARIES SwiftToolsProtocols::LanguageServerProtocol)
