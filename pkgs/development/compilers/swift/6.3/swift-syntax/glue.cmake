# swift-syntax only exports its CMake package into the build tree.
#
# The modules are installed alongside the libraries in lib/swift/host, but
# only because the derivation puts them there: upstream installs the
# libraries and leaves the module interfaces in the build tree.
foreach(module
    SwiftBasicFormat
    SwiftCompilerPluginMessageHandling
    SwiftDiagnostics
    SwiftIDEUtils
    SwiftIfConfig
    SwiftLexicalLookup
    SwiftLibraryPluginProvider
    SwiftOperators
    SwiftParser
    SwiftParserDiagnostics
    SwiftRefactor
    SwiftSyntax
    SwiftSyntaxBuilder
    SwiftSyntaxMacroExpansion
    SwiftSyntaxMacros)
  add_library(SwiftSyntax::${module} SHARED IMPORTED)
  set_property(TARGET SwiftSyntax::${module} PROPERTY
    IMPORTED_LOCATION "@out@/lib/swift/host/lib${module}@dylibExt@")
  set_property(TARGET SwiftSyntax::${module} PROPERTY
    INTERFACE_INCLUDE_DIRECTORIES "@out@/lib/swift/host")
endforeach()
