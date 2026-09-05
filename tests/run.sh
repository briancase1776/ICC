#!/bin/sh
# Run every piece's harness, bottom up, each against the siblings beside it.
set -eu
cd "$(dirname "$0")/.."
for r in ICC-Pipes ICC-Frames ICC-Tee ICC-Merge ICC-Patch; do
  printf '%-11s' "$r"; sh "$r/tests/run.sh"
done
