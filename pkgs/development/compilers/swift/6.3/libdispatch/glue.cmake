add_library(dispatch SHARED IMPORTED)
set_property(TARGET dispatch PROPERTY IMPORTED_LOCATION "@out@/@libSubdir@/libdispatch@dylibExt@")
# dispatch/dispatch.h and Block.h, which CoreFoundation includes directly.
set_property(TARGET dispatch PROPERTY INTERFACE_INCLUDE_DIRECTORIES @headerDirs@)

add_library(BlocksRuntime SHARED IMPORTED)
set_property(TARGET BlocksRuntime PROPERTY IMPORTED_LOCATION "@out@/@libSubdir@/libBlocksRuntime@dylibExt@")

add_library(swiftDispatch SHARED IMPORTED)
set_property(TARGET swiftDispatch PROPERTY IMPORTED_LOCATION "@out@/@libSubdir@/libswiftDispatch@dylibExt@")
