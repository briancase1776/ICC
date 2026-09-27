#!/bin/bash
##
# @file lock.sh
# @brief Prove the lock: one holder per path, across processes, for a while.
# @details Prove the lock: bad arguments refused; a path taken and listed;
#          another path taken beside it; every spelling of the held path
#          waiting, and a wait cut off by timeout or by TERM leaving
#          nothing behind, not even something still waiting; a hold that a
#          hangup leaves standing; a create getting the path the moment
#          the holder gives it back, or the hold is killed, or its lease
#          runs out, and remove saying a lock lapsed; a
#          create cut off once it has the lock taking its directory and the
#          lock with it; four processes taking turns on one path and never
#          overlapping; and remove and list leaving alone what create did
#          not make. Locks paths in a directory of its own, and takes the
#          files under /tmp/icc-lock/ that those paths made, since nothing
#          else can be waiting on them.
# @stdin nothing
# @stdout ok, once every check has passed
# @stderr whatever a failing check printed
# @exit 0 every check passed; otherwise the status of the first that
#       did not
#
# Copyright (c) 2026 Brian Case. All rights reserved.
# AI contributor: Claude (Anthropic)
#
# MIT Licence. See LICENCE.TXT
##
set -eu
cd "$(dirname "$0")/.."
source .claude/skills/icc-lib/scripts/lib
pIccLock=$(cd .claude/skills/icc-lock/scripts && pwd)
# Armed before anything is made, as icc-lib's vArm says: the one cleanup takes
# whatever is named, so a check that fails leaves nothing of the harness's
# own behind. A pid is emptied once it is done, because it is soon someone
# else's.
pWork=
pHeld=
pBeside=
pFake=
pidSleep=
pidWaiter=
aWorkers=()
aLocks=()
vArm '[ -n "$pidWaiter" ] && kill "$pidWaiter" 2>/dev/null || :
      [ -n "$pidSleep" ] && kill "$pidSleep" 2>/dev/null || :
      [ ${#aWorkers[@]} -eq 0 ] || kill "${aWorkers[@]}" 2>/dev/null || :
      for pHold in $pHeld $pBeside; do
        "$pIccLock/remove" "$pHold" 2>/dev/null || :
      done
      [ -n "$pFake" ] && rm -rf "$pFake" || :
      [ ${#aLocks[@]} -eq 0 ] || rm -f "${aLocks[@]}"
      cd /
      [ -n "$pWork" ] && rm -rf "$pWork" || :'
pWork=$(mktemp -d)
cd "$pWork"
pWork=$(pwd -P)

##
# @fn vRefused()
# @brief Run a command that must be refused, and stop here if it is not.
# @details set -e is ignored for a pipeline that begins with !, so `! cmd`
#          states a refusal without ever being able to fail the harness.
#          vRefused() runs the command and stops here if it succeeds.
# @param $1... aCommand - the command and its arguments
# @stderr "not refused" and the command, when it was not; the command's
#         own stderr goes nowhere
# @return 0 the command was refused; it exits 1 instead when it was not
##
vRefused() {
  local aCommand=("$@")
  if "${aCommand[@]}" 2>/dev/null; then
    echo "not refused: ${aCommand[*]}" >&2
    exit 1
  fi
}

##
# @fn nOpeners()
# @brief Print how many descriptors, in every process, have a file open.
# @details Every fd under /proc, compared with the file by -ef, which a
#          builtin test does, so nothing is forked per fd. A hold has the
#          locked file open on one; a create waiting has it on two, its own
#          and its flock's.
# @param $1 pFile - the file
# @stdout the count
# @return 0
##
nOpeners() {
  local pFile=$1
  local pFd
  local nOpen=0
  for pFd in /proc/[0-9]*/fd/*; do
    [ "$pFd" -ef "$pFile" ] 2>/dev/null || continue
    nOpen=$((nOpen + 1))
  done
  echo "$nOpen"
}

##
# @fn vWaiting()
# @brief Wait until a create is waiting for a lock that one hold holds.
# @param $1 pFile - the locked file
# @param $2 pidCreate - the create, which must still be running
# @return 0 once three descriptors have the file open; it exits 1 instead
#         when the create ends first
##
vWaiting() {
  local pFile=$1
  local pidCreate=$2
  while [ "$(nOpeners "$pFile")" -lt 3 ]; do
    kill -0 "$pidCreate"
    sleep 0.1
  done
}

##
# @fn vTake()
# @brief Take a path at once, or stop here, and note its locked file.
# @details Bound by timeout, so a lock that is wrongly held stops the
#          harness instead of hanging it. Called, not captured: the locked
#          file goes on aLocks for the cleanup, and the hold on pTaken.
# @param $1 osPath - the path, as create takes it
# @param $2 nSeconds - the lease
# @global pTaken - set, the hold's directory
# @global aLocks - read and set, every locked file the harness has made
# @return 0; under set -e a create that does not return at once ends the
#         harness
##
vTake() {
  local osPath=$1
  local nSeconds=$2
  pTaken=$(timeout 5 "$pIccLock/create" "$osPath" "$nSeconds")
  aLocks+=("$(sed -n 2p "$pTaken/lock")")
}

# Refused, in the words the pieces use: no SECONDS, SECONDS not a count or
# none, a newline anywhere in PATH, even the one $( ) would drop.
vRefused "$pIccLock/create" file
vRefused "$pIccLock/create" file x
vRefused "$pIccLock/create" file -1
vRefused "$pIccLock/create" $'fi\nle' 30
vRefused "$pIccLock/create" $'file\n' 30
[ "$("$pIccLock/create" file 0 2>&1)" = "SECONDS must be more than zero" ]
[ "$("$pIccLock/create" file 99999999999999999999 2>&1)" = \
  "SECONDS too big: 99999999999999999999" ]
# Taken: the record names the path as readlink -m spells it, and the file
# under /tmp/icc-lock/ its sha256 names; list says up.
vTake file 30
pHeld=$pTaken
pLock=${aLocks[0]}
[ "$(sed -n 1p "$pHeld/lock")" = "$pWork/file" ]
osKey=$(printf '%s' "$pWork/file" | sha256sum)
[ "$pLock" = "/tmp/icc-lock/${osKey%% *}" ]
"$pIccLock/list" | grep -qxF "$pHeld up $pWork/file"
[ "$(nOpeners "$pLock")" -eq 1 ]
# Another path is a lock of its own, and a lock on a directory is on that
# name alone, not on what is under it.
vTake "$pWork" 30
pBeside=$pTaken
vTake sub/file 30
"$pIccLock/remove" "$pTaken"
"$pIccLock/remove" "$pBeside"
pBeside=
# Held, every spelling of it waits, and timeout cuts the wait off with 124,
# having printed nothing. Nothing is left waiting behind: the hold is still
# the only one with the file open.
mkdir sub
ln -s "$pWork" link
for osSpelling in file ./file sub/../file "$pWork//file" link/file; do
  nStatus=0
  pOut=$(timeout 0.5 "$pIccLock/create" "$osSpelling" 30) || nStatus=$?
  [ "$nStatus" -eq 124 ]
  [ -z "$pOut" ]
done
[ "$(nOpeners "$pLock")" -eq 1 ]
# The hold is a server, and a hangup is not its business: it still holds the
# lock after one.
kill -HUP "$(cat "$pHeld/pid")"
sleep 1
"$pIccLock/list" | grep -qxF "$pHeld up $pWork/file"
# TERM to a create alone, while it waits, and not to its flock, still ends it
# at once with 1, and it takes its flock with it. At once is well inside the
# holder's lease, which is still running after: a create that ran its trap
# only when its flock returned would end, but not until then.
"$pIccLock/create" file 30 > waited &
pidWaiter=$!
vWaiting "$pLock" "$pidWaiter"
nStart=$SECONDS
kill -TERM "$pidWaiter"
nStatus=0
wait "$pidWaiter" || nStatus=$?
pidWaiter=
[ "$nStatus" -eq 1 ]
[ $((SECONDS - nStart)) -lt 5 ]
[ ! -s waited ]
[ "$(nOpeners "$pLock")" -eq 1 ]
"$pIccLock/list" | grep -qxF "$pHeld up $pWork/file"
# A create waiting gets the path the moment the holder gives it back.
timeout 5 "$pIccLock/create" file 30 > waited &
pidWaiter=$!
vWaiting "$pLock" "$pidWaiter"
"$pIccLock/remove" "$pHeld"
[ ! -e "$pHeld" ]
wait "$pidWaiter"
pidWaiter=
pHeld=$(cat waited)
"$pIccLock/list" | grep -qxF "$pHeld up $pWork/file"
# However the hold goes, the lock goes with it: killed outright, it is free.
kill -KILL "$(cat "$pHeld/pid")"
vTake file 30
"$pIccLock/list" | grep -qxF "$pHeld down $pWork/file"
nStatus=0
osSaid=$("$pIccLock/remove" "$pHeld" 2>&1) || nStatus=$?
[ "$nStatus" -eq 1 ]
[ "$osSaid" = "lapsed: $pHeld" ]
[ ! -e "$pHeld" ]
pHeld=$pTaken
"$pIccLock/remove" "$pHeld"
pHeld=
# SECONDS is a lease: once it runs out the lock is free, whether or not its
# holder is done, and remove says it lapsed and takes the directory anyway.
vTake lease 1
pBeside=$pTaken
vTake lease 30
pHeld=$pTaken
"$pIccLock/list" | grep -qxF "$pBeside down $pWork/lease"
nStatus=0
osSaid=$("$pIccLock/remove" "$pBeside" 2>&1) || nStatus=$?
[ "$nStatus" -eq 1 ]
[ "$osSaid" = "lapsed: $pBeside" ]
[ ! -e "$pBeside" ]
pBeside=
"$pIccLock/remove" "$pHeld"
pHeld=
# Cut off just after it makes its directory, which is once it holds the
# path, a create takes the directory with it, and the lock is free again.
vCutOff "$pIccLock/create" cut 30
vTake cut 30
"$pIccLock/remove" "$pTaken"
# Four processes, three turns each, on one path: every turn is in then out,
# and nobody's in lands between another's in and out.
for iWorker in 1 2 3 4; do
  (
    for iTurn in 1 2 3; do
      pTurn=$(timeout 30 "$pIccLock/create" turns 10)
      echo "in $iWorker" >> turns
      sleep 0.05
      echo "out $iWorker" >> turns
      "$pIccLock/remove" "$pTurn"
    done
  ) &
  aWorkers+=($!)
done
for pidWorker in "${aWorkers[@]}"; do
  wait "$pidWorker"
done
aWorkers=()
vTake turns 30
"$pIccLock/remove" "$pTaken"
[ "$(wc -l < turns)" -eq 24 ]
awk '
  NR % 2 == 1 && $1 != "in" { exit 1 }
  NR % 2 == 0 && ($1 != "out" || $2 != nWorker) { exit 1 }
  { nWorker = $2 }' turns
# remove refuses what is not a hold, and a look-alike keeps whatever create
# did not make, its stranger's pid included; list skips one with no record.
vRefused "$pIccLock/remove" "$pWork"
vRefused "$pIccLock/remove" /tmp/icc-lock-missing
pFake=$(mktemp -d /tmp/icc-lock-XXXXXXXX)
sleep 30 &
pidSleep=$!
printf '%s\n' "$pWork/fake" "$pLock" > "$pFake/lock"
echo "$pidSleep" > "$pFake/pid"
: > "$pFake/kept"
vRefused "$pIccLock/remove" "$pFake"
kill -0 "$pidSleep"
[ -e "$pFake/kept" ]
[ -z "$("$pIccLock/list" | grep -F "$pFake")" ]
kill "$pidSleep"
pidSleep=
rm -rf "$pFake"
pFake=
rm -f "${aLocks[@]}"
aLocks=()
cd /
rm -rf "$pWork"
vDisarm
echo ok
