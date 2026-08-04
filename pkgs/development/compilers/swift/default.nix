{
  lib,
  newScope,
  stdenv,
  llvmPackages,
  darwin,
}@args:

# Swift 5.10.1 is the last version that can be bootstrapped from a C++
# compiler alone and (for now) the version used on Darwin. Linux is being
# migrated to Swift 6.3, built from source with a prebuilt host toolchain
# (see ./bootstrap). Once the 6.3 tree exists, non-Darwin platforms will
# import it here instead.
import ./5.10 args
