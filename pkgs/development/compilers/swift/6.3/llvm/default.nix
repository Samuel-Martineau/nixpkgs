{
  lib,
  stdenv,
  callPackage,
  cmake,
  ninja,
  python3,
  glibc,
}:

# Swift's fork of LLVM/Clang (currently based on LLVM 21), built as a separate
# derivation so that iterating on the Swift compiler build does not rebuild
# LLVM. The fork is mandatory: the Swift compiler links against fork-only
# Clang/LLVM APIs (API notes, Swift attributes, C++ interop support).
#
# Only libraries, headers, CMake packages, and tblgen utilities are installed;
# LLVM tools are not built. The Swift compiler derivation consumes this via
# LLVM_DIR/Clang_DIR.

let
  sources = callPackage ../sources.nix { };
in
stdenv.mkDerivation {
  pname = "swift-llvm";
  inherit (sources) version;

  src = sources.llvm-project;

  # Deliberately a single output: LLVM's CMake exports reference libraries by
  # absolute path relative to the install prefix, and splitting outputs breaks
  # them. This package is internal to the Swift toolchain build.
  outputs = [ "out" ];

  nativeBuildInputs = [
    cmake
    ninja
    python3
  ];

  patchPhase = ''
    patch -p1 -d llvm -i ${./patches/llvm-module-cache.patch}
    patch -p1 -d clang -i ${./patches/clang-toolchain-dir.patch}
    patch -p1 -d clang -i ${./patches/clang-purity.patch}

    substituteInPlace clang/lib/Driver/ToolChains/Linux.cpp \
      --replace-fail 'LibDir = "lib";' 'LibDir = "${glibc}/lib";' \
      --replace-fail 'LibDir = "lib64";' 'LibDir = "${glibc}/lib";'

    patchShebangs .
  '';

  # The Swift build needs the Clang/LLVM libraries and the tblgen utilities,
  # but none of the LLVM tools.
  cmakeFlags = [
    "-DLLVM_ENABLE_PROJECTS=clang"
    "-DLLVM_BUILD_TOOLS=NO"
    "-DLLVM_INSTALL_UTILS=ON"
    "-DLLVM_TARGETS_TO_BUILD=${
      {
        "x86_64" = "X86";
        "aarch64" = "AArch64";
      }
      .${stdenv.targetPlatform.parsed.cpu.name}
        or (throw "Unsupported CPU architecture: ${stdenv.targetPlatform.parsed.cpu.name}")
    }"
  ];

  cmakeDir = "../llvm";

  # LLVM treats `llvm/Config/config.h` as private to its build tree and does
  # not install it, but the Swift compiler includes it in a dozen places
  # (lib/Basic/Program.cpp, lib/Driver/Driver.cpp, ...). Install it so Swift
  # can be built against this LLVM without its build tree.
  postInstall = ''
    install -Dm444 include/llvm/Config/config.h $out/include/llvm/Config/config.h
  '';

  meta = {
    description = "Swift's fork of LLVM and Clang";
    homepage = "https://github.com/swiftlang/llvm-project";
    teams = [ lib.teams.swift ];
    license = lib.licenses.ncsa;
    platforms = lib.platforms.linux;
    timeout = 86400;
  };
}
