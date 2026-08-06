{
  lib,
  stdenv,
  callPackage,
  cmake,
  ninja,
  substituteAll,
  swift-unwrapped,
  swiftSearchFlags,
  corelibsCmakeFlags,
  Foundation,
  Dispatch,
}:

# ASN.1 and DER support, used by swift-crypto and swift-certificates to verify
# the signatures on binary artifacts SwiftPM downloads.

let
  sources = callPackage ../sources.nix { };
in
stdenv.mkDerivation {
  pname = "swift-asn1";

  version = sources.pinnedVersions.swift-asn1;
  src = sources.swift-asn1;

  outputs = [
    "out"
    "dev"
  ];

  nativeBuildInputs = [
    cmake
    ninja
  ];

  buildInputs = [
    Foundation
    Dispatch
  ];

  cmakeFlags = [
    (lib.cmakeFeature "CMAKE_Swift_COMPILER" "${swift-unwrapped}/bin/swiftc")
  ]
  ++ corelibsCmakeFlags;

  preConfigure = ''
    cmakeFlagsArray+=("-DCMAKE_Swift_FLAGS=${swiftSearchFlags}")
  '';

  postInstall = ''
    # Only exports its CMake package into the build tree.
    mkdir -p $dev/lib/cmake/SwiftASN1
    export dylibExt="${stdenv.hostPlatform.extensions.sharedLibrary}"
    export swiftOs="${swift-unwrapped.swiftOs}"
    export swiftArch="${swift-unwrapped.swiftArch}"
    substituteAll ${./glue.cmake} $dev/lib/cmake/SwiftASN1/SwiftASN1Config.cmake
  '';

  meta = {
    description = "ASN.1 and DER implementation in Swift";
    homepage = "https://github.com/apple/swift-asn1";
    platforms = lib.platforms.linux;
    license = lib.licenses.asl20;
    teams = [ lib.teams.swift ];
  };
}
