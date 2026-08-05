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

    swift-llvm = callPackage ./llvm {
      inherit (llvmPackages) stdenv;
    };

    swift-unwrapped = callPackage ./compiler {
      inherit (llvmPackages) stdenv clang;
    };

    foundation-macros = callPackage ./foundation-macros {
      inherit (llvmPackages) stdenv;
    };

    Dispatch = callPackage ./libdispatch {
      inherit (llvmPackages) stdenv;
      # TODO: build the Swift overlay once the wrapper is migrated.
      useSwift = false;
      swift = null;
    };

    # Components are added here as they are migrated to 6.3:
    # wrapper, Foundation, XCTest, swift-testing, swiftpm, swift-driver,
    # sourcekit-lsp, swift-docc, swift-format.
  };
in
self
