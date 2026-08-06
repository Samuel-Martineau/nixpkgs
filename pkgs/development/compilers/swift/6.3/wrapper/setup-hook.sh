# Add import paths for build inputs.
swiftWrapper_addImports () {
    # Include subdirectories following both the Swift platform convention, and
    # a simple `lib/swift` for Nix convenience.
    for subdir in @swiftModuleSubdir@ @swiftStaticModuleSubdir@ lib/swift; do
        if [[ -d "$1/$subdir" ]]; then
            export NIX_SWIFTFLAGS_COMPILE+=" -I $1/$subdir"
        fi
    done
    for subdir in @swiftLibSubdir@ @swiftStaticLibSubdir@ lib/swift; do
        if [[ -d "$1/$subdir" ]]; then
            export NIX_LDFLAGS+=" -L $1/$subdir"
        fi
    done

    # A Swift module that overlays a C one -- Dispatch over libdispatch, for
    # instance -- cannot be imported unless the Clang module it overlays can
    # be found too, which needs the module map by name and its header
    # directory. Neither is implied by the Swift import paths above.
    if [[ -d "$1/lib/swift" ]]; then
        export NIX_SWIFTFLAGS_COMPILE+=" -Xcc -I$1/lib/swift"
        for modulemap in "$1"/lib/swift/*/module.modulemap; do
            if [[ -f "$modulemap" ]]; then
                export NIX_SWIFTFLAGS_COMPILE+=" -Xcc -fmodule-map-file=$modulemap"
            fi
        done
    fi
}

addEnvHooks "$targetOffset" swiftWrapper_addImports

# Use a postHook here because we rely on NIX_CC, which is set by the cc-wrapper
# setup hook, so delay until we're sure it was run.
swiftWrapper_postHook () {
    # On Darwin, libc also contains Swift modules.
    if [[ -e "$NIX_CC/nix-support/orig-libc" ]]; then
        swiftWrapper_addImports "$(<$NIX_CC/nix-support/orig-libc)"
    fi
}

postHooks+=(swiftWrapper_postHook)
