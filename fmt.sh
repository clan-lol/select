#!/usr/bin/env nix-shell
#!nix-shell -i bash -p nixfmt-rfc-style
set -efux

nixfmt "$@"
