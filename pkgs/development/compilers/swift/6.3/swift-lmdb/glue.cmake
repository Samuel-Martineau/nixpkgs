# swift-lmdb only exports its CMake package into the build tree, and has no
# install rules at all, so this describes what the derivation placed.
add_library(LMDB::CLMDB STATIC IMPORTED)
set_property(TARGET LMDB::CLMDB PROPERTY
  IMPORTED_LOCATION "@out@/lib/libCLMDB.a")
set_property(TARGET LMDB::CLMDB PROPERTY
  INTERFACE_INCLUDE_DIRECTORIES "@dev@/include/CLMDB")
