{
  lib,
  stdenv,
  callPackage,
  cmake,
  ninja,
  useSwift ? true,
  swift,
}:

let
  sources = callPackage ../sources.nix { };
in
stdenv.mkDerivation {
  pname = "swift-corelibs-libdispatch";

  inherit (sources) version;
  src = sources.swift-corelibs-libdispatch;

  outputs = [
    "out"
    "dev"
    "man"
  ];

  nativeBuildInputs = [
    cmake
  ]
  ++ lib.optionals useSwift [
    ninja
    swift
  ];

  # Upstream skips the man pages when the Swift overlay is enabled, which
  # would leave the man output empty.
  postPatch = ''
    substituteInPlace man/CMakeLists.txt \
      --replace-fail 'if(NOT ENABLE_SWIFT)' 'if(TRUE)'
  '';

  cmakeFlags = lib.optionals useSwift [
    "-DENABLE_SWIFT=ON"
    # Install libraries next to the rest of the toolchain's runtime, without
    # the architecture subdirectory Swift SDK overlays use.
    "-Ddispatch_INSTALL_ARCH_SUBDIR=NO"
  ];

  postInstall = ''
    # Provide a CMake module. This is primarily used to glue together parts of
    # the Swift toolchain. Modifying the CMake config to do this for us is
    # otherwise more trouble.
    mkdir -p $dev/lib/cmake/dispatch
    export dylibExt="${stdenv.hostPlatform.extensions.sharedLibrary}"
    # With the Swift overlay enabled the libraries are installed into the
    # Swift runtime layout instead of plain lib/.
    export libSubdir="${if useSwift then "lib/swift/linux" else "lib"}"
    # The Swift overlay build installs the headers next to the runtime; the
    # plain build puts them in the dev output.
    ${
      if useSwift then
        # linux/ also holds Dispatch.swiftmodule, so `import Dispatch` resolves.
        ''export headerDirs="\"$out/lib/swift\" \"$out/lib/swift/Block\" \"$out/lib/swift/linux\""''
      else
        ''export headerDirs="\"$dev/include\""''
    }
    substituteAll ${./glue.cmake} $dev/lib/cmake/dispatch/dispatchConfig.cmake
  '';

  meta = {
    description = "Grand Central Dispatch";
    homepage = "https://github.com/swiftlang/swift-corelibs-libdispatch";
    platforms = lib.platforms.linux;
    license = lib.licenses.asl20;
    teams = [ lib.teams.swift ];
  };
}
