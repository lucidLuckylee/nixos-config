#!/usr/bin/env bash
# Heavier interpreter for depth.py: torch + transformers on top of the usual
# numpy/pillow/scipy. Kept separate from py.sh because building this closure
# takes minutes and the layer scripts do not need it.
exec nix shell --impure --expr 'let pkgs = import (builtins.getFlake "nixpkgs") { system = builtins.currentSystem; }; in [ (pkgs.python3.withPackages (ps: with ps; [ numpy pillow scipy torch torchvision transformers ])) ]' -c python3 "$@"
