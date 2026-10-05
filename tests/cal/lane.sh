#!/bin/bash
##
# @file lane.sh
# @brief Calibrate what Pipes' SKILL.md says of a lane: iflag=fullblock,
#        exact reads, pages, and opens.
# @details lane.sh [RUNS]. RUNS, a count, default 10, is how many times
#          each case runs. printf of 10 to 300000 bytes into dd bs=4096
#          onto a lane, with iflag=fullblock and without, head -c taking
#          them off: it finishes, every write but the last is whole, and
#          the bytes come back. A writer of 100 pieces of 100 bytes that
#          ends: 2+1 records out with the flag. A dd reading a lane fed
#          100 bytes every 50 ms, then cut off: without the flag all of it
#          went on; with it only whole blocks did, and the rest is lost.
#          Two messages back to back, a count line and N bytes each: read
#          -r and head -c take the first and leave the second whole, and
#          dd count=1 takes what one read returns. Nobody reading, what a
#          lane holds before a write waits, written 4096, 100 or 2049 at a
#          time, 100 then 4096s, and 4096s after a read freed 100. While
#          the hold is up, every open opens; once it is down, < and >
#          block and <> opens. Every case prints one line, ok or off in
#          front as vFound says.
# @stdin nothing
# @stdout one line per case
# @stderr whatever failed outside a case
# @exit 0 every case came out as Pipes says; 1 one did not
#
# Copyright (c) 2026 Brian Case. All rights reserved.
# AI contributor: Claude (Anthropic)
#
# MIT Licence. See LICENCE.TXT
##
set -eu
cd "$(dirname "$0")/../.."
source .claude/skills/icc-lib/scripts/lib
pIccPipes=.claude/skills/icc-pipes/scripts
nRuns=$(nCount runs "${1-10}")
[ "$nRuns" -gt 0 ] || { echo "runs must be more than zero" >&2; exit 1; }
nOff=0
pWork=
pA=
pB=
vArm '[ -z "$pA" ] || "$pIccPipes/remove" "$pA"
  [ -z "$pB" ] || "$pIccPipes/remove" "$pB"
  [ -z "$pWork" ] || rm -rf "$pWork"'
pWork=$(mktemp -d)
pA=$("$pIccPipes/create" 2)
pB=$("$pIccPipes/create" 2)
osText=$(head -c 225000 /dev/urandom | base64 -w0)

##
# @fn nDrain()
# @brief Take everything off a lane, and print how many bytes it was.
# @param $1 pLane - the lane
# @stdout the count
# @return 0
##
nDrain() {
  local pLane=$1
  timeout 0.3 dd if="$pLane" bs=65536 status=none | wc -c
}

##
# @fn nFill()
# @brief Write one file onto a lane, one dd a time, nobody reading, until
#        a write waits; print how many bytes went on.
# @param $1 pLane - the lane
# @param $2 pChunk - what each write writes
# @stdout the count
# @return 0
##
nFill() {
  local pLane=$1
  local pChunk=$2
  local nWrites=0
  while timeout 0.5 dd if="$pChunk" of="$pLane" bs=4096 status=none; do
    nWrites=$((nWrites + 1))
  done
  echo $((nWrites * $(wc -c < "$pChunk")))
}

# printf into dd bs=4096 onto a lane: an input that ends
for nSize in 10 100 1000 4095 4096 4097 8191 8192 8193 12288 50000 \
    65535 65536 65537 100000 131072 200000 262144 299999 300000; do
  printf '%s' "${osText:0:nSize}" > "$pWork/want"
  osWant="$((nSize / 4096))+$((nSize % 4096 > 0)) records out"
  for osFlag in iflag=fullblock ''; do
    nDone=0
    nWhole=0
    nAsBlocks=0
    for ((iRun = 0; iRun < nRuns; iRun++)); do
      timeout 20 head -c "$nSize" "$pA/0" > "$pWork/got" &
      nStatus=0
      printf '%s' "${osText:0:nSize}" |
        timeout 15 dd bs=4096 $osFlag of="$pA/0" 2> "$pWork/said" ||
        nStatus=$?
      wait $! || :
      [ "$nStatus" -ne 0 ] || nDone=$((nDone + 1))
      ! cmp -s "$pWork/got" "$pWork/want" || nWhole=$((nWhole + 1))
      ! grep -qx "$osWant" "$pWork/said" || nAsBlocks=$((nAsBlocks + 1))
    done
    vFound $((nDone == nRuns && nWhole == nRuns && nAsBlocks == nRuns)) \
      "ended $nSize ${osFlag:-no flag}: $nRuns runs, $nDone finished," \
      "$nWhole whole, $nAsBlocks $osWant"
  done
