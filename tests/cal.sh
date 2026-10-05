#!/bin/bash
##
# @file cal.sh
# @brief Prove no calibration record has lost a line.
# @details Every commit there is that touched tests/cal/data, against each
#          of its parents, and the tree as it stands against HEAD. Where
#          one took a line out of a record, every line the record held
#          before it has to be in the record as it stands now, as many
#          times as it was then: a line put back is not lost, and a run
#          only ever added is never looked at twice. A record removed or
#          renamed has lost every line, and a record has to be text. A
#          record is a cal certificate, to be looked up years after, and a
#          run is only ever added to it. In a shallow clone only the
#          commits there are can be looked at, and it says so. The
#          calibrations themselves are not run here: they take an hour or
#          more and load the machine, and tests/cal/run.sh runs them.
# @stdin nothing
# @stdout ok, once the check has passed, and why it looked at less than
#         every commit when it did
# @stderr the record that lost a line, and the commit it was lost from
# @exit 0 no record has lost a line; 1 one has, or git could not say
#
# Copyright (c) 2026 Brian Case. All rights reserved.
# AI contributor: Claude (Anthropic)
#
# MIT Licence. See LICENCE.TXT
##
set -eu
export LC_ALL=C
cd "$(dirname "$0")/.."
source .claude/skills/icc-lib/scripts/lib
pData=tests/cal/data
if [ ! -e .git ] && ! git rev-parse --git-dir > /dev/null 2>&1; then
  echo "ok, not a checkout: no history to look at"
  exit 0
fi
pWork=
vArm '[ -z "$pWork" ] || rm -rf "$pWork"'
pWork=$(mktemp -d)

##
# @fn vStillHolds()
# @brief Stop unless a record as it stands holds every line it held at a
#        commit, as many times.
# @param $1 osCommit - the commit, as git names one
# @param $2 pRecord - the record's path
# @stderr the record and the commit, when it does not
# @return 0; it exits 1 instead when the record does not
##
vStillHolds() {
  local osCommit=$1
  local pRecord=$2
  git show "$osCommit:$pRecord" > "$pWork/then"
  if [ ! -f "$pRecord" ] || ! awk '
      FILENAME == ARGV[1] { nNow[$0]++; next }
      --nNow[$0] < 0 { exit 1 }' "$pRecord" "$pWork/then"; then
    echo "lost from $pRecord: a line it held at $osCommit" >&2
    exit 1
  fi
}

##
# @fn vNothingLost()
# @brief Stop at a record a diff took a line out of, unless every line is
#        back; and at one that is not text.
# @param $1 osBefore - the commit the diff is from
# @param $2... aDiff - what git diff takes after it, to the other side
# @stderr the record, when one lost a line or is not text
# @return 0; it exits 1 instead at such a record
##
vNothingLost() {
  local osBefore=$1
  shift
  local osStat
  local osAdded
  local osTaken
  local pRecord
  osStat=$(git diff --no-renames --numstat "$osBefore" "$@" -- "$pData")
  while IFS=$'\t' read -r osAdded osTaken pRecord; do
    [ -n "$pRecord" ] || continue
    if [ "$osTaken" = - ]; then
      echo "not text: $pRecord" >&2
      exit 1
    fi
    [ "$osTaken" -eq 0 ] || vStillHolds "$osBefore" "$pRecord"
  done <<< "$osStat"
}

osLog=$(git log --full-history --format='%H %P' -- "$pData")
while read -r osCommit osParents; do
  for osParent in $osParents; do
    vNothingLost "$osParent" "$osCommit"
  done
done <<< "$osLog"
! git rev-parse --verify -q HEAD > /dev/null || vNothingLost HEAD
if [ "$(git rev-parse --is-shallow-repository)" = true ]; then
  echo "ok, of the commits a shallow clone has"
else
  echo ok
fi
