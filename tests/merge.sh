#!/bin/bash
##
# @file merge.sh
# @brief Prove the merge: two pipes' side copied whole onto a third.
# @details Prove the merge: get three pipes, merge side 0 of two into the
#          third, push a Frames payload bigger than one lane holds through
#          each inlet in turn, read it back whole from the outlet each
#          time, then plain bytes on one lane from both inlets, then two
#          raspberries bigger than a lane, each put on by one dd from its
#          inlet at once, and see each come out whole, one inlet after the
#          other, remove it. The pipes stay up. A merge whose outlet is
#          full and unread is removed with nothing of it left running. An
#          inlet that is the outlet, one given
#          twice, a lane that is not a lane, and an odd lane count are
#          refused; remove takes what create made and not a path out of it
#          or a look-alike; list answers for every merge whatever else
#          /tmp holds, and calls a copierless merge down. A create cut off
#          just after it makes its directory takes it with it.
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
pIccPipes=$(cd .claude/skills/icc-pipes/scripts && pwd)
pIccFrames=$(cd .claude/skills/icc-frames/scripts && pwd)
pIccMerge=$(cd .claude/skills/icc-merge/scripts && pwd)
pIccRaspberry=$(cd .claude/skills/icc-raspberry/scripts && pwd)
# Armed before anything is made, as icc-lib's vArm says: the one cleanup takes
# whatever is named, so a check that fails leaves nothing of the harness's
# own behind.
pWork=
pPipeA=
pPipeB=
pPipeC=
pNarrow=
pBroken=
pOddA=
pOddB=
pMergeDir=
pOutside=
pDeep=
pNoSrc=
pBadSide=
pIdle=
vArm '[ -n "$pMergeDir" ] && "$pIccMerge/remove" "$pMergeDir" 2>/dev/null || :
      for pFake in $pOutside $pDeep $pNoSrc $pBadSide $pIdle; do
        rm -rf "$pFake"
      done
      for pPipe in $pPipeA $pPipeB $pPipeC $pNarrow $pBroken $pOddA $pOddB; do
        "$pIccPipes/remove" "$pPipe" 2>/dev/null || rm -rf "$pPipe"
      done
      cd /
      [ -n "$pWork" ] && rm -rf "$pWork" || :'
pWork=$(mktemp -d)
cd "$pWork"
pPipeA=$("$pIccPipes/create" 6)
pPipeB=$("$pIccPipes/create" 6)
pPipeC=$("$pIccPipes/create" 6)
pNarrow=$("$pIccPipes/create" 2)
"$pIccMerge/create" "$pPipeC" 0 2>/dev/null && exit 1
"$pIccMerge/create" "$pPipeC" 2 "$pPipeA" 2>/dev/null && exit 1
"$pIccMerge/create" "$pPipeC" 0 "$pNarrow" 2>/dev/null && exit 1
"$pIccMerge/create" "$pPipeC" 0 /tmp 2>/dev/null && exit 1
"$pIccMerge/create" "$pPipeC" 0 "$pPipeC" 2>/dev/null && exit 1
"$pIccMerge/create" "$pPipeC" 0 "$pPipeA" "$pPipeA" 2>/dev/null && exit 1
# a lane that is not a lane
pBroken=$("$pIccPipes/create" 6)
rm -f "$pBroken/2"
mkdir "$pBroken/2"
"$pIccMerge/create" "$pPipeC" 0 "$pBroken" 2>/dev/null && exit 1
rmdir "$pBroken/2"
"$pIccPipes/remove" "$pBroken"
# an odd lane count, refused in Pipes' words: one lane, where SIDE 1 has
# none to copy and no copier would start, and three
mkdir one two
mkfifo one/0 two/0
"$pIccMerge/create" one 1 two 2>/dev/null && exit 1
pOddA=$("$pIccPipes/create" 4)
pOddB=$("$pIccPipes/create" 4)
rm -f "$pOddA/3" "$pOddB/3"
"$pIccMerge/create" "$pOddA" 0 "$pOddB" 2>/dev/null && exit 1
"$pIccPipes/remove" "$pOddA"
"$pIccPipes/remove" "$pOddB"
# Cut off just after its directory is made, a create takes it with it.
vCutOff "$pIccMerge/create" "$pPipeC" 0 "$pPipeA"
pMergeDir=$("$pIccMerge/create" "$pPipeC" 0 "$pPipeA" "$pPipeB")
"$pIccMerge/list" | grep -qx "$pMergeDir up $pPipeC 0 $pPipeA $pPipeB"
# A copier is a server, as Pipes' hold is, and a hangup is not its business:
# the merge is still up after every copier has had one.
mapfile -t aCopiers < "$pMergeDir/pid"
kill -HUP "${aCopiers[@]}"
sleep 1
"$pIccMerge/list" | grep -qx "$pMergeDir up $pPipeC 0 $pPipeA $pPipeB"
# remove takes what create made and nothing else, and list answers for every
# merge whatever else is in /tmp.
pOutside=$(mktemp -d)
mkdir "$pOutside/deep"
printf '%s\n0\n%s\n' "$pPipeC" "$pPipeA" > "$pOutside/merge"
: > "$pOutside/pid"
"$pIccMerge/remove" "$pMergeDir/../$(basename "$pOutside")" 2>/dev/null &&
  exit 1
