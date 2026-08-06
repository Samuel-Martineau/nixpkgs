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

    # libdispatch without its Swift overlay. The compiler links against this
    # one, since building the overlay needs a working Swift compiler.
    dispatch-minimal = callPackage ./libdispatch {
      inherit (llvmPackages) stdenv;
      useSwift = false;
      swift = null;
    };

    swift-unwrapped = callPackage ./compiler {
      inherit (llvmPackages) stdenv clang;
      Dispatch = dispatch-minimal;
    };

    foundation-macros = callPackage ./foundation-macros {
      inherit (llvmPackages) stdenv;
    };

    # The full libdispatch, with the Dispatch module for Swift code.
    Dispatch = callPackage ./libdispatch {
      inherit (llvmPackages) stdenv;
      swift = swift-unwrapped;
    };

    Foundation = callPackage ./foundation {
      inherit (llvmPackages) stdenv;
    };

    swiftSearchFlags = callPackage ./swift-search-flags.nix { };

    swift-argument-parser = callPackage ./swift-argument-parser {
      inherit (llvmPackages) stdenv;
    };

    swift-llbuild = callPackage ./swift-llbuild {
      inherit (llvmPackages) stdenv;
    };

    swift-tools-support-core = callPackage ./swift-tools-support-core {
      inherit (llvmPackages) stdenv;
    };

    swift-driver = callPackage ./swift-driver {
      inherit (llvmPackages) stdenv;
    };

    # Pinned dependencies SwiftPM and swift-build are built against. Upstream
    # builds these as part of the same CMake bootstrap and never installs
    # them, so each needs a hand-written CMake package (glue.cmake) describing
    # what it installed.
    swift-system = callPackage ./swift-system {
      inherit (llvmPackages) stdenv;
    };

    swift-collections = callPackage ./swift-collections {
      inherit (llvmPackages) stdenv;
    };

    swift-tools-protocols = callPackage ./swift-tools-protocols {
      inherit (llvmPackages) stdenv;
    };

    swift-asn1 = callPackage ./swift-asn1 {
      inherit (llvmPackages) stdenv;
    };

    swift-crypto = callPackage ./swift-crypto {
      inherit (llvmPackages) stdenv;
    };

    swift-certificates = callPackage ./swift-certificates {
      inherit (llvmPackages) stdenv;
    };

    # The build engine SwiftPM 6 delegates to.
    swift-build = callPackage ./swift-build {
      inherit (llvmPackages) stdenv;
    };

    swift = callPackage ./wrapper {
      inherit (llvmPackages) clang;
      swift = swift-unwrapped;
    };

    XCTest = callPackage ./xctest {
      inherit (llvmPackages) stdenv;
    };

    swift-testing = callPackage ./swift-testing {
      inherit (llvmPackages) stdenv;
    };

    swiftpm = callPackage ./swiftpm {
      inherit (llvmPackages) stdenv;
    };

    # Documentation toolchain: swift-docc, swift-format and sourcekit-lsp are
    # built on these.
    swift-cmark = callPackage ./swift-cmark {
      inherit (llvmPackages) stdenv;
    };

    swift-docc-symbolkit = callPackage ./swift-docc-symbolkit {
      inherit (llvmPackages) stdenv;
    };

    # Components are added here as they are migrated to 6.3:
    # sourcekit-lsp, swift-docc, swift-format.
  };
in
self
