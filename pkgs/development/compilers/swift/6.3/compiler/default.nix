{
  lib,
  stdenv,
  callPackage,
  cmake,
  coreutils,
  gnugrep,
  perl,
  ninja,
  pkg-config,
  clang,
  bintools,
  python3,
  git,
  makeWrapper,
  gnumake,
  file,
  swift-bootstrap,
  swift-llvm,
  # Linux-specific
  libuuid,
  Dispatch,
}:

# Builds the Swift 6.3 compiler and stdlib from source, against the
# separately-built fork of LLVM/Clang (../llvm).
#
# Unlike the 5.10 build, the compiler can no longer be bootstrapped from a
# C++ compiler alone: SwiftCompilerSources and swift-syntax are compiled by a
# host Swift toolchain (BOOTSTRAPPING_MODE=HOSTTOOLS), provided here by
# swift-bootstrap (a prebuilt toolchain from swift.org, see ../../bootstrap).
# The bootstrap toolchain is a build-time dependency only; postFixup checks
# that it does not leak into the runtime closure.
#
# The C library is found without wrapping the Swift binaries: ClangImporter is
# patched (see patches/swift-clangimporter-*) to read `nix-support/libc-cflags`
# from the cc-wrapper behind a `clang` symlink placed next to the running
# swift-frontend.

let
  sources = callPackage ../sources.nix { };

  inherit (stdenv) targetPlatform hostPlatform;

  # Swift uses the xcrun naming convention on Darwin rather than the kernel
  # name. See the `configure_sdk_darwin` calls in its CMake files.
  swiftOs =
    if targetPlatform.isDarwin then
      {
        "macos" = "macosx";
        "ios" = "iphoneos";
      }
      .${targetPlatform.darwinPlatform}
        or (throw "Cannot build Swift for target Darwin platform '${targetPlatform.darwinPlatform}'")
    else
      targetPlatform.parsed.kernel.name;

  # Apple calls the architecture arm64, except on Linux, where it is aarch64.
  swiftArch = if hostPlatform.isDarwin then hostPlatform.darwinArch else targetPlatform.parsed.cpu.name;

  # Clang resource directory version of the vendored LLVM (major only).
  clangVersion = "21";

  # On Darwin a `.swiftmodule` is a directory under `lib/swift/<OS>` holding a
  # binary per architecture; elsewhere the modules live in
  # `lib/swift/<OS>/<ARCH>`.
  swiftLibSubdir = "lib/swift/${swiftOs}";
  swiftModuleSubdir =
    if hostPlatform.isDarwin then "lib/swift/${swiftOs}" else "lib/swift/${swiftOs}/${swiftArch}";

  # And then there's also a separate subtree for statically linked  modules.
  toStaticSubdir = lib.replaceStrings [ "/swift/" ] [ "/swift_static/" ];
  swiftStaticLibSubdir = toStaticSubdir swiftLibSubdir;
  swiftStaticModuleSubdir = toStaticSubdir swiftModuleSubdir;

  # This matches _SWIFT_DEFAULT_COMPONENTS, with specific components disabled.
  swiftInstallComponents = [
    "autolink-driver"
    "compiler"
    "compiler-swift-syntax-lib"
    "swift-syntax-lib"
    # "clang-builtin-headers"
    "stdlib"
    "sdk-overlay"
    "static-mirror-lib"
    "editor-integration"
    # "tools"
    # "testsuite-tools"
    "toolchain-tools"
    "toolchain-dev-tools"
    "license"
    "sourcekit-inproc"
    "swift-remote-mirror"
    "swift-remote-mirror-headers"
  ];

  clangForWrappers = clang.override (prev: {
    extraBuildCommands =
      prev.extraBuildCommands
      # We need to use the resource directory corresponding to Swift’s
      # version of Clang instead of passing along the one from the
      # `cc-wrapper` flags.
      + ''
        substituteInPlace $out/nix-support/cc-cflags \
          --replace-fail " -resource-dir=$out/resource-root" ""
      '';
  });