done

# 100 pieces of 100 bytes that end: the flag makes whole blocks of them
for osFlag in iflag=fullblock ''; do
  declare -A hSaid=()
  nWhole=0
  for ((iRun = 0; iRun < nRuns; iRun++)); do
    timeout 20 head -c 10000 "$pA/0" > "$pWork/got" &
    for ((iPiece = 0; iPiece < 100; iPiece++)); do
      printf '%s' "${osText:iPiece * 100:100}"
      sleep 0.005
    done | timeout 15 dd bs=4096 $osFlag of="$pA/0" 2> "$pWork/said"
    wait $! || :
    [ "$(cat "$pWork/got")" != "${osText:0:10000}" ] || nWhole=$((nWhole + 1))
    osSaid=$(awk '/records out/ {print $1}' "$pWork/said")
    hSaid[$osSaid]=$((${hSaid[$osSaid]-0} + 1))
  done
  osSaid=
  for osOut in "${!hSaid[@]}"; do
    osSaid="$osSaid, ${hSaid[$osOut]} $osOut"
  done
  nBlocks=${hSaid[2+1]-0}
  if [ -n "$osFlag" ]; then
    vFound $((nWhole == nRuns && nBlocks == nRuns)) \
      "pieces of 100, $osFlag: $nRuns runs, $nWhole whole$osSaid out"
  else
    vFound $((nWhole == nRuns)) \
      "pieces of 100, no flag: $nRuns runs, $nWhole whole$osSaid out"
  fi
  unset hSaid
done

# a dd reading a lane fed 100 bytes every 50 ms, then cut off
head -c 100 /dev/zero | tr '\0' x > "$pWork/c100"
for nDribbles in 20 60; do
  nPut=$((nDribbles * 100))
  for osFlag in iflag=fullblock ''; do
    if [ -n "$osFlag" ]; then
      nWant=$((nPut / 4096 * 4096))
    else
      nWant=$nPut
    fi
    nAsSaid=0
    osSeen=
    for ((iRun = 0; iRun < nRuns; iRun++)); do
      timeout 30 dd if="$pA/0" of="$pB/0" bs=4096 $osFlag \
        2> "$pWork/said" &
      pidCopier=$!
      for ((iDribble = 0; iDribble < nDribbles; iDribble++)); do
        dd if="$pWork/c100" of="$pA/0" bs=4096 status=none
        sleep 0.05
      done
      sleep 0.5
      nRunning=$(nDrain "$pB/0")
      kill -INT "$pidCopier"
      wait "$pidCopier" || :
      nAfter=$(nDrain "$pB/0")
      nLeft=$(nDrain "$pA/0")
      osSeen="$osSeen $nRunning/$nAfter/$nLeft"
      [ "$nRunning" -ne "$nWant" ] || [ "$nAfter" -ne 0 ] ||
        [ "$nLeft" -ne 0 ] || nAsSaid=$((nAsSaid + 1))
    done
    vFound $((nAsSaid == nRuns)) \
      "lane fed $nPut, ${osFlag:-no flag}: $nRuns runs, $nAsSaid went on" \
      "$nWant and lost $((nPut - nWant)); on, after the cut, left:$osSeen"
  done
done

