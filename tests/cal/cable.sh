#!/bin/bash
##
# @file cable.sh
# @brief Calibrate what Patch's SKILL.md says a cable DEPTH pipes deep
#        holds, nobody reading.
# @details cable.sh [RUNS [DEPTH...]]. RUNS, a count more than zero, is
#          how many runs at each DEPTH, default 3, and the DEPTHs default
#          to 1 2 3 4 5 8 12 24. Each run makes a mesh 3 of 2 lanes at
#          that DEPTH and writes blocks of 4096 three ways, until the next
#          would wait. One dd a block into lane 0 of seat 0's cable to
#          seat 1, at the cable's first pipe: 17 DEPTH - 1 blocks. One dd
#          a block into seat 1's write end, through its own pipe and tee
#          first: 17 DEPTH + 16, on both its cables. One dd streaming into
#          seat 0's cable to seat 2, cut off after 3 seconds, long after it
#          waits: from 17 DEPTH - 1 to 18 DEPTH - 2. Every cable written is
#          drained at the end its seat holds, and gives back what went in,
#          byte for byte.
#          Each run prints one line, ok or off in front as vFound says.
# @stdin nothing
# @stdout one line per run
# @stderr whatever failed outside a run
# @exit 0 every run came out as Patch says; 1 one did not
#
# Copyright (c) 2026 Brian Case. All rights reserved.
# AI contributor: Claude (Anthropic)
#
# MIT Licence. See LICENCE.TXT
##
set -eu
export LC_ALL=C
cd "$(dirname "$0")/../.."
source .claude/skills/icc-lib/scripts/lib
pIccPatch=.claude/skills/icc-patch/scripts
pIccTee=.claude/skills/icc-tee/scripts
nRuns=$(nCount runs "${1-3}")
[ "$nRuns" -gt 0 ] || { echo "runs must be more than zero" >&2; exit 1; }
[ $# -eq 0 ] || shift
[ $# -gt 0 ] || set -- 1 2 3 4 5 8 12 24
aDepths=()
nMost=1
for osDepth in "$@"; do
  aDepths+=("$(nCount depth "$osDepth")")
  [ "${aDepths[-1]}" -gt 0 ] || { echo "depth must be more than zero" >&2
    exit 1; }
  [ "${aDepths[-1]}" -le "$nMost" ] || nMost=${aDepths[-1]}
done
nOff=0
pWork=
pDir=
vArm '[ -z "$pDir" ] || "$pIccPatch/remove" "$pDir" || :
  [ -z "$pWork" ] || rm -rf "$pWork"'
pWork=$(mktemp -d)
nSource=$((18 * nMost + 20))
head -c $((nSource * 4096)) /dev/urandom > "$pWork/source"

##
# @fn aCable()
# @brief Print the pipes of the cable from one seat to another, first to
#        last, one a line.
# @details The last is the read end the map gives the reader. Each one
#          before it is the source of the one-outlet tee into the next, as
#          Tee's list says.
# @param $1 osWriter - the seat that writes into the cable
# @param $2 osReader - the seat that reads it
# @stdout the pipes, first to last
# @global pDir - read, the patch; hSourceOf - read, a tee's outlet to its
#         source
# @return 0
##
aCable() {
  local osWriter=$1
  local osReader=$2
  local pPipe
  local aPipes=()
  pPipe=$(awk -v w="$osWriter" -v r="$osReader" \
    'NR > 1 && $1 == r && $2 == 1 && $4 == w {print $3}' "$pDir/patch")
  aPipes=("$pPipe")
  while [ -n "${hSourceOf[$pPipe]-}" ]; do
    pPipe=${hSourceOf[$pPipe]}
    aPipes=("$pPipe" "${aPipes[@]}")
  done
  printf '%s\n' "${aPipes[@]}"
}

##
# @fn nByBlock()
# @brief Write the source onto a lane one dd a block, nobody reading,
#        until one waits a second; print how many went on.
# @param $1 pLane - the lane
# @stdout the count of blocks
# @stderr the reason, when pLane is not a fifo
# @return 0; it exits 1 instead when pLane is not a fifo
##
nByBlock() {
  local pLane=$1
  local nBlocks=0
  [ -p "$pLane" ] || { echo "not a lane: $pLane" >&2; exit 1; }
  while [ "$nBlocks" -lt "$nSource" ] &&
      timeout 1 dd if="$pWork/source" of="$pLane" bs=4096 skip="$nBlocks" \
        count=1 status=none; do
    nBlocks=$((nBlocks + 1))
  done
  echo "$nBlocks"
}

##
# @fn bDrained()
# @brief Drain a lane, and say whether it gave back the source's first
#        blocks and nothing else.
# @param $1 pLane - the lane
# @param $2 nBlocks - how many blocks went in
# @param $3 pGot - where to put what was drained
# @stdout 1 when it did, 0 when not
# @return 0
##
bDrained() {
  local pLane=$1
  local nBlocks=$2
  local pGot=$3
  timeout 3 dd if="$pLane" bs=4096 status=none > "$pGot" || :
  if [ "$(wc -c < "$pGot")" -eq $((nBlocks * 4096)) ] &&
      cmp -s "$pGot" <(head -c $((nBlocks * 4096)) "$pWork/source"); then
    echo 1
  else
    echo 0
  fi
}

for nDepth in "${aDepths[@]}"; do
  nFirst=$((17 * nDepth - 1))
  nThrough=$((17 * nDepth + 16))
  nStream=$((18 * nDepth - 2))
  for ((iRun = 1; iRun <= nRuns; iRun++)); do
    pDir=$("$pIccPatch/create" mesh 3 2 "$nDepth")
    bUp=0
    ! "$pIccPatch/list" | grep -qx "$pDir up mesh 3 2 $nDepth" || bUp=1
    declare -A hSourceOf=()
    while read -r pTee _ pSource _ osOutlets; do
      ! grep -q "^$pTee " "$pDir/made" ||
        [ "${osOutlets// /}" != "$osOutlets" ] ||
        hSourceOf[$osOutlets]=$pSource
    done < <("$pIccTee/list")
    mapfile -t aTo1 < <(aCable 0 1)
    mapfile -t aTo2 < <(aCable 0 2)
    mapfile -t aFrom1To0 < <(aCable 1 0)
    mapfile -t aFrom1To2 < <(aCable 1 2)
    bDeep=$((${#aTo1[@]} == nDepth && ${#aTo2[@]} == nDepth &&
      ${#aFrom1To0[@]} == nDepth && ${#aFrom1To2[@]} == nDepth))

    nA=$(nByBlock "${aTo1[0]}/0")
    bA=$(bDrained "${aTo1[-1]}/0" "$nA" "$pWork/a")

    # --foreground sends the INT to dd alone: sent to its group as well,
    # a second INT can end dd before it says how many records went out
    timeout --foreground -s INT 3 dd if="$pWork/source" \
      of="${aTo2[0]}/0" bs=4096 2> "$pWork/said" || :
    osOut=$(awk '/records out/ {print $1}' "$pWork/said")
    nB=0
    nPartial=1
    if [[ $osOut =~ ^([0-9]+)\+([0-9]+)$ ]]; then
      nB=${BASH_REMATCH[1]}
      nPartial=${BASH_REMATCH[2]}
    fi
    bB=$(bDrained "${aTo2[-1]}/0" "$nB" "$pWork/b")

    pWriteEnd=$(awk 'NR > 1 && $1 == 1 && $2 == 0 {print $3}' "$pDir/patch")
    nC=$(nByBlock "$pWriteEnd/0")
    bDrained "${aFrom1To0[-1]}/0" "$nC" "$pWork/c0" > "$pWork/b0" &
    bDrained "${aFrom1To2[-1]}/0" "$nC" "$pWork/c2" > "$pWork/b2" &
    wait
    bC=$(($(cat "$pWork/b0") && $(cat "$pWork/b2")))

    "$pIccPatch/remove" "$pDir"
    pDir=
    unset hSourceOf
    vFound $((bUp && bDeep && nA == nFirst && bA && nC == nThrough &&
        bC && nB >= nFirst && nB <= nStream && nPartial == 0 && bB)) \
      "depth $nDepth run $iRun: a dd a block, $nA of $nFirst at the" \
      "cable and $nC of $nThrough at the write end; one dd streaming," \
      "$osOut of $nFirst to $nStream; up $bUp, deep $bDeep, given back" \
      "whole $bA $bC $bB"
  done
done

echo "$nOff off"
[ "$nOff" -eq 0 ]
