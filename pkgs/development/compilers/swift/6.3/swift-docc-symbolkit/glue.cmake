# swift-docc-symbolkit only exports its CMake package into the build tree, and
# has no install rules at all, so this describes what the derivation placed.
add_library(DocC::SymbolKit STATIC IMPORTED)
set_property(TARGET DocC::SymbolKit PROPERTY
  IMPORTED_LOCATION "@out@/lib/libSymbolKit.a")
set_property(TARGET DocC::SymbolKit PROPERTY
  INTERFACE_INCLUDE_DIRECTORIES "@out@/lib/swift/@swiftOs@")
