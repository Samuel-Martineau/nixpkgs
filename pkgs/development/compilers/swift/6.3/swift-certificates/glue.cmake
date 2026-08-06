# swift-certificates only exports its CMake package into the build tree,
# without a namespace, so dependents refer to the targets by their bare names.
add_library(X509 SHARED IMPORTED)
set_property(TARGET X509 PROPERTY
  IMPORTED_LOCATION "@out@/lib/swift/@swiftOs@/libX509@dylibExt@")
set_property(TARGET X509 PROPERTY
  INTERFACE_INCLUDE_DIRECTORIES "@out@/lib/swift/@swiftOs@")

add_library(_CertificateInternals SHARED IMPORTED)
set_property(TARGET _CertificateInternals PROPERTY
  IMPORTED_LOCATION "@out@/lib/swift/@swiftOs@/lib_CertificateInternals@dylibExt@")
set_property(TARGET _CertificateInternals PROPERTY
  INTERFACE_INCLUDE_DIRECTORIES "@out@/lib/swift/@swiftOs@")

set_property(TARGET X509 PROPERTY
  INTERFACE_LINK_LIBRARIES _CertificateInternals)
