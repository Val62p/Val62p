#!/usr/bin/env sh
# Toutes les vérifications locales, dans l'ordre : format, lint, tests, build, contrôle de la place.
# Prérequis : rojo, stylua, selene et lune dans le PATH (voir rokit.toml).
set -eu
cd "$(dirname "$0")/.."

echo "== StyLua (format)"
stylua --check src tests tools

echo "== Selene (lint)"
selene src tools

echo "== Tests Lune"
lune run tests/run

echo "== Build Rojo"
mkdir -p build
rojo build default.project.json -o build/StealAMeme.rbxl

echo "== Contrôle de la place"
lune run tools/check-place build/StealAMeme.rbxl
