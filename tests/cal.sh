#!/bin/bash
##
# @file cal.sh
# @brief Prove the calibration records only ever grew.
# @details Every commit there is that touched tests/cal/data, against each
#          of its parents, and the tree as it stands against the last: no
#          line in a record taken out or changed, no record removed or
#          renamed, and every record text. A record is a cal certificate,
#          to be looked up years after, and a run is only ever added to
#          it. The calibrations themselves are not run here: they take an
#          hour or more and load the machine, and tests/cal/run.sh runs
#          them when asked.
# @stdin nothing
# @stdout ok, once the check has passed
# @stderr every record a line was taken out of, by commit
# @exit 0 every record only grew; 1 one did not
#
# Copyright (c) 2026 Brian Case. All rights reserved.
# AI contributor: Claude (Anthropic)
#
# MIT Licence. See LICENCE.TXT
##
set -eu
cd "$(dirname "$0")/.."
if ! git rev-parse --verify -q HEAD > /dev/null 2>&1; then
  echo "ok, not a checkout: no history to look at"
  exit 0
fi
{
  git log -m --no-renames --format='commit %H' --numstat -- tests/cal/data
  echo 'commit the tree as it stands'
  git diff --no-renames --numstat HEAD -- tests/cal/data
} | awk -F '\t' '
  /^commit / { osCommit = substr($0, 8); next }
  NF == 3 && $2 != "0" {
    print "taken out of " $3 ", or not text: " osCommit > "/dev/stderr"
    bOut = 1
  }
  END { exit bOut }'
echo ok
