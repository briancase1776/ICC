#!/bin/bash
##
# @file merge.sh
# @brief Calibrate what Patch's SKILL.md says of a tee into p's merge, with
#        load added and without.
# @details merge.sh [LOAD [TRIALS]]. LOAD, a count, default 0, is how many
#          busy loops run for every CPU throughout; TRIALS, a count more
#          than zero, default 100, how many trials each case has. A case
#          is a mesh-p 3 of 2 lanes, whose three seats each put on at once,
#          off one release, a length line, a SEAT line and SIZE bytes of
#          a, b or c, printf into dd bs=4096, with iflag=fullblock or
#          without, and p takes what the three come to off its read end,
#          head -c. Every seat reading all along: SIZE 3000, 8000 and
#          20000 at DEPTH 1, 100000 at 2, 400000 at 6. The same 20000
#          written straight into a merge's three inlets, no tee. 100000 at
#          DEPTH 1 and 2, seat 2 reading nothing for the first second.
#          Each trial prints a line: how long p took from the release, and
#          whole and the order the seats came in; or cut and the runs p
#          got, a header as h and a body as its letter, with their
#          lengths; or wrong, the writers' and p's status, how much p got
#          and how much was left, and the runs. Each case then prints a
#          line, ok or off in front as vFound says: in every trial nothing
#          lost or wrong; 3000 with the flag whole every time, as Patch
#          says is certain; seat 2 stalled at DEPTH 1, cut every time; and
#          with no load added, every other case whole every time. How
#          often a case is cut under load is what was found, and passes
#          either way.
# @stdin nothing
# @stdout one line per trial, and one per case
# @stderr whatever failed outside a trial
# @exit 0 every case came out as Patch says; 1 one did not
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
pIccPipes=.claude/skills/icc-pipes/scripts
pIccMerge=.claude/skills/icc-merge/scripts
pIccPatch=.claude/skills/icc-patch/scripts
nLoad=$(nCount load "${1-0}")
nTrials=$(nCount trials "${2-100}")
[ "$nTrials" -gt 0 ] || { echo "trials must be more than zero" >&2
  exit 1; }
nOff=0
pWork=
pDir=
pMerge=
aInlets=()
pOutlet=
aBusy=()
aDrains=()