in
stdenv.mkDerivation {
  pname = "swift";
  inherit (sources) version;

  outputs = [
    "out"
    "lib"
    "dev"
    "doc"
    "man"
  ];

  nativeBuildInputs = [
    cmake
    git
    ninja
    perl # pod2man
    pkg-config
    python3
    makeWrapper
  ];

  buildInputs = [
    libuuid
    swift-llvm
    Dispatch
  ];

  # We setup custom build directories.
  dontUseCmakeBuildDir = true;

  unpackPhase =
    let
      copySource = repo: "cp -r ${sources.${repo}} ${repo}";
    in
    ''
      mkdir src
      cd src

      ${copySource "swift-cmark"}
      ${copySource "swift"}
      ${copySource "swift-experimental-string-processing"}
      ${copySource "swift-syntax"}
      chmod -R u+w .
    '';

  patchPhase = ''
    # Just patch all the things for now, we can focus this later.
    # TODO: eliminate use of env.
    find -type f -print0 | xargs -0 sed -i \
      -e 's|/usr/bin/env|${coreutils}/bin/env|g' \
      -e 's|/usr/bin/make|${gnumake}/bin/make|g' \
      -e 's|/bin/mkdir|${coreutils}/bin/mkdir|g' \
      -e 's|/bin/cp|${coreutils}/bin/cp|g' \
      -e 's|/usr/bin/file|${file}/bin/file|g'

    # ClangImporter: find libc/libc++ flags via the `clang` symlink next to
    # the running swift binary (see comment at the top of this file).
    patch -p1 -d swift -i ${./patches/swift-clangimporter-read-nix-cc-flags.patch}
    patch -p1 -d swift -i ${./patches/swift-clangimporter-nixpkgs-paths.patch}

    # The bridging headers need Clang declarations that are only forward
    # declared, which fails when the compiler's Swift sources are built.
    patch -p1 -d swift -i ${./patches/swift-sil-missing-headers.patch}

    # Link against the libdispatch package instead of building a copy in
    # tree: the in-tree copy is linked but never installed, so the compiler
    # cannot find libdispatch.so at run time.
    patch -p1 -d swift -i ${./patches/swift-use-nixpkgs-libdispatch.patch}

    # This patch needs to know the lib output location, so must be substituted
    # in the same derivation as the compiler.
    storeDir="${builtins.storeDir}" \
      substituteAll ${./patches/swift-separate-lib.patch} $TMPDIR/swift-separate-lib.patch
    patch -p1 -d swift -i $TMPDIR/swift-separate-lib.patch

    # Fixes for building against an installed LLVM instead of a build tree.
    # Swift doesn't need LLVM's build folder, only a built LLVM.
    substituteInPlace swift/cmake/modules/SwiftSharedCMakeConfig.cmake \
      --replace-fail "precondition_translate_flag(LLVM_BUILD_LIBRARY_DIR LLVM_LIBRARY_DIR)" ""

    # Fix the path to LLVM's CMake modules.
    substituteInPlace swift/lib/Basic/CMakeLists.txt \
      --replace-fail '"''${LLVM_MAIN_SRC_DIR}/cmake/modules/GenerateVersionFromVCS.cmake"' \
        '"${swift-llvm}/lib/cmake/llvm/GenerateVersionFromVCS.cmake"'

    # Find `features.json` in Clang's install tree, not LLVM's build tree.
    substituteInPlace swift/lib/Option/CMakeLists.txt \
      --replace-fail '"''${LLVM_BINARY_DIR}/share/clang/features.json"' '"${swift-llvm}/share/clang/features.json"'

    # Make sure Swift can find Clang's resource dir during the build.
    substituteInPlace swift/stdlib/public/SwiftShims/swift/shims/CMakeLists.txt \
      --replace-fail \
        'set(clang_headers_location "''${LLVM_LIBRARY_OUTPUT_INTDIR}/clang/''${CLANG_VERSION_MAJOR}")' \
        'set(clang_headers_location "${swift-llvm}/lib/clang/${clangVersion}")'

    # libdispatch and the blocks runtime come from a finished package rather
    # than being built in tree, so SourceKit needs no build-order dependency
    # on them (and the CMake targets it names no longer exist).
    substituteInPlace swift/tools/SourceKit/CMakeLists.txt \
      --replace-fail 'add_dependencies(sourcekit-inproc BlocksRuntime dispatch)' ""

    # uuid.h is not part of glibc, but of libuuid.
    sed -i 's|''${GLIBC_INCLUDE_PATH}/uuid/uuid.h|${libuuid.dev}/include/uuid/uuid.h|' \
      swift/stdlib/public/Platform/glibc.modulemap.gyb

    patchShebangs .
  '';

  configurePhase = ''
    export SWIFT_SOURCE_ROOT="$PWD"
    mkdir -p ../build
    cd ../build
    export SWIFT_BUILD_ROOT="$PWD"

    # The host Swift toolchain needs an SDK (sysroot) to find libc and its own
    # runtime when CMake test-compiles and links host Swift code.
    export SDKROOT="${swift-bootstrap}/sysroot"

    # The host toolchain's clang writes its module cache under $HOME.
    export HOME="$TMPDIR"
  '';

  # These steps are derived from doing a normal build with.
  #
  #   ./swift/utils/build-toolchain test --dry-run
  #
  # But dealing with the custom Python build system is far more trouble than
  # simply invoking CMake directly. Few variables it passes to CMake are
  # actually required or non-default.
  #
  # Using CMake directly also allows us to split up the already large build,
  # and package Swift components separately.
  buildPhase = ''
    # Helper to build a subdirectory.
    #
    # Always reset cmakeFlags before calling this. The cmakeConfigurePhase
    # amends flags and would otherwise keep expanding it.
    function buildProject() {
      mkdir -p $SWIFT_BUILD_ROOT/$1
      cd $SWIFT_BUILD_ROOT/$1

      cmakeDir=$SWIFT_SOURCE_ROOT/''${2-$1}
      cmakeConfigurePhase

      ninjaBuildPhase
    }

    cmakeFlags="-GNinja"
    buildProject swift-cmark

    # The bootstrap toolchain's ClangImporter knows nothing about nixpkgs'
    # split C++ standard library, so it cannot compile the compiler's bridging
    # modules (which include LLVM headers) without being told where libstdc++
    # lives. Reuse the paths the nixpkgs Clang wrapper already computed.
    # SWIFT_COMPILER_SOURCES_SDK_FLAGS is a CMake list (semicolons) used for
    # the compiler's own Swift sources; CMAKE_Swift_FLAGS is a plain string
    # applied to every other Swift target (lib/ASTGen and friends).
    swiftCxxFlags=""
    swiftCxxFlagsStr=""
    for dir in $(awk '{ for (i = 1; i <= NF; i++) if ($i == "-cxx-isystem") print $(i + 1) }' \
      ${clang}/nix-support/libcxx-cxxflags); do
      swiftCxxFlags="$swiftCxxFlags;-Xcc;-isystem;-Xcc;$dir"
      swiftCxxFlagsStr="$swiftCxxFlagsStr -Xcc -isystem -Xcc $dir"
    done
    swiftCxxFlags="''${swiftCxxFlags#;}"
    swiftCxxFlagsStr="''${swiftCxxFlagsStr# }"

    # Some notes:
    # - BOOTSTRAPPING_MODE=HOSTTOOLS: SwiftCompilerSources and swift-syntax
    #   are built with the prebuilt host toolchain (swift-bootstrap).
    # - Experimental features are OFF by default in CMake, but are enabled in
    #   official builds, so we do the same.
    cmakeFlags="
      -GNinja
      -DBOOTSTRAPPING_MODE=HOSTTOOLS
      -DCMAKE_Swift_COMPILER=${swift-bootstrap}/usr/bin/swiftc
      -DSWIFT_EARLY_SWIFT_DRIVER_BUILD=${swift-bootstrap}/usr/bin
      -DSWIFT_PREBUILT_CLANG=ON
      -DSWIFT_NATIVE_CLANG_TOOLS_PATH=${clangForWrappers}/bin
      -DSWIFT_NATIVE_LLVM_TOOLS_PATH=${swift-llvm}/bin
      -DSWIFT_BUILD_SWIFT_SYNTAX=ON
      -DSWIFT_ENABLE_EXPERIMENTAL_DIFFERENTIABLE_PROGRAMMING=ON
      -DSWIFT_ENABLE_EXPERIMENTAL_CONCURRENCY=ON
      -DSWIFT_ENABLE_EXPERIMENTAL_CXX_INTEROP=ON
      -DSWIFT_ENABLE_EXPERIMENTAL_DISTRIBUTED=ON
      -DSWIFT_ENABLE_EXPERIMENTAL_STRING_PROCESSING=ON
      -DSWIFT_ENABLE_EXPERIMENTAL_OBSERVATION=ON
      -DSWIFT_ENABLE_SYNCHRONIZATION=ON
      -DSWIFT_ENABLE_VOLATILE=ON
      -DSWIFT_ENABLE_RUNTIME_MODULE=ON
      -DSWIFT_ENABLE_BACKTRACING=ON
      -DLLVM_DIR=${swift-llvm}/lib/cmake/llvm
      -DClang_DIR=${swift-llvm}/lib/cmake/clang
      -DSWIFT_PATH_TO_CMARK_SOURCE=$SWIFT_SOURCE_ROOT/swift-cmark
      -DSWIFT_PATH_TO_CMARK_BUILD=$SWIFT_BUILD_ROOT/swift-cmark
      -Ddispatch_DIR=${lib.getDev Dispatch}/lib/cmake/dispatch
      -DSWIFT_PATH_TO_SWIFT_SYNTAX_SOURCE=$SWIFT_SOURCE_ROOT/swift-syntax
      -DSWIFT_PATH_TO_STRING_PROCESSING_SOURCE=$SWIFT_SOURCE_ROOT/swift-experimental-string-processing
      -DSWIFT_INSTALL_COMPONENTS=${lib.concatStringsSep ";" swiftInstallComponents}
      -DSWIFT_STDLIB_ENABLE_OBJC_INTEROP=OFF
      -DSWIFT_COMPILER_SOURCES_SDK_FLAGS=$swiftCxxFlags
    "

    mkdir -p $SWIFT_BUILD_ROOT/swift
    cd $SWIFT_BUILD_ROOT/swift
    cmakeDir=$SWIFT_SOURCE_ROOT/swift
    # Passed via the array because the value contains spaces.
    cmakeFlagsArray+=("-DCMAKE_Swift_FLAGS=$swiftCxxFlagsStr")
    cmakeConfigurePhase
    unset cmakeFlagsArray

    # ClangImporter of the freshly built swift-frontend locates libc flags
    # via a `clang` symlink next to the running binary (see patches).
    mkdir -p $SWIFT_BUILD_ROOT/swift/bin
    ln -sf ${clangForWrappers}/bin/clang $SWIFT_BUILD_ROOT/swift/bin/clang

    # Every install component is also a build target, and some of them are
    # deliberately excluded from `all` (lib/SwiftSyntax sets EXCLUDE_FROM_ALL),
    # so building only `all` leaves libraries the install rules expect —
    # libSwiftIDEUtils.so and friends — missing.
    ninjaFlags="all ${lib.concatStringsSep " " swiftInstallComponents}"
    ninjaBuildPhase
    unset ninjaFlags
  '';

  # TODO: tests not ported from 5.10 yet.
  doCheck = false;

  installPhase = ''
    mkdir $lib

    cd $SWIFT_BUILD_ROOT/swift
    ninjaInstallPhase

    # Separate $lib output here, because specific logic follows.
    # Only move the dynamic run-time parts, to keep $lib small. Every Swift
    # build will depend on it.
    moveToOutput "lib/swift" "$lib"
    moveToOutput "lib/libswiftDemangle.*" "$lib"

    # This link is here because various tools (swiftpm) check for stdlib
    # relative to the swift compiler. It's fine if this is for build-time
    # stuff, but we should patch all cases were it would end up in an output.
    ln -s $lib/lib/swift $out/lib/swift

    # ClangImporter resolves libc flags via this symlink (see patches). It
    # also gives swift-driver a linker driver next to the Swift binaries.
    ln -sf ${clangForWrappers}/bin/clang $out/bin/clang

    # The "early" Swift driver is taken from the bootstrap toolchain during
    # the build, and CMake installs those binaries. They must not ship: the
    # real driver is built separately (swift-driver). Point swift/swiftc at
    # swift-frontend in the meantime, as its legacy-driver aliases already do.
    rm -f $out/bin/swift $out/bin/swiftc $out/bin/swift-driver $out/bin/swift-help
    ln -s swift-frontend $out/bin/swift
    ln -s swift-frontend $out/bin/swiftc

    # Binaries link the stdlib through $ORIGIN, but the link also recorded the
    # bootstrap toolchain's runtime directory. Drop those entries so the seed
    # stays out of the closure.
    for file in $(find $out $lib -type f); do
      rpath=$(patchelf --print-rpath "$file" 2>/dev/null) || continue
      [ -n "$rpath" ] || continue
      stripped=$(echo "$rpath" | tr ':' '\n' | grep -v "^${swift-bootstrap}" | paste -sd:)
      if [ "$rpath" != "$stripped" ]; then
        patchelf --set-rpath "$stripped" "$file"
      fi
    done

    # Swift has a separate resource root from Clang, but locates the Clang
    # resource root via subdir or symlink. Use the fork's Clang headers, and
    # add the runtime library symlinks from the regular Clang wrapper.
    if [ ! -e $lib/lib/swift/clang ]; then
      cp -r ${swift-llvm}/lib/clang/${clangVersion} $lib/lib/swift/clang
      chmod -R u+w $lib/lib/swift/clang
      cp -P ${clang}/resource-root/{lib,share} $lib/lib/swift/clang/ || true
    fi
  '';

  preFixup = ''
    # This is cheesy, but helps the patchelf hook remove /build from RPATH.
    cd $SWIFT_BUILD_ROOT/..
    mv build buildx
  '';

  postFixup = ''
    # The bootstrap toolchain must never leak into the runtime closure.
    for output in $out $lib; do
      if leaked=$(grep -r -l "${swift-bootstrap}" $output 2>/dev/null | head -1); [ -n "$leaked" ]; then
        echo "error: swift-bootstrap leaked into the closure via $leaked" >&2
        patchelf --print-rpath "$leaked" 2>/dev/null | sed 's/^/  rpath: /' >&2
        exit 1
      fi
    done
  '';

  passthru = {
    inherit
      swiftOs
      swiftArch
      swiftModuleSubdir
      swiftLibSubdir
      swiftStaticModuleSubdir
      swiftStaticLibSubdir
      ;

    # Internal attr for the wrapper.
    _wrapperParams = {
      inherit bintools;
      coreutils_bin = lib.getBin coreutils;
      gnugrep_bin = gnugrep;
      suffixSalt = lib.replaceStrings [ "-" "." ] [ "_" "_" ] targetPlatform.config;
      use_response_file_by_default = 1;
      swiftDriver = "";
    };
  };

  # 1716 targets, and the Swift-in-Swift stages near the end are largely
  # serial, so it needs a builder that will not trip Hydra's max-silent-time.
  requiredSystemFeatures = [ "big-parallel" ];

  meta = {
    description = "Swift Programming Language";
    homepage = "https://github.com/swiftlang/swift";
    teams = [ lib.teams.swift ];
    license = lib.licenses.asl20;
    platforms = lib.platforms.linux;
    badPlatforms = lib.platforms.i686;
    timeout = 86400; # 24 hours.
  };
}
