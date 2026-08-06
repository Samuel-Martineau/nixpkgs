# swift-collections only exports its CMake package into the build tree.
#
# It builds static libraries on Linux, which is why they land under
# lib/swift_static rather than lib/swift. Every module but
# InternalCollectionsUtilities links it, so name it in their link interface
# rather than leaving dependents to discover it.
foreach(module
    InternalCollectionsUtilities
    BitCollections
    Collections
    DequeModule
    HashTreeCollections
    HeapModule
    OrderedCollections
    _RopeModule)
  add_library(SwiftCollections::${module} STATIC IMPORTED)
  set_property(TARGET SwiftCollections::${module} PROPERTY
    IMPORTED_LOCATION "@out@/lib/swift_static/@swiftOs@/lib${module}.a")
  set_property(TARGET SwiftCollections::${module} PROPERTY
    INTERFACE_INCLUDE_DIRECTORIES "@out@/lib/swift_static/@swiftOs@")
  if(NOT module STREQUAL InternalCollectionsUtilities)
    set_property(TARGET SwiftCollections::${module} PROPERTY
      INTERFACE_LINK_LIBRARIES SwiftCollections::InternalCollectionsUtilities)
  endif()
endforeach()
