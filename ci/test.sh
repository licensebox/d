#!/usr/bin/env bash
set -euo pipefail
mkdir -p build/install
ldc2 -Isrc -L-L"$LICENSEBOX_LIB_DIR" -L-llicensebox src/licensebox.d tests/binding.d -of=build/binding
./build/binding
ldc2 -Isrc -L-L"$LICENSEBOX_LIB_DIR" -L-llicensebox src/licensebox.d tests/adapter.d -of=build/adapter
DUB_HOME="$PWD/build/dub-home" LIBRARY_PATH="$LICENSEBOX_LIB_DIR:${LIBRARY_PATH:-}" dub build --compiler=ldc2 --build=release
install -m644 src/licensebox.d build/install/
ldc2 -Ibuild/install -L-L"$LICENSEBOX_LIB_DIR" -L-llicensebox build/install/licensebox.d examples/status.d -of=build/consumer
