#!/bin/bash
##
# @file run.sh
# @brief Run every piece's harness, bottom up.
# @details Each one proves its own piece against the pieces below it, in
#          this same tree. The run stops at the first harness that fails.
# @stdin nothing
# @stdout each piece's name, then what its harness printed
# @stderr whatever a failing harness printed
# @exit 0 every harness passed; otherwise the status of the first that
#       did not
#
# Copyright (c) 2026 Brian Case. All rights reserved.
# AI contributor: Claude (Anthropic)
#
# MIT Licence. See LICENCE.TXT
##
set -eu
cd "$(dirname "$0")/.."
for osPiece in pipes frames tee merge patch bridge; do
  printf '%-8s' "$osPiece"
  "tests/$osPiece.sh"
done
