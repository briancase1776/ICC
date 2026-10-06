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
#          other, and a writer that pauses between its blocks for less
#          than the copier's hundredth of a second, with another inlet
#          waiting, comes out whole too; remove it. The pipes stay up. A
#          merge whose outlet is full and unread is removed with nothing
#          of it left running and only the block in hand lost, counted
#          against what the writer put on. A Frames payload put on while
#          the copier is stopped comes through once it goes on, five times
#          of five. 4 MiB crosses with a dd forked for a turn and
#          not for every block. An inlet that ends, and an outlet that
#          can no longer be written, with SIGPIPE ignored and not, each
#          end the merge, the second with at most a block lost. An
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
pFastIn=
pFastOut=
pDead=
vArm '[ -n "$pMergeDir" ] && "$pIccMerge/remove" "$pMergeDir" 2>/dev/null || :
      for pFake in $pOutside $pDeep $pNoSrc $pBadSide $pIdle; do
        rm -rf "$pFake"
      done
      for pPipe in $pPipeA $pPipeB $pPipeC $pNarrow $pBroken $pOddA $pOddB \
          $pFastIn $pFastOut $pDead; do
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
# A writer that pauses between its blocks for less than the hundredth of a
# second the copier looks again after keeps its turn: forty blocks of a,
# written by printf two thousandths of a second apart, one write each and
# nothing forked, and a block of b put on the other inlet after the first,
# come out together, b before or after. Each try times the writer's longest
# gap, from one write's end to the next one's start: a write blocked on a
# full inlet is no gap, since a full inlet is never found empty. A try the
# machine held up a hundredth or more says nothing either way, and is tried
# again, up to ten times; a try cut with every gap shorter is the copier's.
osBlockA=$(head -c 4096 /dev/zero | tr '\0' a)
osBlockB=$(head -c 4096 /dev/zero | tr '\0' b)
bTold=0
for iTry in $(seq 10); do
  timeout 10 head -c $((41 * 4096)) "$pPipeC/0" > out &
  pidOut=$!
  timeout 10 bash -c '
    exec {fdPause}<> <(:)
    nLongest=0
    nEnd=
    for ((iBlock = 1; iBlock <= 40; iBlock++)); do
      nStart=${EPOCHREALTIME//[!0-9]/}
      [ -z "$nEnd" ] || [ $((nStart - nEnd)) -le "$nLongest" ] ||
        nLongest=$((nStart - nEnd))
      printf "%s" "$1"
      nEnd=${EPOCHREALTIME//[!0-9]/}
      [ "$iBlock" -ne 1 ] || printf "%s" "$2" > "$3"
      read -t 0.002 -u "$fdPause" || :
    done
    echo "$nLongest" > longest' _ "$osBlockA" "$osBlockB" "$pPipeB/0" \
    > "$pPipeA/0"
  wait "$pidOut"
  case $(tr -s ab < out) in
    ab|ba)
      bTold=1
      break
      ;;
  esac
  [ "$(cat longest)" -ge 10000 ] || exit 1
done
[ "$bTold" -eq 1 ] || {
  echo "every try held up a hundredth or more: the machine is too busy" >&2
  exit 1
}
"$pIccMerge/remove" "$pMergeDir"
[ ! -d "$pMergeDir" ]
for pPipe in $pPipeA $pPipeB $pPipeC; do
  "$pIccPipes/list" | grep -qx "$pPipe up"
done
# A merge whose outlet is full and unread has a dd waiting on it, the block
# it took off the inlet in hand. remove takes that dd with the copier, and
# nothing of the merge is left running. Of what went on, the outlet lane
# and the inlet lane hold a lane each, and only the block in hand is lost.
pMergeDir=$("$pIccMerge/create" "$pPipeC" 0 "$pPipeA")
pidCopier=$(cat "$pMergeDir/pid")
head -c 300000 /dev/zero > full
timeout --foreground -s INT 2 dd if=full of="$pPipeA/0" bs=4096 2> said &&
  exit 1
nPut=$(awk '/ bytes / {print $1}' said)
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
[ "$(timeout 1 head -c 65536 "$pPipeC/0" | wc -c)" -eq 65536 ]
[ "$(timeout 1 head -c 65536 "$pPipeA/0" | wc -c)" -eq 65536 ]
read -t 0 < "$pPipeC/0" && exit 1
read -t 0 < "$pPipeA/0" && exit 1
[ "$nPut" -eq $((65536 + 4096 + 65536)) ]
# A turn moves at most what a lane holds: a Frames payload put on while the
# copier is stopped fills the inlet's lanes, and once the copier goes on it
# comes through whole, where a copier that drained a lane in one turn filled
# one outlet lane and waited on it with the others empty.
# Whether that copier fills one lane is a race with the writer, so five
# tries, each with a merge of its own.
head -c 262144 /dev/urandom > in
for iTry in $(seq 5); do
  pMergeDir=$("$pIccMerge/create" "$pPipeC" 0 "$pPipeA")
  pidCopier=$(cat "$pMergeDir/pid")
  kill -STOP "$pidCopier"
  timeout 10 "$pIccFrames/write" "$pPipeA" 0 < in &
  pidA=$!
  sleep 0.5
  kill -CONT "$pidCopier"
  wait "$pidA"
  timeout 5 "$pIccFrames/read" "$pPipeC" 1 > out
  cmp in out
  "$pIccMerge/remove" "$pMergeDir"
done
# 4 MiB crosses a merge with a dd forked for each turn, a lane's 16 blocks
# at most, and not for every block, which would be 1024. Counted by a dd
# first on the copier's PATH that notes itself and execs the real one.
pFastIn=$("$pIccPipes/create" 2)
pFastOut=$("$pIccPipes/create" 2)
mkdir bin
printf '%s\n' '#!/bin/bash' 'echo >> "${0%/*}/forked"' \
  "exec $(type -P dd) \"\$@\"" > bin/dd
chmod +x bin/dd
: > bin/forked
pMergeDir=$(PATH=$pWork/bin:$PATH "$pIccMerge/create" "$pFastOut" 0 \
  "$pFastIn")
head -c 4194304 /dev/urandom > big
timeout 30 head -c 4194304 "$pFastOut/0" > out &
pidOut=$!
timeout 30 dd if=big of="$pFastIn/0" bs=4096 status=none
wait "$pidOut"
cmp big out
[ "$(wc -l < bin/forked)" -lt 256 ]
"$pIccMerge/remove" "$pMergeDir"
# An inlet that ends ends the merge: its hold gone, what was on it still
# comes out, and then list says down.
pDead=$("$pIccPipes/create" 2)
pMergeDir=$("$pIccMerge/create" "$pFastOut" 0 "$pDead")
printf abc > "$pDead/0"
kill "$(cat "$pDead/pid")"
[ "$(timeout 1 head -c 3 "$pFastOut/0")" = abc ]
for iLook in $(seq 20); do
  ! "$pIccMerge/list" | grep -qx "$pMergeDir up $pFastOut 0 $pDead" ||
    sleep 0.1
done
"$pIccMerge/list" | grep -qx "$pMergeDir down $pFastOut 0 $pDead"
"$pIccMerge/remove" "$pMergeDir"
"$pIccPipes/remove" "$pDead" 2>/dev/null || rm -rf "$pDead"
pDead=
# An outlet that can no longer be written ends the merge too, whether the
# copier was made with SIGPIPE ignored or not, and of what went on only the
# block in hand is lost: the rest is still on the inlet. env sets SIGPIPE
# each way, since a trap cannot undo an ignore the harness started with.
for osPipe in --default-signal=PIPE --ignore-signal=PIPE; do
  pDead=$("$pIccPipes/create" 2)
  pMergeDir=$(env "$osPipe" "$pIccMerge/create" "$pDead" 0 "$pFastIn")
  kill "$(cat "$pDead/pid")"
  head -c 20000 /dev/zero > some
  dd if=some of="$pFastIn/0" bs=4096 status=none
  for iLook in $(seq 20); do
    ! "$pIccMerge/list" | grep -qx "$pMergeDir up $pDead 0 $pFastIn" ||
      sleep 0.1
  done
  "$pIccMerge/list" | grep -qx "$pMergeDir down $pDead 0 $pFastIn"
  [ "$(timeout 1 head -c 15904 "$pFastIn/0" | wc -c)" -eq 15904 ]
  "$pIccMerge/remove" "$pMergeDir"
  "$pIccPipes/remove" "$pDead" 2>/dev/null || rm -rf "$pDead"
  pDead=
done
pMergeDir=
"$pIccPipes/remove" "$pFastOut"
"$pIccPipes/remove" "$pFastIn"
"$pIccPipes/remove" "$pNarrow"
"$pIccPipes/remove" "$pPipeC"
"$pIccPipes/remove" "$pPipeB"
"$pIccPipes/remove" "$pPipeA"
cd /
rm -rf "$pWork"
vDisarm
echo ok
