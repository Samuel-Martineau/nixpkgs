{
  lib,
  runCommand,
  llvmPackages,
}:

# The Darwin-targeting tools xtool needs to build and link Apple platform
# binaries from Linux.
#
# Upstream (xtool-org/darwin-tools-linux-llvm) distributes a statically linked
# tarball built from its own fork of llvm-project. That fork exists to undo a
# restriction Swift's fork of LLVM adds: swiftlang's lld refuses outright to
# link for platforms it does not claim to support, and xtool's fork downgrades
# that refusal to a warning when the host is not Apple, so that linking works
# on Linux.
#
# Stock LLVM never had the restriction — its lld only rejects an input whose
# platform differs from the target platform — so building these tools from
# Nixpkgs' LLVM avoids the problem rather than patching around it, and tracks a
# far newer LLVM than the fork, which is pinned to a 2025 branch of Swift's
# 20240723 stable release.

runCommand "xtool-darwin-tools-${llvmPackages.llvm.version}"
  {
    meta = {
      description = "Darwin-targeting linker, libtool and dsymutil that xtool builds Apple binaries with";
      homepage = "https://github.com/xtool-org/darwin-tools-linux-llvm";
      license = lib.licenses.ncsa;
      platforms = lib.platforms.linux;
      mainProgram = "ld64.lld";
    };
  }
  ''
    mkdir -p $out/bin

    ln -s ${lib.getBin llvmPackages.lld}/bin/ld64.lld $out/bin/ld64.lld
    ln -s ${lib.getBin llvmPackages.llvm}/bin/dsymutil $out/bin/dsymutil
    # xtool invokes the archiver under the name Apple's toolchain uses.
    ln -s ${lib.getBin llvmPackages.llvm}/bin/llvm-libtool-darwin $out/bin/libtool

    for tool in $out/bin/*; do
      [ -e "$tool" ] || { echo "error: $tool is a broken link" >&2; exit 1; }
    done
  ''