##
# @fn vTake()
# @brief Stop a case's drains, and take every piece it made.
# @global aDrains, pDir, pMerge, aInlets, pOutlet - read, and emptied
# @return 0
##
vTake() {
  local pPipe
  if [ ${#aDrains[@]} -gt 0 ]; then
    kill "${aDrains[@]}" 2> /dev/null || :
    wait "${aDrains[@]}" 2> /dev/null || :
  fi
  aDrains=()
  [ -z "$pDir" ] || "$pIccPatch/remove" "$pDir" || :
  [ -z "$pMerge" ] || "$pIccMerge/remove" "$pMerge" || :
  for pPipe in "${aInlets[@]}" $pOutlet; do
    "$pIccPipes/remove" "$pPipe" || :
  done
  pDir=
  pMerge=
  aInlets=()
  pOutlet=
}
vArm '[ ${#aBusy[@]} -eq 0 ] || kill "${aBusy[@]}" 2> /dev/null || :
  vTake
  [ -z "$pWork" ] || rm -rf "$pWork"'
pWork=$(mktemp -d)
mkfifo "$pWork/go"
exec {fdGo}<> "$pWork/go"
for ((iBusy = 0; iBusy < nLoad * $(nproc); iBusy++)); do
  timeout 86400 yes > /dev/null 2>&1 &
  aBusy+=($!)
done
[ "$nLoad" -eq 0 ] || sleep 1

##
# @fn vDrain()
# @brief Drain every read end a seat holds, until stopped.
# @param $1 osSeat - the seat
# @global pDir - read, the patch; aDrains - added to
# @return 0
##
vDrain() {
  local osSeat=$1
  local pEnd
  for pEnd in $(awk -v s="$osSeat" '$1 == s && $2 == 1 {print $3}' \
      "$pDir/patch"); do
    timeout 86400 dd if="$pEnd/0" of=/dev/null bs=65536 status=none \
      2> /dev/null &
    aDrains+=($!)
  done
}

##
# @fn vCase()
# @brief Run one case's trials and say what they came to.
# @param $1 eHow - reading, no-tee or stalled
# @param $2 nSize - the bytes of a, b or c each seat puts on
# @param $3 nDepth - the patch's DEPTH; nothing with no tee
# @param $4 osFlag - iflag=fullblock, or nothing
# @stdout a line per trial, and one for the case
# @global nOff - added to; the pieces it makes - set, and taken
# @return 0
##
vCase() {
  local eHow=$1
  local nSize=$2
  local nDepth=$3
  local osFlag=$4
  local osCase="$eHow $nSize${nDepth:+ depth $nDepth} ${osFlag:-no flag}"
  local aWrite=()
  local pRead
  local aBody=()
  local nTotal=0
  local iSeat
  local iTrial
  local aWriters=()
  local pidRead
  local nMs
  local osWriters
  local nRead
  local nLeft
  local osOrder
  local osRuns
  local nWhole=0
  local nCut=0
  local nWrong=0
  local nReading
  local osPerm
  local pEnd
  local pidWriter
  local nStatus
  if [ "$eHow" = no-tee ]; then
    for iSeat in 0 1 2; do
      aInlets+=("$("$pIccPipes/create" 2)")
    done
    pOutlet=$("$pIccPipes/create" 2)
    pMerge=$("$pIccMerge/create" "$pOutlet" 0 "${aInlets[@]}")
    aWrite=("${aInlets[@]}")
    pRead=$pOutlet
  else
    pDir=$("$pIccPatch/create" mesh-p 3 2 "$nDepth")
    for iSeat in 0 1 2; do
      aWrite+=("$(awk -v s="$iSeat" '$1 == s && $2 == 0 {print $3}' \
        "$pDir/patch")")
    done
    pRead=$(awk '$1 == "p" && $2 == 1 {print $3}' "$pDir/patch")
    vDrain 0
    vDrain 1
    [ "$eHow" = stalled ] || vDrain 2
  fi
  for iSeat in 0 1 2; do
    aBody+=("$(head -c "$nSize" /dev/zero | tr '\0' "${osLetters:iSeat:1}")")
    printf '%s\nSEAT %s\n%s' "$nSize" "$iSeat" "${aBody[iSeat]}" \
      > "$pWork/m$iSeat"
    nTotal=$((nTotal + ${#nSize} + 8 + nSize))
  done
  for osPerm in 012 021 102 120 201 210; do
    cat "$pWork/m${osPerm:0:1}" "$pWork/m${osPerm:1:1}" \
      "$pWork/m${osPerm:2:1}" > "$pWork/w$osPerm"
  done
  echo "case $osCase: load $(cut -d' ' -f1-3 /proc/loadavg)"
  for ((iTrial = 1; iTrial <= nTrials; iTrial++)); do
    aWriters=()
    for iSeat in 0 1 2; do
      (
        read -r -N 1 -t 30 _ < "$pWork/go" || exit 3
        printf '%s\nSEAT %s\n%s' "$nSize" "$iSeat" "${aBody[iSeat]}" |
          timeout 60 dd of="${aWrite[iSeat]}/0" bs=4096 $osFlag status=none
      ) &
      aWriters+=($!)
    done
    (
      nStatus=0
      timeout 60 head -c "$nTotal" "$pRead/0" > "$pWork/got" || nStatus=$?
      echo "${EPOCHREALTIME//[!0-9]/}" > "$pWork/done"
      exit "$nStatus"
    ) &
    pidRead=$!
    sleep 0.2
    nMs=${EPOCHREALTIME//[!0-9]/}
    printf xxx >&"$fdGo"
    if [ "$eHow" = stalled ]; then
      sleep 1
      nReading=${#aDrains[@]}
      vDrain 2
    fi
    osWriters=
    for pidWriter in "${aWriters[@]}"; do
      nStatus=0
      wait "$pidWriter" || nStatus=$?
      osWriters=$osWriters$nStatus
    done
    nRead=0
    wait "$pidRead" || nRead=$?
    nMs=$((($(cat "$pWork/done") - nMs) / 1000))
    if [ "$eHow" = stalled ]; then
      sleep 0.3
      kill "${aDrains[@]:nReading}" 2> /dev/null || :
      wait "${aDrains[@]:nReading}" 2> /dev/null || :
      aDrains=("${aDrains[@]:0:nReading}")
      for pEnd in $(awk '$1 == 2 && $2 == 1 {print $3}' "$pDir/patch"); do
        timeout 0.3 dd if="$pEnd/0" of=/dev/null bs=65536 status=none || :
      done
    fi
    osOrder=
    for osPerm in 012 021 102 120 201 210; do
      ! cmp -s "$pWork/got" "$pWork/w$osPerm" || osOrder=$osPerm
    done
    if [ -n "$osOrder" ] && [ "$osWriters$nRead" = 0000 ]; then
      nWhole=$((nWhole + 1))
      echo "t=$iTrial ${nMs}ms whole $osOrder"
      continue
    fi
    nLeft=$(timeout 1 dd if="$pRead/0" bs=65536 status=none | wc -c)
    osRuns=$(tr '\n' n < "$pWork/got" |
      LC_ALL=C grep -aoE 'a+|b+|c+|[^abc]+' |
      awk '{k = substr($0, 1, 1); if (k !~ /[abc]/) k = "h"
        printf "%s%s%d", (NR > 1 ? " " : ""), k, length($0)}')
    if [ "$osWriters$nRead$nLeft" = 00000 ] &&
        [ "$(wc -c < "$pWork/got")" -eq "$nTotal" ] &&
        [ "$(tr -cd a < "$pWork/got" | wc -c)" -eq "$nSize" ] &&
        [ "$(tr -cd b < "$pWork/got" | wc -c)" -eq "$nSize" ] &&
        [ "$(tr -cd c < "$pWork/got" | wc -c)" -eq "$nSize" ]; then
      nCut=$((nCut + 1))
      echo "t=$iTrial ${nMs}ms cut $osRuns"
    else
      nWrong=$((nWrong + 1))
      echo "t=$iTrial ${nMs}ms wrong, writers $osWriters, p $nRead," \
        "$(wc -c < "$pWork/got") of $nTotal, $nLeft left: $osRuns"
    fi
  done
  vTake
  osCase="$osCase, $nTrials trials: $nWhole whole, $nCut cut, $nWrong"
  osCase="$osCase lost or wrong"
  if [ "$eHow" = stalled ] && [ "$nDepth" -eq 1 ]; then
    vFound $((nCut == nTrials)) "$osCase"
  elif [ "$eHow" = reading ] && [ "$nSize" -eq 3000 ] && [ -n "$osFlag" ]
  then
    vFound $((nWhole == nTrials)) "$osCase"
  elif [ "$nLoad" -eq 0 ]; then
    vFound $((nWhole == nTrials)) "$osCase"
  else
    vFound $((nWrong == 0)) "$osCase"
  fi
}

osLetters=abc
for osFlag in iflag=fullblock ''; do
  for osSpec in 3000:1 8000:1 20000:1 100000:2 400000:6; do
    vCase reading "${osSpec%:*}" "${osSpec#*:}" "$osFlag"
  done
done
for osFlag in iflag=fullblock ''; do
  vCase no-tee 20000 '' "$osFlag"
done
for osFlag in iflag=fullblock ''; do
  for nDepth in 1 2; do
    vCase stalled 100000 "$nDepth" "$osFlag"
  done
done

echo "$nOff off"
[ "$nOff" -eq 0 ]
