{ lib, fetchFromGitHub }:

# Sources for the Swift 6.3 toolchain.
#
# The authoritative list of repositories and pins for a release is
# `utils/update_checkout/update-checkout-config.json` (branch scheme
# `release/6.3`) in the swiftlang/swift repository. Repositories in the
# `release` set below are tagged `swift-${version}-RELEASE` together with the
# compiler; the `pinned` set mirrors the version-pinned third-party
# dependencies from that file. Vendored copies of cmake, ninja, curl, libxml2,
# zlib, brotli and mimalloc are intentionally omitted — nixpkgs versions are
# used instead — as are repositories only needed for WASM, installer scripts,
# and upstream CI.

let

  version = "6.3.3";

  # All part of the swiftlang org, tagged with the toolchain release.
  releaseHashes = {
    indexstore-db = "sha256-nmnVN9p598/AypUrr+rE1ocy8kAhONE60QlpdZQAswU=";
    llvm-project = "sha256-b+0G3b5f/i+4SgLV0nsZte5pc/tHd9fVIOPAxWInQXs=";
    sourcekit-lsp = "sha256-vjVcsxFCg1s8L96HSllgGGVpOQeHAWfVnLmUcP05F/o=";
    swift = "sha256-7/jT/U0sOsr4iWnCluyUWjnD/XH5CnPyAG9EQ+Nq+tI=";
    swift-build = "sha256-UW6OD3WyAuN1/vkzlANfWr9lJ2x9mLFgdYC8pwbVqjE=";
    swift-cmark = "sha256-0pyZ5yQRsbiKwz2XT8N6dMwCLcmM28qQOrxHcV6uH7g=";
    swift-corelibs-blocksruntime = "sha256-Uelm1MFSBh/oCW6FXIPZ5iTLWVbxidn+2JvTQZY+i0g=";
    swift-corelibs-foundation = "sha256-Dm/oYkNRevXBBP1+xOgZm3/QjRLQBjk58mXt9N/sPAY=";
    swift-corelibs-libdispatch = "sha256-7UxacHkvbyt51I1WT2wWR1GDrHdknlnYWF9yF8GusQc=";
    swift-corelibs-xctest = "sha256-68OKhvLKwXPZNvuFkcZsqyeVE4YlLXp5+sHfns3EGKM=";
    swift-docc = "sha256-wRHy4yeq+LAUU7dDPc3kUT1BP9ZONl1qmfrYffuR5tQ=";
    swift-docc-render-artifact = "sha256-l5BHqQG47XurMfCASW0t2dfMe9rnXwmij4/qTLJJxes=";
    swift-docc-symbolkit = "sha256-oGnvRcDFgk5DOmKxqsxelT1ScijOwARmrwlKxOPUz00=";
    swift-driver = "sha256-XilPErlnLI7JOnEQM3zEieyo+0/7q2hYfHfnDBtP7qE=";
    swift-experimental-string-processing = "sha256-ENnaw/1UN9PnVLTZujtpfGs5d1e3Z+5Z6EjiwM/8alU=";
    swift-format = "sha256-YkOsFWaQJU786L9OB/n9jOL5G303cz0q62dw3yFWkA0=";
    swift-foundation = "sha256-sXlA1n7SmgneUxsS7+/xNwbIOyGvLmofNXxrIG1Pq9w=";
    swift-foundation-icu = "sha256-+Syca40t4KYTs6Y0qgfntziUebEmHdq1tNNbLau4bwc=";
    swift-llbuild = "sha256-w+pZRXiGSHsxK+ewMdfX49rAJYfZ9wOql/vUGLXpJvo=";
    swift-llvm-bindings = "sha256-nsh5pBokQ088d8Z65trJZPb9XMcw/umEulUN/IYo164=";
    swift-lmdb = "sha256-jPtkUnCsfjBu4pJhaDw+umQivU0beTGSVoI2rIv8Mzg=";
    swift-markdown = "sha256-fDYOycjRC1EiXEd44ZZuYFgUfJBV4cqAWKuJU2j+V2Y=";
    swift-package-manager = "sha256-34mm8hYEvYuvmtkEBQDzluJSHsiwzmGWuO3ZgWnFjzg=";
    swift-syntax = "sha256-zr+2MlGncEu1bEQwUUxlySDx4XOyK+LnX1SRbtm9ERc=";
    swift-testing = "sha256-lXeFJcKRzoRpUYLrQT+5MITb36hSH/dXjBm4w0RispI=";
    swift-tools-support-core = "sha256-LAboqDVEoz2Sgp3BIrasS2DVmiug89yAioJ/mFIVIjA=";
  };

  # Version-pinned dependencies, mostly SwiftPM packages used by the tools.
  pinned = {
    swift-argument-parser = {
      owner = "apple";
      version = "1.6.1";
      hash = "sha256-JXNjFpLNaqzOGXlIgQtwzG2Yq1daOl4tmTAUcZL4thM=";
    };
    swift-asn1 = {
      owner = "apple";
      version = "1.3.2";
      hash = "sha256-ip/N/JAt5Cws14ICFgYHJB3krL3MmyykkuF1bbct4nM=";
    };
    swift-async-algorithms = {
      owner = "apple";
      version = "1.0.1";
      hash = "sha256-Y5b3WJsjy4JMV0QRpHyCFkvZr1E/rMOdh/MDX5ju4Ms=";
    };
    swift-atomics = {
      owner = "apple";
      version = "1.2.0";
      hash = "sha256-Ho3/BDUwAVGG26u8Jz2j1mwqFRcLc+DTlqTyGelM+Gc=";
    };
    swift-certificates = {
      owner = "apple";
      version = "1.10.1";
      hash = "sha256-sGF9dJr4TDYXWSqwj9JeM+TaBq6GdvCBvqTx40CucI4=";
    };
    swift-collections = {
      owner = "apple";
      version = "1.1.6";
      hash = "sha256-+f9Azcl+NbDvxlMsX0UbT3n87aYaBR1Kjp3rDqoLgkA=";
    };
    swift-crypto = {
      owner = "apple";
      version = "3.12.5";
      hash = "sha256-dS2QVkY0IWzmg4vokFLb64b9CM1llvJ5gt4ySGLKuNc=";
    };
    swift-log = {
      owner = "apple";
      version = "1.5.4";
      hash = "sha256-6USRqIqimtQLMQFs+h2G/i1vgK6ttOd7ZQb93G3IhYA=";
    };
    swift-nio = {
      owner = "apple";
      version = "2.65.0";
      hash = "sha256-o/fqOxQAwtIjvLUq+yLveg1vO7mD6xxYT/g05NNvBUg=";
    };
    swift-numerics = {
      owner = "apple";
      version = "1.0.2";
      hash = "sha256-D4cOMa26NYhVzRz3le5CPydn9qEFbFLAqgonPRB0cVo=";
    };
    swift-subprocess = {
      owner = "swiftlang";
      version = "0.2.1";
      hash = "sha256-zG4TLp2crVrP2PeIyZb6BX+C+VaiszEAW/06KfzwYLE=";
    };
    swift-system = {
      owner = "apple";
      version = "1.5.0";
      hash = "sha256-fkPD9lz+XnMRu2Nr62Z+xaPXfK3EYaWaTjO2ZdMPuN8=";
    };
    swift-toolchain-sqlite = {
      owner = "swiftlang";
      version = "1.0.7";
      hash = "sha256-Cb9/Maz1JYeRBW1gx4n8k4bZOeMsntIQm7lcaEL5B48=";
    };
    swift-tools-protocols = {
      owner = "swiftlang";
      version = "0.0.9";
      hash = "sha256-q/S95ozgWkzYm3awDmAC5Obnur4OQp8aO2gstrwCOnE=";
    };
  };

  releaseSources = lib.mapAttrs (
    repo: hash:
    fetchFromGitHub {
      owner = "swiftlang";
      inherit repo hash;
      rev = "swift-${version}-RELEASE";
      name = "${repo}-${version}-src";
    }
  ) releaseHashes;

  pinnedSources = lib.mapAttrs (
    repo: pin:
    fetchFromGitHub {
      inherit (pin) owner hash;
      inherit repo;
      rev = pin.version;
      name = "${repo}-${pin.version}-src";
    }
  ) pinned;

in
releaseSources
// pinnedSources
// {
  inherit version;
  # Versions of the pinned dependencies, for use in component derivations.
  pinnedVersions = lib.mapAttrs (_: pin: pin.version) pinned;
}
