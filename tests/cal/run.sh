#!/bin/bash
##
# @file run.sh
# @brief Run a calibration, or every one, and append what it found to its
#        record.
# @details run.sh [NAME [ARGS...]]. NAME is lane, cable or merge, and ARGS
#          go to it. With no NAME, every one in turn, merge three times,
#          with no load added, then one and four busy loops for every CPU:
#          an hour or more, and the machine is saturated for most of it.
#          Each run appends to tests/cal/data/NAME.txt and to nothing
#          else: an @ run line saying when and what was run; an @ icc line
#          naming the commit, or none, and saying clean, or unknown when
#          git could not tell, or changed and then an @ changed line for
#          every path that differed from it; an @ box line saying
#          what machine; everything the calibration printed; and an @ end
#          line saying when it ended, with what status, and the load then.
#          A run cut off has no @ end, and the run after it starts on a
#          line of its own. A record is a cal certificate: it is
#          committed, nothing in it is ever changed or taken out, and
#          tests/cal.sh checks that.
# @stdin nothing
# @stdout everything the calibration printed, as it goes into the record
# @stderr the reason, when NAME is not a calibration
# @exit 0 every calibration run found what the SKILL.md files say;
#       otherwise the status of the first that did not
#
# Copyright (c) 2026 Brian Case. All rights reserved.
# AI contributor: Claude (Anthropic)
#
# MIT Licence. See LICENCE.TXT
##
set -eu
export LC_ALL=C
cd "$(dirname "$0")/../.."

##
# @fn vRun()
# @brief Run one calibration and append its run to its record.
# @param $1 osName - lane, cable or merge
# @param $2... aArgs - what the calibration takes
# @stdout everything the calibration printed
# @global nFirst - set to the calibration's status, when it is the first
#         that failed
# @return 0
##
vRun() {
  local osName=$1
  shift
  local pRecord=tests/cal/data/$osName.txt
  local osCommit
  local osChanged
  local osTree=clean
  local nStatus
  osCommit=$(git rev-parse --verify -q HEAD 2> /dev/null) || osCommit=none
  if osChanged=$(git status --porcelain -- . ':!tests/cal/data' 2> /dev/null)
  then
    [ -z "$osChanged" ] || osTree=changed
  else
    osChanged=
    osTree=unknown
  fi
  # A run cut off, the machine gone from under it, can end halfway along a
  # line. The next starts on a line of its own, so that line stays as it was
  # left and this run's @ run is not read as part of it.
  [ ! -s "$pRecord" ] || [ -z "$(tail -c 1 "$pRecord")" ] ||
    echo >> "$pRecord"
  {
    echo "@ run $(date -u +%Y-%m-%dT%H:%M:%SZ) $osName $*"
    echo "@ icc $osCommit $osTree"
    [ -z "$osChanged" ] || sed 's/^/@ changed /' <<< "$osChanged"
    echo "@ box $(nproc) cpus, load $(cut -d' ' -f1-3 /proc/loadavg)," \
      "Linux $(uname -r) $(uname -m), bash $BASH_VERSION," \
      "coreutils $(dd --version | awk 'NR == 1 {print $NF}')," \
      "$(awk -F': ' '/^model name/ {print $2; exit}' /proc/cpuinfo)"
  } >> "$pRecord"
  "tests/cal/$osName.sh" "$@" 2>&1 | tee -a "$pRecord"
  nStatus=${PIPESTATUS[0]}
  echo "@ end $(date -u +%Y-%m-%dT%H:%M:%SZ) status $nStatus," \
    "load $(cut -d' ' -f1-3 /proc/loadavg)" >> "$pRecord"
  [ "$nStatus" -eq 0 ] || [ "$nFirst" -ne 0 ] || nFirst=$nStatus
}

nFirst=0
if [ $# -eq 0 ]; then
  vRun lane
  vRun cable
  vRun merge 0
  vRun merge 1
  vRun merge 4
else
  case $1 in
    lane|cable|merge) vRun "$@" ;;
    *) echo "not a calibration: $1" >&2; exit 1 ;;
  esac
fi
exit "$nFirst"
