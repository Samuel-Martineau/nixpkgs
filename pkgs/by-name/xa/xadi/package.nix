{
  lib,
  buildDubPackage,
  fetchFromGitHub,
  pkg-config,
  openssl,
  libplist,
}:

# Apple Device Identity, the library xtool uses to talk to Apple's GrandSlam
# authentication service on Linux. Written in D.
#
# The shared library is all that is wanted here: xtool declares it as a
# systemLibrary target whose module map is just `link "xadi"`.

buildDubPackage {
  pname = "xadi";
  version = "0-unstable-2024-12-16";

  src = fetchFromGitHub {
    owner = "xtool-org";
    repo = "xadi";
    rev = "61c02708c9cb046100f500878863fd2122b0d7e3";
    hash = "sha256-mKHZE5Al2RK0kDLq3gDzHp1+GmqMFo4R8SItrmY5tcE=";
  };

  dubLock = ./dub-lock.json;

  nativeBuildInputs = [ pkg-config ];

  buildInputs = [
    openssl
    libplist
  ];

  # buildDubPackage installs executables; this package's product is a library.
  installPhase = ''
    runHook preInstall
    install -Dm755 bin/libxadi.so $out/lib/libxadi.so
    runHook postInstall
  '';

  meta = {
    description = "Apple Device Identity library, used by xtool for Apple ID authentication";
    homepage = "https://github.com/xtool-org/xadi";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.linux;
    sourceProvenance = [ lib.sourceTypes.fromSource ];
    teams = [ lib.teams.swift ];
  };
}
