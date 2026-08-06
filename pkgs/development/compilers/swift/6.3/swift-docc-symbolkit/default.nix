{
  lib,
  stdenv,
  callPackage,
  cmake,
  ninja,
  substituteAll,
  swift-unwrapped,
  swiftSearchFlags,
  corelibsBuildInputs,
  corelibsCmakeFlags,
  Foundation,
  Dispatch,
}:

# The symbol graph format swift-docc and sourcekit-lsp read.

let
  sources = callPackage ../sources.nix { };
  inherit (swift-unwrapped) swiftOs;
in
stdenv.mkDerivation {
  pname = "swift-docc-symbolkit";

  inherit (sources) version;
  src = sources.swift-docc-symbolkit;

  outputs = [
    "out"
    "dev"
  ];

  nativeBuildInputs = [
    cmake
    ninja
  ];

  buildInputs = [
  ]
  ++ corelibsBuildInputs;

  cmakeFlags = [
    (lib.cmakeFeature "CMAKE_Swift_COMPILER" "${swift-unwrapped}/bin/swiftc")
  ]
  ++ corelibsCmakeFlags
  ++ [
  ];

  preConfigure = ''
    cmakeFlagsArray+=("-DCMAKE_Swift_FLAGS=${swiftSearchFlags}")
  '';

  # This project has no install rules whatsoever -- upstream only ever builds
  # it as part of a larger tree and refers to the build directory -- so
  # everything is placed by hand from where its CMakeLists puts it.
  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib $out/lib/swift/${swiftOs}
    cp lib/libSymbolKit.* $out/lib/
    cp swift/SymbolKit.swiftmodule swift/SymbolKit.swiftdoc $out/lib/swift/${swiftOs}/

    runHook postInstall
  '';

  postInstall = ''
    # Only exports its CMake package into the build tree.
    mkdir -p $dev/lib/cmake/SymbolKit
    export swiftOs="${swiftOs}"
    substituteAll ${./glue.cmake} $dev/lib/cmake/SymbolKit/SymbolKitConfig.cmake
  '';

  meta = {
    description = "Symbol graph format used by Swift documentation tools";
    homepage = "https://github.com/swiftlang/swift-docc-symbolkit";
    platforms = lib.platforms.linux;
    license = lib.licenses.asl20;
    teams = [ lib.teams.swift ];
  };
}
