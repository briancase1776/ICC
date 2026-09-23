#!/bin/bash
##
# @file tee.sh
# @brief Prove the tee: one pipe's side copied whole onto two others.
# @details Prove the tee: get three pipes, tee side 0 of one into the
#          other two, push a Frames payload bigger than one lane holds,
#          read it back whole from both outlets, then plain bytes on one
#          lane, remove it. The pipes stay up. Bad arguments are refused,
#          a create cut off by a signal, just after it makes its directory
#          or inside its lane loop, takes itself with it, and remove and
#          list leave alone what create did not make.
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
# What is in /tmp is counted from globs, never from ls, and a glob that
# matches nothing is no paths at all, not the pattern itself.
shopt -s nullglob
cd "$(dirname "$0")/.."
pIccPipes=$(cd .claude/skills/icc-pipes/scripts && pwd)
pIccFrames=$(cd .claude/skills/icc-frames/scripts && pwd)
pIccTee=$(cd .claude/skills/icc-tee/scripts && pwd)
# Armed before anything is made, as in every piece: each name is empty until
# what it names exists, and the one EXIT trap takes whatever is named, so a
# check that fails leaves nothing of the harness's own behind. A signal exits
# 1, which runs it.
# pidSleep is emptied once it is killed, because a pid is soon someone
# else's.
pWork=
pPipeA=
pPipeB=
pPipeC=
pNarrow=
pBroken=
pOddA=
pOddB=
pWideSrc=
pWideDst=
pDead=
pTeeDir=
pStalled=
pFake=
pidSleep=
trap '[ -n "$pidSleep" ] && kill "$pidSleep" 2>/dev/null || :
      for pTee in $pTeeDir $pStalled; do
        "$pIccTee/remove" "$pTee" 2>/dev/null || :
      done
      [ -n "$pFake" ] && rm -rf "$pFake" || :
      for pPipe in $pPipeA $pPipeB $pPipeC $pNarrow $pBroken $pOddA $pOddB \
          $pWideSrc $pWideDst $pDead; do
        "$pIccPipes/remove" "$pPipe" 2>/dev/null || rm -rf "$pPipe"
      done
      cd /
      [ -n "$pWork" ] && rm -rf "$pWork" || :' EXIT
trap 'exit 1' INT TERM HUP
pWork=$(mktemp -d)
cd "$pWork"
pPipeA=$("$pIccPipes/create" 6)
pPipeB=$("$pIccPipes/create" 6)
pPipeC=$("$pIccPipes/create" 6)
pNarrow=$("$pIccPipes/create" 2)

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

