{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  python3,
  gcc,
  gcc14,
  glibc,
  binutils,
  zlib,
  libxml2,
  ncurses,
  libedit,
  curl,
  sqlite,
  libuuid,
  python312,
}:

# Prebuilt Swift toolchain from swift.org, used (like `rustc`'s bootstrap) as
# the host compiler to build `swiftPackages.swift-unwrapped` from source.
# Swift 6.x can no longer be bootstrapped from a C++ compiler alone: the
# compiler is partly written in Swift and upstream requires a host swiftc
# >= 5.9 (see SwiftCompilerSources/CMakeLists.txt). This derivation never
# ends up in the runtime closure of the from-source toolchain.

let
  # Ubuntu-compiled LLDB requires NCURSES6_* symbols; the nixpkgs default
  # (unicodeSupport = true) exports NCURSESW6_* instead.
  ncurses-non-wide = ncurses.override { unicodeSupport = false; };

  version = "6.3.3";

  sources = {
    "x86_64-linux" = {
      url = "https://download.swift.org/swift-${version}-release/ubuntu2404/swift-${version}-RELEASE/swift-${version}-RELEASE-ubuntu24.04.tar.gz";
      hash = "sha256-2oJypf3czWWxUp7Q5S4EUm4urdQjfVjWIg7+uXPGzRk=";
    };
    "aarch64-linux" = {
      url = "https://download.swift.org/swift-${version}-release/ubuntu2404-aarch64/swift-${version}-RELEASE/swift-${version}-RELEASE-ubuntu24.04-aarch64.tar.gz";
      hash = "sha256-RxJjlUKWU/p2jTcGVYduwbaPapXHiE9eTxeXABQcm38=";
    };
  };
  source =
    sources.${stdenv.hostPlatform.system}
      or (throw "swift-bootstrap: unsupported platform ${stdenv.hostPlatform.system}");

  targetTriple = stdenv.hostPlatform.config;

  # glibc's dynamic loader path varies by ISA. Baked into the clang cfg file
  # so linked binaries pick up nixpkgs' glibc at runtime, not the Ubuntu one.
  dynamicLinker =
    {
      "x86_64-linux" = "ld-linux-x86-64.so.2";
      "aarch64-linux" = "ld-linux-aarch64.so.1";
    }
    .${stdenv.hostPlatform.system};

  # gcc14 (not the default gcc) because GCC 15's C++ headers use constexpr
  # __builtin_fmodf and mmintrin.h uses builtins that clang-21 can't parse.
  # Default gcc is still fine for libstdc++.so runtime linking.
  gcc14Version = lib.getVersion gcc14.cc;
  gcc14CrtDir = "${gcc14.cc}/lib/gcc/${targetTriple}/${gcc14Version}";