# two messages back to back: read -r and head -c take one, and no more
for nSize in 1 4095 4096 4097 100000; do
  printf '%s' "${osText:0:nSize}" > "$pWork/m1"
  printf '%s' "${osText:nSize:nSize}" > "$pWork/m2"
  nWhole=0
  for ((iRun = 0; iRun < nRuns; iRun++)); do
    { printf '%s\n' "$nSize"; cat "$pWork/m1"
      printf '%s\n' "$nSize"; cat "$pWork/m2"; } |
      timeout 10 dd of="$pA/0" bs=4096 status=none &
    for iMessage in 1 2; do
      : > "$pWork/o$iMessage"
      timeout 10 bash -c '
        exec {fd}< "$1"
        read -r -u "$fd" nGot && [ "$nGot" = "$2" ] &&
          head -c "$nGot" <&"$fd" > "$3"' _ "$pA/0" "$nSize" \
        "$pWork/o$iMessage" || :
    done
    wait $! || :
    ! cmp -s "$pWork/o1" "$pWork/m1" || ! cmp -s "$pWork/o2" "$pWork/m2" ||
      [ "$(nDrain "$pA/0")" -ne 0 ] || nWhole=$((nWhole + 1))
  done
  vFound $((nWhole == nRuns)) \
    "exact $nSize: $nRuns runs, both whole and nothing left in $nWhole"
done
printf x > "$pA/0"
dd if=/dev/zero of="$pA/0" bs=4096 count=1 status=none
nOne=$(timeout 1 dd if="$pA/0" bs=4096 count=1 status=none | wc -c)
nRest=$(nDrain "$pA/0")
vFound $((nOne == 4096 && nRest == 1)) \
  "dd count=1 after writes of 1 and 4096: took $nOne, left $nRest"

# pages: what a lane holds, nobody reading, before a write waits
head -c 100 /dev/zero > "$pWork/z100"
head -c 2049 /dev/zero > "$pWork/z2049"
head -c 4096 /dev/zero > "$pWork/z4096"
for osCase in 'writes of 4096:65536' 'writes of 100:64000' \
    'writes of 2049:32784' 'one of 100, then 4096s:61540' \
    'one of 4096, 100 read off, then 100s:63996'; do
  nWant=${osCase##*:}
  osSeen=
  nAsSaid=0
  for ((iRun = 0; iRun < nRuns; iRun++)); do
    case ${osCase%:*} in
      'writes of 4096') nHeld=$(nFill "$pA/0" "$pWork/z4096") ;;
      'writes of 100') nHeld=$(nFill "$pA/0" "$pWork/z100") ;;
      'writes of 2049') nHeld=$(nFill "$pA/0" "$pWork/z2049") ;;
      'one of 100, then 4096s')
        dd if="$pWork/z100" of="$pA/0" bs=4096 status=none
        nHeld=$((100 + $(nFill "$pA/0" "$pWork/z4096"))) ;;
      *)
        dd if="$pWork/z4096" of="$pA/0" bs=4096 status=none
        timeout 1 head -c 100 "$pA/0" > /dev/null
        nHeld=$((3996 + $(nFill "$pA/0" "$pWork/z100"))) ;;
    esac
    nDrained=$(nDrain "$pA/0")
    osSeen="$osSeen $nHeld/$nDrained"
    [ "$nHeld" -ne "$nWant" ] || [ "$nDrained" -ne "$nWant" ] ||
      nAsSaid=$((nAsSaid + 1))
  done
  vFound $((nAsSaid == nRuns)) "pages, ${osCase%:*}: $nRuns runs," \
    "$nAsSaid held $nWant; held and drained:$osSeen"
done

# opens: none blocks while the hold is up; < and > block once it is down
for osOpen in '<' '>' '<>'; do
  nOpened=0
  for ((iRun = 0; iRun < 20 * nRuns; iRun++)); do
    ! timeout 1 bash -c "exec 3$osOpen \"\$1\"" _ "$pA/0" ||
      nOpened=$((nOpened + 1))
  done
  vFound $((nOpened == 20 * nRuns)) \
    "open $osOpen, hold up: $((20 * nRuns)) tries, $nOpened opened"
done
kill "$(cat "$pB/pid")"
while "$pIccPipes/list" | grep -qx "$pB up"; do
  sleep 0.1
done
for osOpen in '<' '>' '<>'; do
  nOpened=0
  for ((iRun = 0; iRun < nRuns; iRun++)); do
    ! timeout 0.5 bash -c "exec 3$osOpen \"\$1\"" _ "$pB/0" ||
      nOpened=$((nOpened + 1))
  done
  if [ "$osOpen" = '<>' ]; then
    nWant=$nRuns
  else
    nWant=0
  fi
  vFound $((nOpened == nWant)) \
    "open $osOpen, hold down: $nRuns tries, $nOpened opened"
done

echo "$nOff off"
[ "$nOff" -eq 0 ]
