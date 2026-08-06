{
  lib,
  stdenv,
  callPackage,
  cmake,
  ninja,
  git,
  sqlite,
  ncurses,
  makeWrapper,
  swift,
  swift-unwrapped,
  swiftSearchFlags,
  swift-argument-parser,
  swift-asn1,
  swift-build,
  swift-certificates,
  swift-collections,
  swift-crypto,
  swift-driver,
  swift-llbuild,
  swift-system,
  swift-tools-protocols,
  swift-tools-support-core,
  Foundation,
  Dispatch,
  XCTest,
}:

# The Swift Package Manager, built in the two stages upstream uses.
#
# SwiftPM is itself a SwiftPM package, so it cannot be built by SwiftPM until
# one exists. Upstream breaks the circle by keeping a second build description
# in CMake, used only for bootstrapping; the result then builds SwiftPM the
# intended way. The second stage is not optional: `PackageDescription` and
# `PackagePlugin`, which every package manifest and build plugin in the world
# compiles against, are products of SwiftPM's own package graph and are laid
# out by its own build.
#
# The second stage resolves nothing over the network. Setting
# SWIFTCI_USE_LOCAL_DEPS makes every package in the graph take its
# dependencies from sibling directories instead of Git, so the sources below
# are simply unpacked next to each other. That also sidesteps the dependencies
# pinned to branches rather than revisions, which SwiftPM re-resolves even from
# a valid vendored workspace state.

let
  sources = callPackage ../sources.nix { };
  inherit (swift-unwrapped) swiftOs;

  # The directory names Package.swift expects for `.package(path: "../…")`.
  # Note llbuild is not named swift-llbuild here.
  siblings = {
    llbuild = sources.swift-llbuild;
    swift-argument-parser = sources.swift-argument-parser;
    swift-asn1 = sources.swift-asn1;
    swift-build = sources.swift-build;
    swift-certificates = sources.swift-certificates;
    swift-collections = sources.swift-collections;
    swift-crypto = sources.swift-crypto;
    swift-driver = sources.swift-driver;
    swift-syntax = sources.swift-syntax;
    swift-system = sources.swift-system;
    swift-toolchain-sqlite = sources.swift-toolchain-sqlite;
    swift-tools-protocols = sources.swift-tools-protocols;
    swift-tools-support-core = sources.swift-tools-support-core;
  };

  unpackSiblings = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (name: src: ''
      cp -r ${src} ${name}
      chmod -R u+w ${name}
    '') siblings
  );

  commonAttrs = {
    inherit (sources) version;
    src = sources.swift-package-manager;

    postPatch = ''
      # The location of xcrun is hardcoded; PATH lookup is what works here.
      find Sources -name '*.swift' | xargs sed -i -e 's|/usr/bin/xcrun|xcrun|g'
    '';
  };

  # Stage one: built by CMake, so it needs no package manager. Used only to
  # build the real thing.
  swiftpm-bootstrap = stdenv.mkDerivation (
    commonAttrs
    // {
      pname = "swiftpm-bootstrap";

      nativeBuildInputs = [
        cmake
        ninja
      ];

      buildInputs = [
        sqlite
        swift-argument-parser
        swift-asn1
        swift-build
        swift-certificates
        swift-collections
        swift-crypto
        swift-driver
        swift-llbuild
        swift-system
        swift-tools-protocols
        swift-tools-support-core
        Foundation
        Dispatch
      ];

      cmakeFlags = [
        (lib.cmakeFeature "CMAKE_Swift_COMPILER" "${swift-unwrapped}/bin/swiftc")
        (lib.cmakeFeature "dispatch_DIR" "${lib.getDev Dispatch}/lib/cmake/dispatch")
        (lib.cmakeFeature "Foundation_DIR" "${lib.getDev Foundation}/lib/cmake/Foundation")
        (lib.cmakeFeature "ArgumentParser_DIR" "${lib.getDev swift-argument-parser}/lib/cmake/ArgumentParser")
        (lib.cmakeFeature "LLBuild_DIR" "${swift-llbuild}/lib/cmake/llbuild")
        (lib.cmakeFeature "SwiftASN1_DIR" "${lib.getDev swift-asn1}/lib/cmake/SwiftASN1")
        (lib.cmakeFeature "SwiftBuild_DIR" "${lib.getDev swift-build}/lib/cmake/SwiftBuild")
        (lib.cmakeFeature "SwiftCertificates_DIR" "${lib.getDev swift-certificates}/lib/cmake/SwiftCertificates")
        (lib.cmakeFeature "SwiftCollections_DIR" "${lib.getDev swift-collections}/lib/cmake/SwiftCollections")
        (lib.cmakeFeature "SwiftCrypto_DIR" "${lib.getDev swift-crypto}/lib/cmake/SwiftCrypto")
        (lib.cmakeFeature "SwiftDriver_DIR" "${swift-driver}/lib/cmake/SwiftDriver")
        (lib.cmakeFeature "SwiftSystem_DIR" "${lib.getDev swift-system}/lib/cmake/SwiftSystem")
        (lib.cmakeFeature "SwiftToolsProtocols_DIR" "${lib.getDev swift-tools-protocols}/lib/cmake/SwiftToolsProtocols")
        (lib.cmakeFeature "TSC_DIR" "${lib.getDev swift-tools-support-core}/lib/cmake/TSC")
      ];

      preConfigure = ''
        cmakeFlagsArray+=("-DCMAKE_Swift_FLAGS=${swiftSearchFlags}")
      '';
    }
  );
