{
  lib,
  stdenv,
  runCommand,
  llvmPackages,
}:

# The Darwin-targeting tools xtool needs to build and link Apple platform
# binaries from Linux.
#
# Upstream (xtool-org/darwin-tools-linux-llvm) distributes a statically linked
# tarball built from a fork of llvm-project, but that fork carries no changes
# of its own — it pins an unmodified commit of swiftlang's `next` branch — and
# the three tools it selects are stock LLVM: the Mach-O flavour of lld, the
# Darwin archiver, and the debug symbol linker. Nixpkgs already builds all of
# them, so assemble the toolset from those rather than compiling LLVM again.

runCommand "darwin-tools-linux-llvm-${llvmPackages.llvm.version}"
  {
    meta = {
      description = "Toolset for xtool's Darwin SDK: Mach-O linker, libtool and dsymutil for Linux";
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
