{
  lib,
  stdenv,
  fetchFromGitHub,
  autoPatchelfHook,
  clang,
  makeWrapper,
  pkg-config,
  swift,
  swiftpm,
  swiftpm2nix,
  swiftPackages,
  llvmPackages,
  xadi,
  xtool-darwin-tools,
  curl,
  glibc,
  libimobiledevice,
  libimobiledevice-glue,
  libplist,
  libusbmuxd,
  openssl,
  xz,
  zip,
  zlib,
}:

# A replacement for Xcode's command line tooling: builds, signs and installs
# iOS apps from Linux.
#
# xtool downloads several things on first run. Only one of them can be
# replaced with something built from source -- the Darwin toolset of ld64.lld,
# dsymutil and libtool, which is what xtool-darwin-tools provides and what the
# local-darwin-toolset patch redirects. The rest are either Apple binaries
# that cannot be redistributed (the libraries inside Apple Music's APK, used
# for Apple ID authentication) or live Apple web APIs, which have nothing to
# pin.

let
  generated = swiftpm2nix.helpers ./generated;

  # SwiftPM compiles C targets with clang-only flags (-fblocks, -target), so a
  # gcc stdenv cannot serve. Building in the toolchain's own clang stdenv makes
  # CC and CXX right by construction, and keeps the C++ standard library
  # reaching the compiler through the wrapper's -cxx-isystem rather than by
  # hand.
  swiftStdenv = llvmPackages.stdenv;
in
swiftStdenv.mkDerivation (finalAttrs: {
  pname = "xtool";
  version = "1.17.0";

  src = fetchFromGitHub {
    owner = "xtool-org";
    repo = "xtool";
    rev = "9e8bfd432c99c7ef9ade6c4b6723f1321ed0e7ed";
    hash = "sha256-8OOxQg6x5EQFuieRQg/GV3LfB3Eky+qR19C+B9OpjuQ=";
  };

  patches = [ ./patches/local-darwin-toolset.patch ];

  nativeBuildInputs = [
    swift
    swiftpm
    autoPatchelfHook
    makeWrapper
    pkg-config
  ];

  buildInputs = [
    xadi
    curl
    glibc
    libimobiledevice
    libimobiledevice-glue
    libplist
    libusbmuxd
    openssl
    xz
    zlib
  ];

  configurePhase = ''
    runHook preConfigure
    ${generated.configure}
    runHook postConfigure
  '';

  swiftpmFlags = [
    "--product"
    "xtool"
  ]
  # SwiftPM reads CC from the environment but then invokes the compiler with
  # an environment of its own, so CPATH does not reach it and the libc headers
  # have to travel as flags. The C++ standard library is deliberately absent:
  # the cc-wrapper supplies it through -cxx-isystem, which is why this builds
  # against the default GCC's libstdc++ rather than needing an older one.
  # -Xcc reaches C compilation and -Xcxx C++; the vendored BoringSSL and zsign
  # are C++, so both are needed.
  #
  # -idirafter rather than -isystem: libstdc++'s <cstdlib> reaches the libc
  # header with `#include_next <stdlib.h>`, which searches only the
  # directories *after* the one holding the file doing the including. An
  # -isystem entry lands before the C++ directory and is therefore skipped;
  # -idirafter puts it at the very end, where include_next will find it.
  ++ lib.concatMap (dir: [
    "-Xcc"
    "-idirafter"
    "-Xcc"
    dir
    "-Xcxx"
    "-idirafter"
    "-Xcxx"
    dir
  ]) (
    map (p: "${lib.getDev p}/include") [
      glibc
      xz
      zlib
    ]
  );

  env = {
    # ld.lld is invoked without the cc-wrapper, so libraries it cannot already
    # reach have to be named here. unxip's module map calls liblzma "lzma",
    # which pkg-config does not answer to.
    LIBRARY_PATH = lib.makeLibraryPath [
      xadi
      xz
      zlib
    ];

    # Package.swift takes the version from the environment.
    XTOOL_VERSION = finalAttrs.version;
  };


  installPhase = ''
    runHook preInstall

    install -Dm755 "$(swiftpmBinPath)/xtool" $out/bin/.xtool-wrapped

    # xtool drives clang for the project it is building, not just for itself,
    # and shells out to zip when packaging an IPA. XTOOL_DARWIN_TOOLSET is
    # read by the local-darwin-toolset patch in place of a download.
    makeWrapper $out/bin/.xtool-wrapped $out/bin/xtool \
      --set CC "${lib.getBin clang}/bin/clang" \
      --set XTOOL_DARWIN_TOOLSET ${xtool-darwin-tools} \
      --prefix PATH : ${lib.makeBinPath [ zip ]}

    runHook postInstall
  '';

  preFixup = ''
    addAutoPatchelfSearchPath ${lib.getLib swiftPackages.swift-unwrapped}/lib/swift/${swiftPackages.swift-unwrapped.swiftOs}
  '';

  meta = {
    description = "Cross-platform replacement for Xcode's command line tooling";
    longDescription = ''
      xtool builds, signs and installs iOS applications from Linux.

      Authentication against Apple's services still reaches the network:
      signing in with an Apple ID downloads Apple's own identity libraries at
      run time, and talking to the developer portal is inherently online.
      Building and packaging an app do not require either.
    '';
    homepage = "https://xtool.sh";
    license = lib.licenses.gpl3Only;
    mainProgram = "xtool";
    platforms = lib.platforms.linux;
    teams = [ lib.teams.swift ];
  };
})
