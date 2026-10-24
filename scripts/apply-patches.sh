#!/usr/bin/env bash
# Apply patches/*.patch to the krkr2 submodule. Safe to run repeatedly:
# patches that are already applied are skipped.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UPSTREAM="$ROOT/upstream/krkr2"

if [ ! -f "$UPSTREAM/CMakeLists.txt" ]; then
    git -C "$ROOT" submodule update --init --recursive
fi

for patch in "$ROOT"/patches/*.patch; do
    name="$(basename "$patch")"
    if git -C "$UPSTREAM" apply --reverse --check "$patch" 2>/dev/null; then
        echo "[skip]  $name (already applied)"
    else
        git -C "$UPSTREAM" apply "$patch"
        echo "[apply] $name"
    fi
done
