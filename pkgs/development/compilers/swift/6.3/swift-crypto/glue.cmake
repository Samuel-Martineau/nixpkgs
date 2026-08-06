# swift-crypto only exports its CMake package into the build tree, without a
# namespace, so dependents refer to the targets by their bare names.
#
# The vendored BoringSSL and its wrapper are static, and the Swift modules do
# not carry them along the way a shared library would, so name them in the
# link interface.
foreach(module Crypto _CryptoExtras)
  add_library(${module} SHARED IMPORTED)
  set_property(TARGET ${module} PROPERTY
    IMPORTED_LOCATION "@out@/lib/swift/@swiftOs@/lib${module}@dylibExt@")
  set_property(TARGET ${module} PROPERTY
    INTERFACE_INCLUDE_DIRECTORIES "@out@/lib/swift/@swiftOs@/@swiftArch@")
endforeach()

foreach(module CryptoBoringWrapper CCryptoBoringSSL CCryptoBoringSSLShims)
  add_library(${module} STATIC IMPORTED)
  set_property(TARGET ${module} PROPERTY
    IMPORTED_LOCATION "@out@/lib/swift/@swiftOs@/lib${module}.a")
  set_property(TARGET ${module} PROPERTY
    INTERFACE_INCLUDE_DIRECTORIES "@out@/lib/swift/@swiftOs@/@swiftArch@")
endforeach()

set_property(TARGET Crypto PROPERTY
  INTERFACE_LINK_LIBRARIES CryptoBoringWrapper CCryptoBoringSSL CCryptoBoringSSLShims)
set_property(TARGET _CryptoExtras PROPERTY
  INTERFACE_LINK_LIBRARIES Crypto CryptoBoringWrapper CCryptoBoringSSL CCryptoBoringSSLShims)