vRefused "$pIccTee/create" "$pPipeA" 0
vRefused "$pIccTee/create" "$pPipeA" 2 "$pPipeB"
vRefused "$pIccTee/create" "$pPipeA" 0 "$pNarrow"
vRefused "$pIccTee/create" "$pPipeA" 0 /tmp
# A lane that is a file, not a lane, would take the copier's writes; and an
# odd lane count, one lane or three, is refused in Pipes' words: one lane
# would leave SIDE 1 none to copy, and a tee with no copier. Neither is a
# pipe Pipes makes.
pBroken=$("$pIccPipes/create" 6)
rm -f "$pBroken/2"
: > "$pBroken/2"
vRefused "$pIccTee/create" "$pPipeA" 0 "$pBroken"
[ ! -s "$pBroken/2" ]
rm -f "$pBroken/2"
mkfifo "$pBroken/2"
"$pIccPipes/remove" "$pBroken"
mkdir one two
mkfifo one/0 two/0
vRefused "$pIccTee/create" one 1 two
pOddA=$("$pIccPipes/create" 4)
pOddB=$("$pIccPipes/create" 4)
rm -f "$pOddA/3" "$pOddB/3"
vRefused "$pIccTee/create" "$pOddA" 0 "$pOddB"
"$pIccPipes/remove" "$pOddA"
"$pIccPipes/remove" "$pOddB"
# SRC as its own DST, the same DST twice, the same DST spelled two ways
vRefused "$pIccTee/create" "$pPipeA" 0 "$pPipeA"
vRefused "$pIccTee/create" "$pPipeA" 0 "$pPipeB" "$pPipeB"
vRefused "$pIccTee/create" "$pPipeA" 0 "$pPipeB" "$pPipeB/"
pTeeDir=$("$pIccTee/create" "$pPipeA" 0 "$pPipeB" "$pPipeC")
"$pIccTee/list" | grep -qx "$pTeeDir up $pPipeA 0 $pPipeB $pPipeC"
head -c 150000 /dev/urandom > in
"$pIccFrames/write" "$pPipeA" 0 < in
timeout 5 "$pIccFrames/read" "$pPipeB" 1 > out
cmp in out
timeout 5 "$pIccFrames/read" "$pPipeC" 1 > out
cmp in out
printf 'plain' > "$pPipeA/2"
[ "$(timeout 1 cat "$pPipeB/2")" = plain ]
[ "$(timeout 1 cat "$pPipeC/2")" = plain ]
"$pIccTee/remove" "$pTeeDir"
[ ! -d "$pTeeDir" ]
# remove signals a copier, not whatever pid sits in the file, and takes the
# two files it made, not the directory. A look-alike holding a stranger's pid
# loses its own two files and nothing else; one with a file beside them is
# left where it is. list does not announce a directory with no DIR/tee.
# Cut off just after its directory is made, a create takes it with it.
##
# @fn vCutOff()
# @brief Cut a command off just after its first mktemp, and check it goes
#        and takes what that made with it.
# @details A stand-in mktemp makes what the real one would, prints it and
#          waits, so the signal lands once the thing exists and before the
#          command has its name: the moment a cleanup armed after mktemp
#          misses. The stand-in takes itself away first, so any later
#          mktemp in the command is the real one. The same check in every
#          harness whose piece makes something.
# @param $1... aCommand - the command and its arguments
# @stderr "cut off, not taken" and the command, when it failed
# @return 0 the command exited 1 and what its mktemp made is gone; it exits
#         1 instead when not
##
vCutOff() {
  local aCommand=("$@")
  local pBin
  local pidCommand
  local pidStub
  local pMade
  local nStatus=0
  pBin=$(mktemp -d)
  printf '%s\n' '#!/bin/bash' 'rm -- "$0"' \
    'pMade=$(command -p mktemp "$@")' 'echo "$pMade"' \
    'echo "$$ $pMade" > "${0%/*}/stalled"' 'exec sleep 30' > "$pBin/mktemp"
  chmod +x "$pBin/mktemp"
  PATH=$pBin:$PATH "${aCommand[@]}" >/dev/null 2>&1 &
  pidCommand=$!
  while [ ! -s "$pBin/stalled" ]; do
    kill -0 "$pidCommand" 2>/dev/null || break
  done
  read -r pidStub pMade < "$pBin/stalled"
  kill -TERM "$pidCommand"
  kill "$pidStub"
  wait "$pidCommand" || nStatus=$?
  rm -rf "$pBin"
  [ "$nStatus" -eq 1 ] && [ ! -e "$pMade" ] || {
    echo "cut off, not taken: ${aCommand[*]}" >&2
    rm -rf "$pMade"
    exit 1
  }
}

vCutOff "$pIccTee/create" "$pPipeA" 0 "$pPipeB"
# The trap: a create cut off inside its lane loop takes its directory and the
# copiers it started with it. A wide pipe makes that loop long enough to
# signal into, and the signal waits for the new tee's pid file, which create
# writes once its trap is armed and just before its first copier. Cutting a
# create off before that proves nothing about the trap; waiting only for the
# directory worked while each look took an ls, and lost the race to the trap
# once it took a glob.
pWideSrc=$("$pIccPipes/create" 200)
pWideDst=$("$pIccPipes/create" 200)
aTees=(/tmp/icc-tee-*/)
nTees=${#aTees[@]}
aStarted=(/tmp/icc-tee-*/pid)
nStarted=${#aStarted[@]}
"$pIccTee/create" "$pWideSrc" 0 "$pWideDst" >/dev/null 2>&1 &
pidCreate=$!
while [ "${#aStarted[@]}" -le "$nStarted" ]; do
  kill -0 $pidCreate 2>/dev/null || break
  aStarted=(/tmp/icc-tee-*/pid)
done
kill -TERM $pidCreate 2>/dev/null || :
wait $pidCreate 2>/dev/null || :
aTees=(/tmp/icc-tee-*/)
[ "${#aTees[@]}" -eq "$nTees" ]
"$pIccPipes/remove" "$pWideDst"
"$pIccPipes/remove" "$pWideSrc"

# A lane with no writer does not hang create: the copier lets go of the
# caller's stdout before it opens, so d=$(create ...) returns and list says
# down. A writer lets the copier through, and it ends when that writer goes.
pDead=$("$pIccPipes/create" 6)
kill "$(cat "$pDead/pid")"
while kill -0 "$(cat "$pDead/pid")" 2>/dev/null; do :; done
pStalled=$(timeout 10 "$pIccTee/create" "$pDead" 0 "$pPipeB")
"$pIccTee/list" | grep -qx "$pStalled down $pDead 0 $pPipeB"
osStalled=$(cat "$pStalled/pid")
: > "$pDead/0"
"$pIccTee/remove" "$pStalled"
[ ! -d "$pStalled" ]
# remove takes the copiers still waiting on their lanes too, which have
# nothing on stdin yet to be known by. Dead is dead: reaped, or a zombie.
sleep 1
for pidCopier in $osStalled; do
  case $(ps -o stat= -p "$pidCopier" 2>/dev/null) in
    ''|Z*)
      ;;
    *)
      exit 1
      ;;
  esac