in
stdenv.mkDerivation {
  pname = "swift-bootstrap";
  inherit version;

  src = fetchurl source;

  nativeBuildInputs = [
    autoPatchelfHook
    (python3.withPackages (ps: [ ps.lief ]))
  ];

  buildInputs = [
    gcc.cc.lib
    glibc
    zlib
    libxml2
    ncurses-non-wide
    libedit
    curl
    sqlite
    libuuid
    python312
  ];

  dontStrip = true;

  preFixup = ''
    # Ubuntu's Swift links against libxml2.so.2 and libedit.so.2; nixpkgs
    # ships libxml2.so.16 (>=2.13) and libedit.so.0. Rewrite DT_NEEDED so
    # autoPatchelf resolves against the sonames actually on disk.
    for f in \
        "$out/usr/bin/lldb" \
        "$out/usr/bin/lldb-server" \
        "$out/usr/bin/lldb-dap" \
        "$out/usr/bin/lld" \
        "$out/usr/lib/liblldb.so.21.0.0" \
        "$out/usr/lib/swift/linux/libFoundationXML.so"; do
      [ -e "$f" ] || continue
      chmod +w "$f"
      patchelf --replace-needed libxml2.so.2 libxml2.so.16 "$f" 2>/dev/null || true
      patchelf --replace-needed libedit.so.2  libedit.so.0  "$f" 2>/dev/null || true
    done

    # LLDB needs non-wide ncurses (NCURSES6_* symbols) but python312 drags
    # in the default wide ncurses (NCURSESW6_*). autoPatchelf searches $out
    # before buildInputs, so shimming the non-wide libs into $out/usr/lib/
    # wins the resolution. libtinfo is merged into libncurses in non-wide.
    for lib in libncurses.so.6 libpanel.so.6 libform.so.6 libmenu.so.6; do
      ln -sf "${ncurses-non-wide}/lib/$lib" "$out/usr/lib/$lib"
    done
    ln -sf "${ncurses-non-wide}/lib/libncurses.so.6" "$out/usr/lib/libtinfo.so.6"

    # libFoundationXML.so, lld, and lldb still require LIBXML2_2.x.y symbol
    # versions that nixpkgs libxml2 >=2.13 dropped - strip them so ld.so
    # stops warning.
    python3 ${./strip-libxml2-verneed.py} \
      "$out/usr/lib/swift/linux/libFoundationXML.so" \
      "$out/usr/bin/lld" \
      "$out/usr/bin/lldb" \
      "$out/usr/bin/lldb-server" \
      "$out/usr/bin/lldb-dap" \
      "$out/usr/lib/liblldb.so.21.0.0"
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out
    cp -r . $out/

    # The bundled clang calls bare "ld" which isn't in PATH inside the
    # sandbox. Symlink binutils ld into the Swift bin dir so clang finds it.
    ln -s ${binutils.bintools}/bin/ld $out/usr/bin/ld

    # Swift's ClangImporter and swift-driver locate libc headers, crt
    # objects, and the Swift runtime through an SDK sysroot (they do not
    # read clang's cfg file). Assemble one from nixpkgs glibc plus the
    # toolchain's own Swift libraries.
    mkdir -p $out/sysroot/usr/lib
    ln -s ${glibc.dev}/include $out/sysroot/usr/include
    for f in ${glibc}/lib/*; do
      ln -s "$f" $out/sysroot/usr/lib/
    done
    ln -s $out/usr/lib/swift $out/sysroot/usr/lib/swift
    ln -s $out/usr/lib/swift_static $out/sysroot/usr/lib/swift_static

    mkdir -p $out/bin
    for f in $out/usr/bin/*; do
      ln -sf "../usr/bin/$(basename "$f")" "$out/bin/$(basename "$f")"
    done

    # Default the driver's SDK to our sysroot. Subcommands (swift-package,
    # swift-build, ...) inherit SDKROOT from the wrapped entry points.
    for tool in swift swiftc; do
      rm $out/bin/$tool
      cat > $out/bin/$tool <<EOF
    #!${stdenv.shell}
    export SDKROOT="\''${SDKROOT:-$out/sysroot}"
    exec $out/usr/bin/$tool "\$@"
    EOF
      chmod +x $out/bin/$tool
    done

    # Point the bundled clang at nixpkgs' glibc headers and GCC CRT/libs.
    # clang-21 auto-loads <target-triple>.cfg from its own bindir. Only -B/-L
    # into gcc's per-target-lib dir (crt*.o, libgcc); gcc's intrinsic include
    # is deliberately not on the header path so clang uses its own mmintrin.
    cat > $out/usr/bin/${targetTriple}.cfg <<EOF
    -isystem ${glibc.dev}/include
    -B${glibc}/lib
    -B${gcc14CrtDir}
    -L${glibc}/lib
    -L${gcc.cc.lib}/lib
    -L${gcc14CrtDir}
    -fuse-ld=lld
    -Wl,-dynamic-linker,${glibc}/lib/${dynamicLinker}
    EOF

    runHook postInstall
  '';

  meta = {
    description = "Prebuilt Swift toolchain, used to bootstrap the from-source Swift build";
    homepage = "https://swift.org";
    license = lib.licenses.asl20;
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    teams = [ lib.teams.swift ];
    mainProgram = "swift";
  };
}