in
stdenv.mkDerivation (
  commonAttrs
  // {
    pname = "swiftpm";

    nativeBuildInputs = [
      makeWrapper
      swift
      swiftpm-bootstrap
    ];

    buildInputs = [
      ncurses
      sqlite
      Foundation
      Dispatch
      XCTest
    ];

    postUnpack = ''
      # Every package in this graph resolves its dependencies from sibling
      # directories when SWIFTCI_USE_LOCAL_DEPS is set, so lay them out.
      pushd ..
      ${unpackSiblings}
      popd
    '';

    configurePhase = ''
      runHook preConfigure
      export SWIFTCI_USE_LOCAL_DEPS=1
      export HOME="$TMPDIR"
      runHook postConfigure
    '';

    buildPhase = ''
      runHook preBuild
      TERM=dumb swift-build -c release --disable-sandbox
      runHook postBuild
    '';

    # Derived from Utilities/bootstrap, see install_swiftpm.
    installPhase = ''
      runHook preInstall

      binPath="$(swift-build --show-bin-path -c release --disable-sandbox)"
      mkdir -p $out/bin $out/lib/swift

      cp "$binPath/swift-package-manager" $out/bin/swift-package
      wrapProgram $out/bin/swift-package --prefix PATH : ${lib.makeBinPath [ git ]}
      for tool in swift-build swift-test swift-run swift-package-collection; do
        ln -s $out/bin/swift-package $out/bin/$tool
      done

      # The libraries every package manifest and build plugin is compiled
      # against.
      installSwiftpmModule() {
        mkdir -p $out/lib/swift/pm/$2
        cp "$binPath/lib$1${stdenv.hostPlatform.extensions.sharedLibrary}" $out/lib/swift/pm/$2/
        if [ -f "$binPath/$1.swiftinterface" ]; then
          cp "$binPath/$1.swiftinterface" $out/lib/swift/pm/$2/
        else
          cp -r "$binPath/$1.swiftmodule" $out/lib/swift/pm/$2/
        fi
        cp "$binPath/$1.swiftdoc" $out/lib/swift/pm/$2/
      }
      installSwiftpmModule PackageDescription ManifestAPI
      installSwiftpmModule PackagePlugin PluginAPI

      runHook postInstall
    '';

    passthru = { inherit swiftpm-bootstrap; };

    meta = {
      description = "Package manager for the Swift programming language";
      homepage = "https://github.com/swiftlang/swift-package-manager";
      mainProgram = "swift-package";
      platforms = lib.platforms.linux;
      license = lib.licenses.asl20;
      teams = [ lib.teams.swift ];
    };
  }
)
