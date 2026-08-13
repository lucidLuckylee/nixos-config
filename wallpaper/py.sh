#!/usr/bin/env bash
# numpy + pillow + scipy in one interpreter.
#
# `nix shell nixpkgs#python3Packages.numpy` does not work: it puts the package
# in PATH but the interpreter it also pulls in cannot see the separate output,
# so the import fails. withPackages builds an interpreter that has them.
exec nix shell --impure --expr 'let pkgs = import (builtins.getFlake "nixpkgs") { system = builtins.currentSystem; }; in [ (pkgs.python3.withPackages (ps: with ps; [ numpy pillow scipy ])) ]' -c python3 "$@"
