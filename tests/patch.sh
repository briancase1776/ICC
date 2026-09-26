#!/bin/bash
##
# @file patch.sh
# @brief Prove the bay: every shape makes the map it says, and carries.
# @details Prove the bay: make each shape, see the map name the cables the
#          shape says and no more, push a Frames payload bigger than one
#          lane holds from a seat to its peers and read it back whole at
#          every one, plain bytes back the other way, see a hold go when
#          the patch does, see a piece that will not go named and tried
#          again, remove it, see nothing left. Make a mesh-p and a ring-p
#          with every cable a seat reads in series, see the map name every
#          pipe, a write bigger than single pipes hold go on with nobody
#          reading and come out whole. Sit a moot on ring-p 3,
#          three seats and a chair blowing raspberries at once through
#          every tee and merge, and check every one and every seat's
#          spittle count. A create cut off by a signal leaves nothing
#          either, and create, list and remove cut off just after they
#          make a directory or a temp file take it with them.
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
pIccPipes=.claude/skills/icc-pipes/scripts
pIccFrames=.claude/skills/icc-frames/scripts
pIccPatch=.claude/skills/icc-patch/scripts
pIccRaspberry=.claude/skills/icc-raspberry/scripts

##
# @fn pEnd()
# @brief Print the pipe a seat holds a side of, with a given peer on it.
# @details eSide is 0 or 1. PEERS are matched whole, so 1 is not 10.
# @param $1 osSeat - the seat, a number or p
# @param $2 eSide - the side it holds, 0 or 1
# @param $3 osPeer - one of the seats in its PEERS
# @stdout the pipe's directory for each end that matches, or nothing
# @global pDir - read, the patch under test
# @return awk's status: 0 unless the map could not be read
##
pEnd() {
  local osSeat=$1
  local eSide=$2
  local osPeer=$3
  awk -v s="$osSeat" -v i="$eSide" -v p="$osPeer" \
    '$1==s && $2==i && ("," $4 ",") ~ ("," p ",") {print $3}' "$pDir/patch"
}

##
# @fn pAt()
# @brief Print the pipe pEnd finds, and exit 1 if it finds none.
# @details eSide is 0 or 1, as for pEnd. Every call is inside $( ), so the
#          exit ends only that substitution. Each result is therefore
#          assigned before it is used: the assignment fails with it, and
#          set -e stops the harness there. Used in place, as an argument
#          or a redirection, it would leave an empty string and the
#          command would go on with it.
# @param $1 osSeat - the seat, a number or p
# @param $2 eSide - the side it holds, 0 or 1
# @param $3 osPeer - one of the seats in its PEERS
# @stdout the pipe's directory
# @stderr "no end" and the three arguments, when there is none
# @return 0; it exits 1 instead when there is no such end
##
pAt() {
  local osSeat=$1
  local eSide=$2
  local osPeer=$3
  local pFound
  pFound=$(pEnd "$osSeat" "$eSide" "$osPeer")
  [ -n "$pFound" ] || {
    echo "no end: $osSeat $eSide $osPeer" >&2
    exit 1
  }
  echo "$pFound"
}

##
# @fn vMade()
# @brief Succeed when so many of the made file's lines name a skill.
# @param $1 osSkill - what to look for, as grep takes it: icc-pipes, say
# @param $2 nCount - how many lines should have it
# @global pDir - read, the patch under test
# @return 0 the count is right; 1 it is not, which ends the harness
##
vMade() {
  local osSkill=$1
  local nCount=$2
  [ "$(grep -c "$osSkill" "$pDir/made")" -eq "$nCount" ]
}

##
# @fn vEnds()
# @brief Succeed when the map has so many ends, and no more.
# @param $1 nEnds - how many lines the map should have after its first
# @global pDir - read, the patch under test
# @return 0 the count is right; 1 it is not, which ends the harness
##
vEnds() {
  local nEnds=$1
  [ "$(( $(wc -l < "$pDir/patch") - 1 ))" -eq "$nEnds" ]
}

##
# @fn vMake()
# @brief Make a patch, and remember it for the EXIT trap.
# @param $1... - SHAPE N [LANES [DEPTH]], as Patch's create takes them
# @global pIccPatch - read, where Patch's scripts are
# @global pDir - set, the patch it made
# @global osMine - read and set, every patch made so far
# @return 0; a create that fails ends the harness
##
vMake() {
  pDir=$("$pIccPatch/create" "$@")
  osMine="$osMine $pDir"
}

