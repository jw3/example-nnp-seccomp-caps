#!/usr/bin/env bash

set -euo pipefail

# do not use mktemp, perm issues ensure
export TMPDIR="/tmp/testing-nnp"
mkdir -p "$TMPDIR"
trap 'rm -rf "$TMPDIR" 2>/dev/null || true' EXIT

./build.sh "$TMPDIR"
./test.sh "$TMPDIR"
