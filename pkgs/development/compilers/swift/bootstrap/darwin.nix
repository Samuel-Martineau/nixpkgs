{
  lib,
  stdenv,
  fetchurl,
  xar,
  cpio,
  gzip,
}:

# The Darwin half of the bootstrap seed (see ./default.nix).
#
# swift.org ships macOS toolchains as an Apple installer package: a xar
# archive whose Payload is a gzip'd cpio of the toolchain rooted at `usr/`.
# Unlike the Linux seed, nothing has to be rewritten afterwards -- the
# binaries link against the system libraries and locate their own runtime
# through @rpath -- so this is an unpack and a copy.
#
# The code signature is left alone deliberately: it stays valid as long as the
# binaries are not modified, and modifying them is exactly what the Linux seed
# has to do and this one does not.

let
  version = "6.3.3";

  # One package serves both architectures; the binaries inside are universal.
  src = fetchurl {
    url = "https://download.swift.org/swift-${version}-release/xcode/swift-${version}-RELEASE/swift-${version}-RELEASE-osx.pkg";
    hash = "sha256-7oLld3TWZQ+UqgYwJDXW9EoFW5QRaY247LhdmjvMkdA=";
  };
in
stdenv.mkDerivation {
  pname = "swift-bootstrap";
  inherit version src;

  nativeBuildInputs = [
    xar
    cpio
    gzip
  ];

  # xar cannot be pointed at a file it does not own the directory of.
  unpackPhase = ''
    runHook preUnpack

    xar -xf ${src} swift-${version}-RELEASE-osx-package.pkg/Payload
    gzip -dc swift-${version}-RELEASE-osx-package.pkg/Payload | cpio -i --quiet

    [ -x usr/bin/swiftc ] \
      || { echo "error: the package did not contain usr/bin/swiftc" >&2; exit 1; }

    runHook postUnpack
  '';

  dontBuild = true;
  dontFixup = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out
    cp -R usr $out/

    # The compiler derivation invokes the seed as $out/usr/bin/swiftc, and
    # elsewhere expects a bin/ too, matching the Linux seed's layout.
    mkdir -p $out/bin
    for tool in swift swiftc swift-frontend; do
      ln -s ../usr/bin/$tool $out/bin/$tool
    done

    runHook postInstall
  '';

  passthru.isBootstrap = true;

  meta = {
    description = "Prebuilt Swift toolchain from swift.org, used to bootstrap the one built from source";
    homepage = "https://swift.org/download/";
    license = lib.licenses.asl20;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = lib.platforms.darwin;
    teams = [ lib.teams.swift ];
  };
}
