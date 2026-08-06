# swift-markdown only exports its CMake package into the build tree, and has
# no install rules at all, so this describes what the derivation placed.
# Both libraries are static, and the Swift module does not carry the atomics
# shim along the way a shared library would.
add_library(SwiftMarkdown::Markdown STATIC IMPORTED)
set_property(TARGET SwiftMarkdown::Markdown PROPERTY
  IMPORTED_LOCATION "@out@/lib/libMarkdown.a")
set_property(TARGET SwiftMarkdown::Markdown PROPERTY
  INTERFACE_INCLUDE_DIRECTORIES "@out@/lib/swift/@swiftOs@")

add_library(SwiftMarkdown::CAtomic STATIC IMPORTED)
set_property(TARGET SwiftMarkdown::CAtomic PROPERTY
  IMPORTED_LOCATION "@out@/lib/libCAtomic.a")

set_property(TARGET SwiftMarkdown::Markdown PROPERTY
  INTERFACE_LINK_LIBRARIES SwiftMarkdown::CAtomic)
