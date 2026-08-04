#!/usr/bin/env python3
"""
Delete libxml2 VERNEED entries and their symbol-version references from
an ELF binary.

libFoundationXML.so from Swift's Ubuntu 24.04 binary release requires
LIBXML2_2.x.y symbol versions that were dropped in nixpkgs libxml2 >=2.13.
The symbols still resolve unversioned, but ld.so walks the VERNEED chain
on load and warns once per absent version definition.

Emptying the libxml2 VERNEED entry's aux list causes LIEF to drop the
entry on write. That alone would leave dynamic symbols pointing at
non-existent version indexes, so we also reset those indexes to 0 (a
plain unversioned lookup against libxml2.so.16).
"""

import sys

import lief


def patch(path: str) -> None:
    elf = lief.parse(path)
    if elf is None:
        return

    dropped_indexes: set[int] = set()
    for req in elf.symbols_version_requirement:
        if req.name.startswith("libxml2"):
            for aux in list(req.get_auxiliary_symbols()):
                dropped_indexes.add(aux.other)
                req.remove_aux_requirement(aux)

    if not dropped_indexes:
        return

    for sym in elf.dynamic_symbols:
        if sym.has_version and sym.symbol_version.value in dropped_indexes:
            sym.symbol_version.value = 0

    elf.write(path)


if __name__ == "__main__":
    for arg in sys.argv[1:]:
        patch(arg)