[ -d "$pOutside/deep" ]
pDeep=$(mktemp -d /tmp/icc-merge-XXXXXXXX)
mkdir "$pDeep/deep"
printf '%s\n0\n%s\n' "$pPipeC" "$pPipeA" > "$pDeep/merge"
: > "$pDeep/pid"
"$pIccMerge/remove" "$pDeep" 2>/dev/null && exit 1
[ -d "$pDeep/deep" ]
pNoSrc=$(mktemp -d /tmp/icc-merge-XXXXXXXX)
printf '%s\n0\n' "$pPipeC" > "$pNoSrc/merge"
echo 1 > "$pNoSrc/pid"
# A SIDE that is not 0 or 1 is not a merge either, and list skips it:
# arithmetic on it stopped the listing, and a subscript in it ran.
pBadSide=$(mktemp -d /tmp/icc-merge-XXXXXXXX)
printf '%s\n' "$pPipeC" 'a[$(touch pwned)]' "$pPipeA" > "$pBadSide/merge"
echo 1 > "$pBadSide/pid"
"$pIccMerge/list" > /dev/null
[ -z "$("$pIccMerge/list" 2>&1 >/dev/null)" ]
[ ! -e pwned ]
"$pIccMerge/list" | grep -q "$pBadSide" && exit 1
"$pIccMerge/list" | grep -qx "$pMergeDir up $pPipeC 0 $pPipeA $pPipeB"
pIdle=$(mktemp -d /tmp/icc-merge-XXXXXXXX)
printf '%s\n0\n%s\n' "$pPipeC" "$pPipeA" > "$pIdle/merge"
: > "$pIdle/pid"
"$pIccMerge/list" | grep -qx "$pIdle down $pPipeC 0 $pPipeA"
"$pIccMerge/remove" "$pIdle"
[ ! -d "$pIdle" ]
rm -rf "$pOutside" "$pDeep" "$pNoSrc" "$pBadSide"
head -c 150000 /dev/urandom > in
"$pIccFrames/write" "$pPipeA" 0 < in
timeout 5 "$pIccFrames/read" "$pPipeC" 1 > out
cmp in out
"$pIccFrames/write" "$pPipeB" 0 < in
timeout 5 "$pIccFrames/read" "$pPipeC" 1 > out
cmp in out
# Inlets that write at once: a payload that fits in one frame is one write,
# so the merge passes each whole, in either order. Random bytes, random
# sizes up to a frame, and many rounds, because what broke it did so only
# now and then.
for iRound in $(seq 30); do
  head -c $((1 + RANDOM % 4000)) /dev/urandom > inA
  head -c $((1 + RANDOM % 4000)) /dev/urandom > inB
  "$pIccFrames/write" "$pPipeA" 0 < inA &
  pidA=$!
  "$pIccFrames/write" "$pPipeB" 0 < inB &
  pidB=$!
  wait "$pidA" "$pidB"
  timeout 5 "$pIccFrames/read" "$pPipeC" 1 > out1
  timeout 5 "$pIccFrames/read" "$pPipeC" 1 > out2
  if cmp -s inA out1; then
    cmp inB out2
  else
    cmp inA out2
    cmp inB out1
  fi
done
printf 'a' > "$pPipeA/2"
printf 'b' > "$pPipeB/2"
case $(timeout 1 dd if="$pPipeC/2" bs=4096 status=none) in
  ab|ba)
    ;;
  *)
    exit 1
    ;;
esac
# Inlets that write at once, with more than a lane each: the copier drains
# one inlet before it goes to the next, so what one writer puts on without a
# pause comes out whole, and then the other's. A raspberry checks itself.
for iRound in $(seq 5); do
  "$pIccRaspberry/raspberry" $((150000 + 2 * RANDOM)) > inA
  "$pIccRaspberry/raspberry" $((150000 + 2 * RANDOM)) > inB
  nBoth=$(($(wc -c < inA) + $(wc -c < inB)))
  timeout 10 head -c "$nBoth" "$pPipeC/0" > out &
  pidOut=$!
  dd if=inA of="$pPipeA/0" bs=4096 2>/dev/null &
  pidA=$!
  dd if=inB of="$pPipeB/0" bs=4096 2>/dev/null &
  pidB=$!
  wait "$pidA" "$pidB" "$pidOut"
  cat inA inB | cmp -s - out || cat inB inA | cmp - out
done
"$pIccMerge/remove" "$pMergeDir"
[ ! -d "$pMergeDir" ]
for pPipe in $pPipeA $pPipeB $pPipeC; do
  "$pIccPipes/list" | grep -qx "$pPipe up"
done
# A merge whose outlet is full and unread has a dd waiting on it, the block
# it took off the inlet in hand. remove takes that dd with the copier, and
# nothing of the merge is left running.
pMergeDir=$("$pIccMerge/create" "$pPipeC" 0 "$pPipeA")
pidCopier=$(cat "$pMergeDir/pid")
head -c 300000 /dev/zero |
  timeout 2 dd of="$pPipeA/0" bs=4096 2>/dev/null && exit 1
[ -n "$(pgrep -P "$pidCopier")" ]
"$pIccMerge/remove" "$pMergeDir"
sleep 1
[ -z "$(pgrep -P "$pidCopier")" ]
case $(ps -o stat= -p "$pidCopier" 2>/dev/null) in
  ''|Z*)
    ;;
  *)
    exit 1
    ;;
esac
"$pIccPipes/remove" "$pNarrow"
"$pIccPipes/remove" "$pPipeC"
"$pIccPipes/remove" "$pPipeB"
"$pIccPipes/remove" "$pPipeA"
cd /
rm -rf "$pWork"
vDisarm
echo ok
