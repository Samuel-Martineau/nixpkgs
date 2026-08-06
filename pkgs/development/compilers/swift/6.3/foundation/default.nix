{
  lib,
  stdenv,
  callPackage,
  cmake,
  ninja,
  swift-unwrapped,
  foundation-macros,
  Dispatch,
  libxml2,
  curl,
  substituteAll,
}:

# swift-corelibs-foundation is a compatibility layer in 6.x: the core types
# live in swift-foundation (FoundationEssentials, FoundationInternationalization)
# with internationalisation data from a vendored ICU, and this package adds the
# umbrella Foundation module plus FoundationXML and FoundationNetworking.
#
# All three of those dependencies are declared with FetchContent, which clones
# from GitHub at configure time unless the corresponding _SourceDIR variables
# point at local checkouts.

let
  sources = callPackage ../sources.nix { };
in
stdenv.mkDerivation {
  pname = "swift-corelibs-foundation";

  inherit (sources) version;
  src = sources.swift-corelibs-foundation;

  outputs = [
    "out"
    "dev"
  ];

  nativeBuildInputs = [
    cmake
    ninja
  ];

  buildInputs = [
    libxml2
    curl
  ];

  propagatedBuildInputs = [ Dispatch ];

  cmakeFlags = [
    (lib.cmakeFeature "CMAKE_Swift_COMPILER" "${swift-unwrapped}/bin/swiftc")
    # Without these, CMake clones swift-foundation, swift-foundation-icu and
    # swift-collections from GitHub while configuring.
    (lib.cmakeFeature "_SwiftCollections_SourceDIR" "${sources.swift-collections}")
    (lib.cmakeBool "FETCHCONTENT_FULLY_DISCONNECTED" true)
    # Foundation's macros are provided by a separately built plugin.
    (lib.cmakeFeature "SwiftFoundation_MACRO" "${foundation-macros}/lib/swift/host/plugins")
    (lib.cmakeFeature "dispatch_DIR" "${lib.getDev Dispatch}/lib/cmake/dispatch")
  ];

  # Components copy their headers into a shared directory for XCTest to use
  # with `file(COPY)`, which applies the permissions of the source to the
  # destination. The sources are store paths, so the shared directory becomes
  # read-only and later copies into it fail. swift-foundation needs a writable
  # copy for the same treatment, since the fix is in its CMake files.
  postPatch = ''
    # The option has to follow DESTINATION, so amend the line that closes each
    # `file(COPY ...)` call. swift-foundation-icu copies into the shared
    # directory itself, so it is what makes that directory read-only.
    makeCopiesWritable() {
      local files
      files=$(grep -rl '_CModulesForClients[A-Za-z_/]*)' "$1" --include=CMakeLists.txt)
      [ -n "$files" ] || { echo "no header copies found in $1" >&2; exit 1; }
      echo "$files" | xargs sed -i \
        -e 's|\(_CModulesForClients[A-Za-z_/]*\))|\1 NO_SOURCE_PERMISSIONS)|'
    }

    makeCopiesWritable .

    cp -r ${sources.swift-foundation} swift-foundation
    chmod -R u+w swift-foundation
    makeCopiesWritable swift-foundation

    cp -r ${sources.swift-foundation-icu} swift-foundation-icu
    chmod -R u+w swift-foundation-icu
    makeCopiesWritable swift-foundation-icu
  '';

  preConfigure = ''
    # Fails to build with -D_FORTIFY_SOURCE.
    NIX_HARDENING_ENABLE=''${NIX_HARDENING_ENABLE/fortify/}

    appendToVar cmakeFlags "-D_SwiftFoundation_SourceDIR=$PWD/swift-foundation"
    appendToVar cmakeFlags "-D_SwiftFoundationICU_SourceDIR=$PWD/swift-foundation-icu"

    # CMake does not turn the dispatch package's interface include directories
    # into Swift search paths. `import Dispatch` needs the Swift module, and
    # the module in turn needs the C module map it is an overlay for.
    #
    # Runtime library paths deliberately are not passed here: this project sets
    # CMAKE_INSTALL_RPATH itself, so CMake rewrites them away on install. They
    # are applied in postInstall instead.
    cmakeFlagsArray+=(
      "-DCMAKE_Swift_FLAGS=-I ${Dispatch}/lib/swift/linux -Xcc -fmodule-map-file=${Dispatch}/lib/swift/dispatch/module.modulemap -Xcc -I${Dispatch}/lib/swift"
    )
  '';

  postInstall = ''
    # This project sets CMAKE_INSTALL_RPATH to $ORIGIN, so CMake replaces the
    # library paths recorded at link time when it installs. Record them again
    # here, which is the only point they survive.
    #
    # These libraries have to name the Swift runtime and libdispatch even
    # though whatever loads them already does: linkers emit DT_RUNPATH, which,
    # unlike DT_RPATH, is not used to resolve the dependencies of a dependency.
    # curl and libxml2 are linked by bare name by FoundationNetworking and
    # FoundationXML, so nothing records where they live either.
    rpath="${lib.getLib swift-unwrapped}/lib/swift/${swift-unwrapped.swiftOs}"
    rpath="$rpath:${Dispatch}/lib/swift/${swift-unwrapped.swiftOs}"
    rpath="$rpath:${lib.getLib curl}/lib:${lib.getLib libxml2}/lib"

    for library in $out/lib/swift/${swift-unwrapped.swiftOs}/*.so; do
      patchelf --add-rpath "$rpath" "$library"
    done

    # Foundation only exports its CMake package into the build directory, so
    # dependents (XCTest, swift-testing) need one describing the install.
    mkdir -p $dev/lib/cmake/Foundation
    export dylibExt="${stdenv.hostPlatform.extensions.sharedLibrary}"
    export swiftOs="${swift-unwrapped.swiftOs}"
    substituteAll ${./glue.cmake} $dev/lib/cmake/Foundation/FoundationConfig.cmake
  '';

  meta = {
    description = "Core utilities, internationalization, and OS independence for Swift";
    homepage = "https://github.com/swiftlang/swift-corelibs-foundation";
    mainProgram = "plutil";
    platforms = lib.platforms.linux;
    license = lib.licenses.asl20;
    teams = [ lib.teams.swift ];
  };
}
