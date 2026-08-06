{
  lib,
  stdenv,
  callPackage,
  cmake,
  ninja,
  substituteAll,
  swift-unwrapped,
  swiftSearchFlags,
  swift-asn1,
  Foundation,
  Dispatch,
}:

# Swift bindings for cryptographic operations, over a vendored BoringSSL.
# SwiftPM uses it to check the signatures of downloaded artifacts.

let
  sources = callPackage ../sources.nix { };
  inherit (swift-unwrapped) swiftOs swiftArch;
in
stdenv.mkDerivation {
  pname = "swift-crypto";

  version = sources.pinnedVersions.swift-crypto;
  src = sources.swift-crypto;

  outputs = [
    "out"
    "dev"
  ];

  nativeBuildInputs = [
    cmake
    ninja
  ];

  buildInputs = [
    swift-asn1
    Foundation
    Dispatch
  ];

  cmakeFlags = [
    (lib.cmakeFeature "CMAKE_Swift_COMPILER" "${swift-unwrapped}/bin/swiftc")
    (lib.cmakeFeature "dispatch_DIR" "${lib.getDev Dispatch}/lib/cmake/dispatch")
    (lib.cmakeFeature "Foundation_DIR" "${lib.getDev Foundation}/lib/cmake/Foundation")
    (lib.cmakeFeature "SwiftASN1_DIR" "${lib.getDev swift-asn1}/lib/cmake/SwiftASN1")
  ];

  preConfigure = ''
    # The modules of these packages are installed under an architecture
    # subdirectory, unlike the libraries beside them.
    cmakeFlagsArray+=(
      "-DCMAKE_Swift_FLAGS=${swiftSearchFlags} -I ${swift-asn1}/lib/swift/${swiftOs}/${swiftArch} -L ${swift-asn1}/lib/swift/${swiftOs} -Xlinker -rpath -Xlinker ${swift-asn1}/lib/swift/${swiftOs}"
    )
  '';

  postInstall = ''
    # Only the Crypto module is installed, but dependents link more than that:
    # swift-certificates uses _CryptoExtras, and both rest on the vendored
    # BoringSSL and its wrapper, which are static.
    libraries=$(find . \( -name 'lib_CryptoExtras*' -o -name 'libCryptoBoringWrapper.a' \
      -o -name 'libCCryptoBoringSSL*.a' \) -not -path '*/CMakeFiles/*')
    [ -n "$libraries" ] || { echo "error: no extra crypto libraries were built" >&2; exit 1; }
    echo "$libraries" | xargs -I{} cp {} $out/lib/swift/${swiftOs}/

    # Take these from the module directory rather than searching the build
    # tree: the per-source partial modules are also named *.swiftmodule, and
    # there are a hundred of them.
    cp swift/*.swiftmodule swift/*.swiftdoc $out/lib/swift/${swiftOs}/${swiftArch}/

    for expected in lib_CryptoExtras${stdenv.hostPlatform.extensions.sharedLibrary} \
      libCryptoBoringWrapper.a libCCryptoBoringSSL.a libCCryptoBoringSSLShims.a; do
      [ -e "$out/lib/swift/${swiftOs}/$expected" ] \
        || { echo "error: $expected was not installed" >&2; exit 1; }
    done

    # Copying straight out of the build tree skips the rewrite CMake does when
    # it installs a target, so this library still points at the build
    # directory. Give it the paths the installed one gets.
    patchelf --set-rpath \
      '$ORIGIN'":${lib.getLib swift-unwrapped}/lib/swift/${swiftOs}:${Foundation}/lib/swift/${swiftOs}:${Dispatch}/lib/swift/${swiftOs}:${swift-asn1}/lib/swift/${swiftOs}" \
      $out/lib/swift/${swiftOs}/lib_CryptoExtras${stdenv.hostPlatform.extensions.sharedLibrary}

    # Only exports its CMake package into the build tree.
    mkdir -p $dev/lib/cmake/SwiftCrypto
    export dylibExt="${stdenv.hostPlatform.extensions.sharedLibrary}"
    export swiftOs="${swiftOs}"
    export swiftArch="${swiftArch}"
    substituteAll ${./glue.cmake} $dev/lib/cmake/SwiftCrypto/SwiftCryptoConfig.cmake
  '';

  meta = {
    description = "Open-source implementation of Apple CryptoKit's API";
    homepage = "https://github.com/apple/swift-crypto";
    platforms = lib.platforms.linux;
    license = lib.licenses.asl20;
    teams = [ lib.teams.swift ];
  };
}
