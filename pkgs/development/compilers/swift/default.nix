{
  lib,
  newScope,
  stdenv,
  llvmPackages,
  darwin,
}@args:

# Swift 5.10.1 is the last version that can be bootstrapped from a C++
# compiler alone; 6.x is built from source with a prebuilt host toolchain
# instead (see ./bootstrap), the way rustc is bootstrapped.
#
# Darwin stays on 5.10.1 until the 6.3 tree has been tested there. The
# difference is not incidental: the corelibs the 6.3 tree builds --
# swift-corelibs-{foundation,libdispatch,xctest} -- exist only because Linux
# has no Foundation, and on Darwin they have to give way to the SDK's real
# frameworks.
if stdenv.hostPlatform.isDarwin then import ./5.10 args else import ./6.3 args
