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

# Swift implementations of the Language Server Protocol and the Build Server
# Protocol, shared by sourcekit-lsp, swift-build and SwiftPM.

let
  sources = callPackage ../sources.nix { };
in
stdenv.mkDerivation {
  pname = "swift-tools-protocols";

  version = sources.pinnedVersions.swift-tools-protocols;
  src = sources.swift-tools-protocols;

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
  ++ corelibsCmakeFlags
  ++ [
    # The install rules use this as their destination, but nothing sets it:
    # upstream builds this project without ever installing it, and points
    # dependents at the build tree instead.
    (lib.cmakeFeature "swift-tools-protocols_INSTALL_LIBDIR" "lib")
  ];

  preConfigure = ''
    cmakeFlagsArray+=("-DCMAKE_Swift_FLAGS=${swiftSearchFlags}")
  '';

  postInstall = ''
    # For the same reason, the Swift modules dependents import are not
    # installed at all.
    mkdir -p $out/lib/swift/${swift-unwrapped.swiftOs}
    modules=$(find . -name '*.swiftmodule' -not -path '*/CMakeFiles/*')
    [ -n "$modules" ] || { echo "error: no Swift modules were built" >&2; exit 1; }
    echo "$modules" | xargs -I{} cp -r {} $out/lib/swift/${swift-unwrapped.swiftOs}/

    # ToolsProtocolsCAtomics is a header-only C module, so CMake declares it
    # INTERFACE and installs nothing, but swift-build imports it.
    install -Dm444 $src/Sources/ToolsProtocolsCAtomics/include/ToolsProtocolsCAtomics.h \
      $dev/include/ToolsProtocolsCAtomics/ToolsProtocolsCAtomics.h
    install -Dm444 $src/Sources/ToolsProtocolsCAtomics/include/module.modulemap \
      $dev/include/ToolsProtocolsCAtomics/module.modulemap

    # Only exports its CMake package into the build tree.
    mkdir -p $dev/lib/cmake/SwiftToolsProtocols
    export dylibExt="${stdenv.hostPlatform.extensions.sharedLibrary}"
    export swiftOs="${swift-unwrapped.swiftOs}"
    substituteAll ${./glue.cmake} $dev/lib/cmake/SwiftToolsProtocols/SwiftToolsProtocolsConfig.cmake
  '';

  meta = {
    description = "Swift implementations of the Language Server and Build Server protocols";
    homepage = "https://github.com/swiftlang/swift-tools-protocols";
    platforms = lib.platforms.linux;
    license = lib.licenses.asl20;
    teams = [ lib.teams.swift ];
  };
}
