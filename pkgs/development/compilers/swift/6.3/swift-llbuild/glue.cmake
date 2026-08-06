# llbuild only exports its CMake package into the build tree.
find_package(Threads REQUIRED)
find_package(SQLite3 QUIET)

add_library(libllbuild STATIC IMPORTED)
set_property(TARGET libllbuild PROPERTY
  IMPORTED_LOCATION "@out@/lib/libllbuild.a")
set_property(TARGET libllbuild PROPERTY
  INTERFACE_INCLUDE_DIRECTORIES "@out@/include")
add_library(llbuild ALIAS libllbuild)

add_library(llbuildSwift SHARED IMPORTED)
set_property(TARGET llbuildSwift PROPERTY
  IMPORTED_LOCATION "@out@/lib/swift/pm/llbuild/libllbuildSwift@dylibExt@")
set_property(TARGET llbuildSwift PROPERTY
  INTERFACE_INCLUDE_DIRECTORIES "@out@/lib/swift/pm/llbuild")
