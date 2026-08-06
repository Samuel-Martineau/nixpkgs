{
  lib,
  stdenv,
  callPackage,
}:

# Prebuilt Swift toolchain from swift.org, used (like `rustc`'s bootstrap) as
# the host compiler to build `swiftPackages.swift-unwrapped` from source.
#
# The two platforms share nothing but their purpose and their layout: the
# Linux seed is a tarball of Ubuntu binaries that has to be patchelf'd onto
# Nixpkgs' glibc, while the Darwin seed is an Apple installer package whose
# binaries are already relocatable. Both present the toolchain under
# `$out/usr`, which is what the compiler derivation expects.

if stdenv.hostPlatform.isDarwin then callPackage ./darwin.nix { } else callPackage ./linux.nix { }
