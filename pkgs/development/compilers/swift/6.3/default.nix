{
  lib,
  newScope,
  stdenv,
  llvmPackages,
  darwin,
}:

# Swift 6.3 toolchain, built from source using a prebuilt host toolchain
# (../bootstrap) in the same way rustc is bootstrapped. Linux-only for now;
# Darwin remains on ../5.10.
let
  self = rec {

    callPackage = newScope self;

    # Provided for backwards compatibility.
    inherit stdenv;

    sources = callPackage ./sources.nix { };

    swift-bootstrap = callPackage ../bootstrap { };

    # Components are added here as they are migrated to 6.3:
    # swift-unwrapped, wrapper, Dispatch, Foundation, XCTest, swift-testing,
    # swiftpm, swift-driver, sourcekit-lsp, swift-docc, swift-format.
  };
in
self
