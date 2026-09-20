#!/bin/bash
# tests/run.sh
# Run every piece's harness, bottom up. Each one proves its own piece
# against the pieces below it, in this same tree.
# Copyright (c) 2026 Brian Case. All rights reserved.
# AI contributor: Claude (Anthropic)
#
# MIT License text omitted for brevity, See LICENCE.TXT
set -eu
cd "$(dirname "$0")/.."
for p in pipes frames tee merge patch bridge; do
  printf '%-8s' "$p"; "tests/$p.sh"
done
