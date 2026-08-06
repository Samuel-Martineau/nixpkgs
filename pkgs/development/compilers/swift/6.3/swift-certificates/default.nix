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
  swift-crypto,
  Foundation,
  Dispatch,
}:

# X.509 certificate handling. SwiftPM uses it to validate the signatures on
# binary artifacts and registry packages.

let
  sources = callPackage ../sources.nix { };
  inherit (swift-unwrapped) swiftOs swiftArch;
in
stdenv.mkDerivation {
  pname = "swift-certificates";

  version = sources.pinnedVersions.swift-certificates;
  src = sources.swift-certificates;

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
    swift-crypto
    Foundation
    Dispatch
  ];

  cmakeFlags = [
    (lib.cmakeFeature "CMAKE_Swift_COMPILER" "${swift-unwrapped}/bin/swiftc")
    (lib.cmakeFeature "dispatch_DIR" "${lib.getDev Dispatch}/lib/cmake/dispatch")
    (lib.cmakeFeature "Foundation_DIR" "${lib.getDev Foundation}/lib/cmake/Foundation")
    (lib.cmakeFeature "SwiftASN1_DIR" "${lib.getDev swift-asn1}/lib/cmake/SwiftASN1")
    (lib.cmakeFeature "SwiftCrypto_DIR" "${lib.getDev swift-crypto}/lib/cmake/SwiftCrypto")
  ];

  preConfigure = ''
    # The modules of these packages are installed under an architecture
    # subdirectory, unlike the libraries beside them.
    cmakeFlagsArray+=(
      "-DCMAKE_Swift_FLAGS=${swiftSearchFlags} -I ${swift-asn1}/lib/swift/${swiftOs}/${swiftArch} -I ${swift-crypto}/lib/swift/${swiftOs}/${swiftArch} -L ${swift-asn1}/lib/swift/${swiftOs} -L ${swift-crypto}/lib/swift/${swiftOs} -Xlinker -rpath -Xlinker ${swift-asn1}/lib/swift/${swiftOs} -Xlinker -rpath -Xlinker ${swift-crypto}/lib/swift/${swiftOs}"
    )
  '';

  postInstall = ''
    # Only exports its CMake package into the build tree.
    mkdir -p $dev/lib/cmake/SwiftCertificates
    export dylibExt="${stdenv.hostPlatform.extensions.sharedLibrary}"
    export swiftOs="${swiftOs}"
    export swiftArch="${swiftArch}"
    substituteAll ${./glue.cmake} $dev/lib/cmake/SwiftCertificates/SwiftCertificatesConfig.cmake
  '';

  meta = {
    description = "Implementation of X.509 certificate handling in Swift";
    homepage = "https://github.com/apple/swift-certificates";
    platforms = lib.platforms.linux;
    license = lib.licenses.asl20;
    teams = [ lib.teams.swift ];
  };
}
