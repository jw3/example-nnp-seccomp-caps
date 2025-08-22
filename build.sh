#!/usr/bin/env bash

TMPDIR="$1"
mkdir "$TMPDIR/build"
cmake -S. -B "$TMPDIR/build" -DCMAKE_INSTALL_PREFIX="$TMPDIR"
cmake --build "$TMPDIR/build"
cmake --install "$TMPDIR/build"