##
# @fn pidHolder()
# @brief Print the pid of a process that holds a pipe's lane 0 open.
# @param $1 pPipe - the pipe
# @stdout the first such pid found under /proc, or nothing
# @global pFd - set, the descriptor it stopped at
# @return 0 it found one; 1 it did not
##
pidHolder() {
  local pPipe=$1
  for pFd in /proc/[0-9]*/fd/*; do
    [ "$(readlink "$pFd" 2>/dev/null)" = "$pPipe/0" ] && {
      echo "$pFd" | cut -d/ -f3
      return
    }
  done
}

"$pIccPatch/create" 2>/dev/null && exit 1
"$pIccPatch/create" bus 3 2>/dev/null && exit 1
"$pIccPatch/create" ring 0 2>/dev/null && exit 1
"$pIccPatch/create" ring 3 3 2>/dev/null && exit 1
"$pIccPatch/create" mesh 1 banana 2>/dev/null && exit 1
# an odd LANES, and none, where the shape makes no pipe to say so
"$pIccPatch/create" mesh 1 3 2>/dev/null && exit 1
"$pIccPatch/create" mesh 1 0 2>/dev/null && exit 1
# LANES is refused as Pipes refuses N, word for word
for osLanes in x 3 0 99999999999999999998; do
  osPatch=$("$pIccPatch/create" mesh 1 "$osLanes" 2>&1) || :
  osPipes=$("$pIccPipes/create" "$osLanes" 2>&1) || :
  [ "$osPatch" = "$osPipes" ]
done
# past 64 bits, where a count wrapped: this one was a ring of 2
"$pIccPatch/create" ring 18446744073709551618 2>/dev/null && exit 1
"$pIccPatch/create" star 1 99999999999999999998 2>/dev/null && exit 1
# DEPTH is a count, 1 or more
"$pIccPatch/create" mesh 3 2 0 2>/dev/null && exit 1
"$pIccPatch/create" mesh 3 2 x 2>/dev/null && exit 1
# Armed before anything is made, as icc-lib's vArm says: the one cleanup takes
# whatever is named, so a check that fails leaves nothing of the harness's
# own behind.
# osMine is every patch made so far, and pDir the latest, which a signal can
# catch before vMake has added it to the list.
osMine=
pDir=
pWork=
vArm 'for pMine in $osMine $pDir; do
        "$pIccPatch/remove" "$pMine" 2>/dev/null || :
      done
      [ -n "$pWork" ] && rm -rf "$pWork" || :'
pWork=$(mktemp -d)
pIn=$pWork/in
pOut=$pWork/out
head -c 150000 /dev/urandom > "$pIn"
# remove knows a patch by name as well as by shape: a directory outside
# /tmp/icc-patch-* with a patch file and a made file in it is refused, and
# keeps everything in it.
mkdir "$pWork/fake"
: > "$pWork/fake/patch"
: > "$pWork/fake/made"
: > "$pWork/fake/precious"
"$pIccPatch/remove" "$pWork/fake" 2>/dev/null && exit 1
[ -f "$pWork/fake/precious" ]
vMake star 3 6
"$pIccPatch/list" | grep -qx "$pDir up star 3 6 1"
vMade icc-pipes 3
vMade icc-tee 0
vMade icc-merge 0
vEnds 6
[ "$(grep -c '^p ' "$pDir/patch")" -eq 3 ]
pWriteEnd=$(pAt 1 0 p)
"$pIccFrames/write" "$pWriteEnd" 0 < "$pIn"
pReadEnd=$(pAt p 1 1)
timeout 5 "$pIccFrames/read" "$pReadEnd" 1 > "$pOut"
cmp "$pIn" "$pOut"
pWriteEnd=$(pAt p 1 2)
"$pIccFrames/write" "$pWriteEnd" 1 < "$pIn"
pReadEnd=$(pAt 2 0 p)
timeout 5 "$pIccFrames/read" "$pReadEnd" 0 > "$pOut"
cmp "$pIn" "$pOut"
pWriteEnd=$(pAt 0 0 p)
printf 'me' > "$pWriteEnd/0"
pReadEnd=$(pAt p 1 0)
[ "$(timeout 1 cat "$pReadEnd/0")" = me ]
[ -z "$(pEnd 0 0 2)" ]
[ -z "$(pEnd 0 1 p)" ]
"$pIccPatch/remove" "$pDir"
[ ! -d "$pDir" ]
vMake star 1
vMade icc-pipes 1
vEnds 2
"$pIccPatch/remove" "$pDir"
vMake ring 3 6
"$pIccPatch/list" | grep -qx "$pDir up ring 3 6 1"
vMade icc-pipes 3
vMade icc-tee 0
vMade icc-merge 0
vEnds 6
pWriteEnd=$(pAt 2 0 0)
"$pIccFrames/write" "$pWriteEnd" 0 < "$pIn"
pReadEnd=$(pAt 0 1 2)
timeout 5 "$pIccFrames/read" "$pReadEnd" 1 > "$pOut"
cmp "$pIn" "$pOut"
pWriteEnd=$(pAt 0 1 2)
"$pIccFrames/write" "$pWriteEnd" 1 < "$pIn"
pReadEnd=$(pAt 2 0 0)
timeout 5 "$pIccFrames/read" "$pReadEnd" 0 > "$pOut"
cmp "$pIn" "$pOut"
[ -z "$(pEnd 0 0 2)" ]
"$pIccPatch/remove" "$pDir"
[ ! -d "$pDir" ]
vMake ring 2
vMade icc-pipes 1
vEnds 2
"$pIccPatch/remove" "$pDir"
vMake ring 1
vMade icc-pipes 1
vEnds 2
pWriteEnd=$(pAt 0 0 0)
printf 'me' > "$pWriteEnd/0"
pReadEnd=$(pAt 0 1 0)
[ "$(timeout 1 cat "$pReadEnd/0")" = me ]
"$pIccPatch/remove" "$pDir"
vMake mesh 4 6
"$pIccPatch/list" | grep -qx "$pDir up mesh 4 6 1"
vMade icc-pipes 16
vMade icc-tee 4
vMade icc-merge 0
vEnds 16
# every pipe is a seat's: a write end and a read end from each other seat
[ -z "$(grep '^- ' "$pDir/patch")" ]
[ "$(grep -c '^3 ' "$pDir/patch")" -eq 4 ]
pWriteEnd=$(pAt 1 0 3)
"$pIccFrames/write" "$pWriteEnd" 0 < "$pIn"
for osSeat in 0 2 3; do
  pReadEnd=$(pAt $osSeat 1 1)
  timeout 5 "$pIccFrames/read" "$pReadEnd" 1 > "$pOut"
  cmp "$pIn" "$pOut"
done
# nothing comes back to the writer
[ -z "$(pEnd 1 1 1)" ]
# two writing at once each reach seat 3 on a read end of their own
pWriteEnd=$(pAt 0 0 2)
printf 'a' > "$pWriteEnd/2"
pWriteEnd=$(pAt 2 0 0)
printf 'b' > "$pWriteEnd/2"
pReadEnd=$(pAt 3 1 0)
[ "$(timeout 1 cat "$pReadEnd/2")" = a ]
pReadEnd=$(pAt 3 1 2)
[ "$(timeout 1 cat "$pReadEnd/2")" = b ]
mkdir "$pDir/lock"
"$pIccPatch/remove" "$pDir"
[ ! -d "$pDir" ]
vMake mesh 2
vMade icc-pipes 1
vMade icc-tee 0
vEnds 2
mv "$pDir/made" "$pDir/gone"
"$pIccPatch/list" | grep -qx "$pDir down mesh 2 2 1"
mv "$pDir/gone" "$pDir/made"
"$pIccPatch/remove" "$pDir"
vMake mesh 1
vMade icc-pipes 0
vEnds 0
"$pIccPatch/remove" "$pDir"
vMake mesh-p 1
vMade icc-pipes 1
vMade icc-merge 0
vEnds 2
pWriteEnd=$(pAt 0 0 p)
printf 'hi' > "$pWriteEnd/0"
pReadEnd=$(pAt p 1 0)
[ "$(timeout 1 cat "$pReadEnd/0")" = hi ]
pWriteEnd=$(pAt p 1 0)
printf 'yo' > "$pWriteEnd/1"
pReadEnd=$(pAt 0 0 p)
[ "$(timeout 1 cat "$pReadEnd/1")" = yo ]
"$pIccPatch/remove" "$pDir"
# mesh-p 2: the seats' mesh, and a merge of both for p alone, twice as deep;
# p writes nothing, and nothing comes back to a writer
vMake mesh-p 2
vMade icc-pipes 8
vMade icc-tee 3
vMade icc-merge 1
vEnds 8
[ "$(grep -c '^p ' "$pDir/patch")" -eq 1 ]
[ -z "$(pEnd p 0 0)" ]
[ "$(pEnd p 1 0)" = "$(pEnd p 1 1)" ]
pWriteEnd=$(pAt 0 0 1)
printf 'all' > "$pWriteEnd/0"
pReadEnd=$(pAt 1 1 0)
[ "$(timeout 1 cat "$pReadEnd/0")" = all ]
pReadEnd=$(pAt p 1 0)
[ "$(timeout 1 cat "$pReadEnd/0")" = all ]
[ -z "$(pEnd 0 1 0)" ]
# where the seats meet is p's merge: two writing at once come out whole
pWriteEnd=$(pAt 0 0 p)
printf 'a' > "$pWriteEnd/0"
pWriteEnd=$(pAt 1 0 p)
printf 'b' > "$pWriteEnd/0"
pReadEnd=$(pAt p 1 0)
case $(timeout 1 cat "$pReadEnd/0") in
  ab|ba)
    ;;
  *)
    exit 1
    ;;
esac
"$pIccPatch/remove" "$pDir"
# p's cable from the merge is three deep, one pipe for each seat in it
vMake ring-p 3 6
vMade icc-pipes 16
vMade icc-tee 6
vMade icc-merge 1
vEnds 16
# one coupler per seat, and two pipes of p's cable no seat holds
[ "$(grep -c '^- ' "$pDir/patch")" -eq 5 ]
[ "$(pEnd 1 1 0)" != "$(pEnd 1 1 p)" ]
pWriteEnd=$(pAt 1 0 2)
"$pIccFrames/write" "$pWriteEnd" 0 < "$pIn"
pReadEnd=$(pAt 2 1 1)
timeout 5 "$pIccFrames/read" "$pReadEnd" 1 > "$pOut"
cmp "$pIn" "$pOut"
pReadEnd=$(pAt p 1 1)
timeout 5 "$pIccFrames/read" "$pReadEnd" 1 > "$pOut"
cmp "$pIn" "$pOut"
[ -z "$(pEnd 0 1 1)" ]
pWriteEnd=$(pAt p 0 1)
printf 'all' > "$pWriteEnd/2"
for osSeat in 0 1 2; do
  pReadEnd=$(pAt $osSeat 1 p)
  [ "$(timeout 1 cat "$pReadEnd/2")" = all ]
done
osPieces=$(cut -d' ' -f1 "$pDir/made")
"$pIccPatch/remove" "$pDir"
[ ! -d "$pDir" ]
for pPiece in $osPieces; do [ ! -e "$pPiece" ]; done
vMake ring-p 1
vMade icc-pipes 4
vMade icc-tee 1
vMade icc-merge 0
vEnds 5
# ring-p 1 has no coupler: p holds both
[ -z "$(grep '^- ' "$pDir/patch")" ]
pWriteEnd=$(pAt p 0 0)
printf 'hi' > "$pWriteEnd/0"
pReadEnd=$(pAt 0 1 p)
[ "$(timeout 1 cat "$pReadEnd/0")" = hi ]
"$pIccPatch/remove" "$pDir"
# DEPTH: every cable a seat reads through a fitting is that many pipes in
# series, and the map names every one of them, and p's from the merge is
# three times that. Five deep, a tee's cable to each seat holds more than a
# mesh of single pipes does, so a write bigger than that goes on with nobody
# reading, waits whole in every other seat's cable from the writer and in
# p's, and comes out whole at each, one after another.
vMake mesh-p 3 2 5
"$pIccPatch/list" | grep -qx "$pDir up mesh-p 3 2 5"
vMade icc-pipes 51
vMade icc-tee 41
vMade icc-merge 1
vEnds 51
[ "$(grep -c '^- ' "$pDir/patch")" -eq 41 ]
"$pIccRaspberry/raspberry" 300000 > "$pWork/deep"
pWriteEnd=$(pAt 1 0 p)
timeout 10 dd if="$pWork/deep" of="$pWriteEnd/0" bs=4096 2>/dev/null
for osSeat in 0 2 p; do
  pReadEnd=$(pAt $osSeat 1 1)
  timeout 5 head -c 300000 "$pReadEnd/0" | cmp - "$pWork/deep"
done
osPieces=$(cut -d' ' -f1 "$pDir/made")
"$pIccPatch/remove" "$pDir"
[ ! -d "$pDir" ]
for pPiece in $osPieces; do [ ! -e "$pPiece" ]; done
# ring-p, two deep: every cable a seat reads in series, p's from the merge
# twice that, a Frames payload through a seat's hop and through p's merge
vMake ring-p 2 6 2
vMade icc-pipes 17
vMade icc-tee 10
vMade icc-merge 1
vEnds 17
pWriteEnd=$(pAt 0 0 1)
"$pIccFrames/write" "$pWriteEnd" 0 < "$pIn"
pReadEnd=$(pAt 1 1 0)
timeout 5 "$pIccFrames/read" "$pReadEnd" 1 > "$pOut"
cmp "$pIn" "$pOut"
pReadEnd=$(pAt p 1 0)
timeout 5 "$pIccFrames/read" "$pReadEnd" 1 > "$pOut"
cmp "$pIn" "$pOut"
pWriteEnd=$(pAt p 0 1)
printf 'all' > "$pWriteEnd/2"
for osSeat in 0 1; do
  pReadEnd=$(pAt $osSeat 1 p)
  [ "$(timeout 1 cat "$pReadEnd/2")" = all ]
done
"$pIccPatch/remove" "$pDir"
# The moot: three seats and a chair on ring-p 3, all at once, through every
# fitting the shape has. Four rounds, Opening, two Rotations and the Final;
# each round every seat blows a raspberry at the next, the hop tees copy each
# one to the chair through the merge, and the chair blows one at every seat
# through the broadcast tee. Every seat hands back its spittle count. The
# raspberries come from icc-raspberry, fresh each time; in the Final the
# chair's is 20000 bytes and spills over five frames, which the broadcast
# tee, one writer to a lane, carries whole.

##
# @fn vSeat()
# @brief Sit one seat through the moot's four rounds, then count its
#        spittle.
# @details Each round the seat blows before it takes, which is what keeps
#          three seats from waiting on each other: its raspberry at the
#          next seat, then the one from the seat before, then the
#          chair's. What it blew and what it took go into its own files in
#          pWork, a line each, and its spittle count, every ~ it took, into
#          one more.
# @param $1 iSeat - the seat, 0 to 2
# @global pDir - read, the patch
# @global pWork - read, where the seat's files go
# @global pIccFrames - read, where Frames' scripts are
# @global pIccRaspberry - read, where the raspberries come from
# @return 0; a write or read that fails ends the seat, and the chair's wait
#         for it with it
##
vSeat() {
  local iSeat=$1
  local pSend
  local pHop
  local pChair
  local osBlown
  local iRound
  pSend=$(pAt "$iSeat" 0 $(( (iSeat + 1) % 3 )))
  pHop=$(pAt "$iSeat" 1 $(( (iSeat + 2) % 3 )))
  pChair=$(pAt "$iSeat" 1 p)
  for iRound in 1 2 3 4; do
    osBlown=$("$pIccRaspberry/raspberry")
    echo "$osBlown" >> "$pWork/blown$iSeat"
    printf '%s' "$osBlown" | "$pIccFrames/write" "$pSend" 0
    timeout 10 "$pIccFrames/read" "$pHop" 1 >> "$pWork/hop$iSeat"
    echo >> "$pWork/hop$iSeat"
    timeout 10 "$pIccFrames/read" "$pChair" 1 >> "$pWork/chair$iSeat"
    echo >> "$pWork/chair$iSeat"
  done
  cat "$pWork/hop$iSeat" "$pWork/chair$iSeat" | tr -cd '~' | wc -c \
    > "$pWork/spittle$iSeat"
}

vMake ring-p 3
pBroadcast=$(pAt p 0 0)
pOverheard=$(pAt p 1 0)
aSeats=()
for iSeat in 0 1 2; do
  vSeat "$iSeat" &
  aSeats+=($!)
done
for nBytes in '' '' '' 20000; do
  osBlown=$("$pIccRaspberry/raspberry" "$nBytes")
  echo "$osBlown" >> "$pWork/blownp"
  printf '%s' "$osBlown" | "$pIccFrames/write" "$pBroadcast" 0
  for iSeat in 0 1 2; do
    timeout 10 "$pIccFrames/read" "$pOverheard" 1 >> "$pWork/overheard"
    echo >> "$pWork/overheard"
  done
done
for pidSeat in "${aSeats[@]}"; do
  wait "$pidSeat"
done
# Every hop reached the next seat as it was blown, and the chair's every
# seat; and the merge gave the chair all twelve hops whole, three seats' at
# once, in whatever order they met.
for iSeat in 0 1 2; do
  cmp "$pWork/blown$(( (iSeat + 2) % 3 ))" "$pWork/hop$iSeat"
  cmp "$pWork/blownp" "$pWork/chair$iSeat"
done
cat "$pWork/blown0" "$pWork/blown1" "$pWork/blown2" | sort |
  cmp - <(sort "$pWork/overheard")
# and each seat's spittle count is every ~ that was blown at it
for iSeat in 0 1 2; do
  nSpat=$(cat "$pWork/blown$(( (iSeat + 2) % 3 ))" "$pWork/blownp" |
    tr -cd '~' | wc -c)
  [ "$(cat "$pWork/spittle$iSeat")" -eq "$nSpat" ]
done
"$pIccPatch/remove" "$pDir"
vMake star 1 2
pHeld=$(pAt 0 0 p)
pidHold=$(pidHolder "$pHeld")
[ -n "$pidHold" ]
"$pIccPatch/remove" "$pDir"
# dead is dead: reaped, or a zombie nobody reaped
sleep 1
case $(ps -o stat= -p "$pidHold" 2>/dev/null) in
  ''|Z*)
    ;;
  *)
    exit 1
    ;;
esac
vMake star 1 2
pHeld=$(pAt 0 0 p)
touch "$pHeld/obstruct"
"$pIccPatch/remove" "$pDir" 2>/dev/null && exit 1
[ -d "$pDir" ]
rm -f "$pHeld/obstruct"
"$pIccPatch/remove" "$pDir" 2>/dev/null
[ ! -d "$pDir" ]
rmdir "$pHeld" 2>/dev/null || :
# A piece whose skill cannot be reached is not one its skill has forgotten:
# remove keeps the record and DIR, and says so, and once the skill is back
# it takes the lot.
vMake star 1 2
cp "$pDir/made" "$pWork/made"
sed -i 's| .*| /nonexistent/scripts|' "$pDir/made"
"$pIccPatch/remove" "$pDir" 2>/dev/null && exit 1
[ -d "$pDir" ]
cp "$pWork/made" "$pDir/made"
"$pIccPatch/remove" "$pDir"
[ ! -d "$pDir" ]
# A copy of the skills whose path has a space in it, and no .claude: create
# finds its siblings beside it, the made record still reads back whole, so
# list sees the pieces up and remove takes every one of them.
mkdir "$pWork/with space"
cp -r .claude/skills "$pWork/with space/"
pSpaced="$pWork/with space/skills/icc-patch/scripts"
pDir=$("$pSpaced/create" star 1)
osMine="$osMine $pDir"
"$pSpaced/list" | grep -qx "$pDir up star 1 2 1"
osPieces=$(cut -d' ' -f1 "$pDir/made")
"$pSpaced/remove" "$pDir"
[ ! -d "$pDir" ]
for pPiece in $osPieces; do [ ! -e "$pPiece" ]; done
# Cut off just after it makes its directory or its temp file, each script
# takes it with it: create, list, and remove, which leaves the patch alone.
vCutOff "$pIccPatch/create" star 1
vCutOff "$pIccPatch/list"
pDir=$("$pIccPatch/create" star 1)
osMine="$osMine $pDir"
vCutOff "$pIccPatch/remove" "$pDir"
"$pIccPatch/list" | grep -qx "$pDir up star 1 2 1"
"$pIccPatch/remove" "$pDir"
# A signal between pieces is a create that cannot finish: it exits 1 and
# hands what it made to its remove, which takes the directory it printed
# last, once every piece is gone. Stalled in the tr that writes the first
# line of the map, after its first pipe.
vCutOffAt TERM tr "$pIccPatch/create" star 1
for pMine in $osMine; do [ ! -d "$pMine" ]; done
rm -rf "$pWork"
vDisarm
echo ok