done
"$pIccPipes/remove" "$pDead"
sleep 60 &
pidSleep=$!
pFake=$(mktemp -d /tmp/icc-tee-XXXXXXXX)
printf '%s\n' /tmp/not-a-pipe 0 /tmp/nor-this > "$pFake/tee"
echo "$pidSleep" > "$pFake/pid"
"$pIccTee/remove" "$pFake"
[ ! -d "$pFake" ]
kill -0 "$pidSleep"
kill "$pidSleep"
pidSleep=
pFake=$(mktemp -d /tmp/icc-tee-XXXXXXXX)
printf '%s\n' /tmp/not-a-pipe 0 /tmp/nor-this > "$pFake/tee"
echo 1 > "$pFake/pid"
: > "$pFake/keep"
vRefused "$pIccTee/remove" "$pFake"
[ -f "$pFake/keep" ]
rm -f "$pFake"/*
rmdir "$pFake"
pFake=$(mktemp -d /tmp/icc-tee-XXXXXXXX)
echo 1 > "$pFake/pid"
[ -z "$("$pIccTee/list" 2>&1 >/dev/null)" ]
"$pIccTee/list" 2>/dev/null | grep -q "$pFake" && exit 1
rm -f "$pFake"/*
rmdir "$pFake"
# A SIDE that is not 0 or 1 was not written by create, and list skips it:
# arithmetic on it stopped the listing, and a subscript in it ran.
pFake=$(mktemp -d /tmp/icc-tee-XXXXXXXX)
printf '%s\n' /tmp/not-a-pipe 'a[$(touch pwned)]' /tmp/nor-this > "$pFake/tee"
echo 1 > "$pFake/pid"
"$pIccTee/list" > /dev/null
[ -z "$("$pIccTee/list" 2>&1 >/dev/null)" ]
[ ! -e pwned ]
"$pIccTee/list" | grep -q "$pFake" && exit 1
rm -f "$pFake"/*
rmdir "$pFake"
# A tee with its two files and no copier forked yet, as a create killed
# before its first fork leaves it, is down to list and taken by remove.
pFake=$(mktemp -d /tmp/icc-tee-XXXXXXXX)
printf '%s\n' "$pPipeA" 0 "$pPipeB" > "$pFake/tee"
: > "$pFake/pid"
"$pIccTee/list" | grep -qx "$pFake down $pPipeA 0 $pPipeB"
"$pIccTee/remove" "$pFake"
[ ! -d "$pFake" ]
# and one outside /tmp/icc-tee-* is refused, and keeps its files
mkdir look
printf '%s\n' "$pPipeA" 0 "$pPipeB" > look/tee
: > look/pid
vRefused "$pIccTee/remove" look
[ -f look/tee ]
vRefused "$pIccTee/remove" "$pPipeA"
for pPipe in $pPipeA $pPipeB $pPipeC; do
  "$pIccPipes/list" | grep -qx "$pPipe up"
done
"$pIccPipes/remove" "$pNarrow"
"$pIccPipes/remove" "$pPipeC"
"$pIccPipes/remove" "$pPipeB"
"$pIccPipes/remove" "$pPipeA"
cd /
rm -rf "$pWork"
trap - EXIT INT TERM HUP
echo ok
