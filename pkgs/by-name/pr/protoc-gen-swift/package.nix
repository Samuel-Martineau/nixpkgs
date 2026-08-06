{
  lib,
  fetchFromGitHub,
  swiftPackages,
  swift,
  swiftpm,
  nix-update-script,
}:
let
  stdenv = swiftPackages.stdenv;
in
stdenv.mkDerivation (finalAttrs: {
  pname = "protoc-gen-swift";
  version = "1.34.1";

  src = fetchFromGitHub {
    owner = "apple";
    repo = "swift-protobuf";
    rev = "${finalAttrs.version}";
    hash = "sha256-DnnDT4egw00tvy84PuyvSKINjVwueg7QRSQrwD81qbg=";
  };

  # The `protoc` target builds Google's C++ protobuf compiler out of the
  # Sources/protobuf submodule, which is not fetched, along with the plugin
  # that drives it. SwiftPM 6 rejects a manifest naming an empty target even
  # when nothing asks to build it, where 5.10 tolerated one. protoc-gen-swift
  # is a plugin *for* protoc and never needs protoc itself.
  postPatch = ''
    awk '
      /^        \.(executable|executableTarget|plugin)\($/ {
          hdr = $0; getline nm;
          if (nm ~ /^            name: "(protoc|SwiftProtobufPlugin)",$/) { drop = 1; next }
          print hdr; print nm; next
      }
      drop && /^        \),$/ { drop = 0; next }
      !drop
    ' Package.swift > Package.swift.new
    mv Package.swift.new Package.swift

    if grep -q '"protoc"' Package.swift; then
      echo "error: protoc references remain in the manifest" >&2
      exit 1
    fi
  '';

  nativeBuildInputs = [
    swift
    swiftpm
  ];

  # Not needed for darwin, as `apple-sdk` is implicit and part of the stdenv
  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    swiftPackages.Foundation
    swiftPackages.Dispatch
  ];

  env = lib.optionalAttrs stdenv.hostPlatform.isLinux {
    # swiftpm fails to found libdispatch.so on Linux
    LD_LIBRARY_PATH = lib.makeLibraryPath [
      swiftPackages.Dispatch
    ];
  };

  installPhase = ''
    runHook preInstall
    install -Dm755 .build/release/protoc-gen-swift $out/bin/protoc-gen-swift
    runHook postInstall
  '';

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "Protobuf plugin for generating Swift code";
    homepage = "https://github.com/apple/swift-protobuf";
    license = lib.licenses.asl20;
    maintainers = with lib.maintainers; [ matteopacini ];
    mainProgram = "protoc-gen-swift";
    inherit (swift.meta) platforms badPlatforms;
  };
})
