#!/bin/sh
# tests/run.sh
# Run every piece's harness, bottom up, each against the siblings beside it.
# Copyright (c) 2026 Brian Case. All rights reserved.
# AI contributor: Claude (Anthropic)
#
# MIT License text omitted for brevity, see LICENSE
set -eu
cd "$(dirname "$0")/.."
for r in ICC-Pipes ICC-Frames ICC-Tee ICC-Merge ICC-Patch; do
  printf '%-11s' "$r"; sh "$r/tests/run.sh"
done
