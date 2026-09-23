#!/bin/bash
##
# @file patch.sh
# @brief Prove the bay: every shape makes the map it says, and carries.
# @details Prove the bay: make each shape, see the map name the cables the
#          shape says and no more, push a Frames payload bigger than one
#          lane holds from a seat to its peers and read it back whole at
#          every one, plain bytes back the other way, see a hold go when
#          the patch does, see a piece that will not go named and tried
#          again, remove it, see nothing left. A create cut off by a
#          signal leaves nothing either.
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
pIccPipes=.claude/skills/icc-pipes/scripts
pIccFrames=.claude/skills/icc-frames/scripts
pIccPatch=.claude/skills/icc-patch/scripts

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
# @param $1... - SHAPE N [LANES], as Patch's create takes them
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
osMine=
pWork=$(mktemp -d)
pIn=$pWork/in
pOut=$pWork/out
head -c 150000 /dev/urandom > "$pIn"
trap 'for pMine in $osMine; do
        "$pIccPatch/remove" "$pMine" 2>/dev/null || :
      done
      rm -rf "$pWork"' EXIT
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
"$pIccPatch/list" | grep -qx "$pDir up star 3 6"
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
"$pIccPatch/list" | grep -qx "$pDir up ring 3 6"
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
"$pIccPatch/list" | grep -qx "$pDir up mesh 4 6"
vMade icc-pipes 9
vMade icc-tee 1
vMade icc-merge 1
vEnds 9
# the hub, named, held by nobody
[ "$(grep -c '^- ' "$pDir/patch")" -eq 1 ]
[ "$(grep -c '^3 ' "$pDir/patch")" -eq 2 ]
pWriteEnd=$(pAt 1 0 3)
"$pIccFrames/write" "$pWriteEnd" 0 < "$pIn"
for osSeat in 0 1 2 3; do
  pReadEnd=$(pAt $osSeat 1 1)
  timeout 5 "$pIccFrames/read" "$pReadEnd" 1 > "$pOut"
  cmp "$pIn" "$pOut"
done
pWriteEnd=$(pAt 0 0 2)
printf 'a' > "$pWriteEnd/2"
pWriteEnd=$(pAt 2 0 0)
printf 'b' > "$pWriteEnd/2"
pReadEnd=$(pAt 3 1 0)
case $(timeout 1 cat "$pReadEnd/2") in
  ab|ba)
    ;;
  *)
    exit 1
    ;;
esac
mkdir "$pDir/lock"
"$pIccPatch/remove" "$pDir"
[ ! -d "$pDir" ]
vMake mesh 2
vMade icc-pipes 1
vMade icc-tee 0
vEnds 2
mv "$pDir/made" "$pDir/gone"
"$pIccPatch/list" | grep -qx "$pDir down mesh 2 2"
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
vMake mesh-p 2
vMade icc-pipes 7
vMade icc-tee 1
vMade icc-merge 1
vEnds 7
pWriteEnd=$(pAt p 0 1)
printf 'all' > "$pWriteEnd/0"
for osSeat in 0 1 p; do
  pReadEnd=$(pAt $osSeat 1 p)
  [ "$(timeout 1 cat "$pReadEnd/0")" = all ]
done
"$pIccPatch/remove" "$pDir"
vMake ring-p 3 6
vMade icc-pipes 14
vMade icc-tee 4
vMade icc-merge 1
vEnds 14
# one coupler per seat
[ "$(grep -c '^- ' "$pDir/patch")" -eq 3 ]
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
"$pSpaced/list" | grep -qx "$pDir up star 1 2"
osPieces=$(cut -d' ' -f1 "$pDir/made")
"$pSpaced/remove" "$pDir"
[ ! -d "$pDir" ]
for pPiece in $osPieces; do [ ! -e "$pPiece" ]; done
# A signal between pieces is a create that cannot finish: it takes what it
# made and exits 1, as one inside a piece does. This tr stalls the first line
# of the map, and takes itself away so that the next tr is the real one.
mkdir "$pWork/bin"
printf '%s\n' '#!/bin/bash' 'rm -- "$0"' 'echo $$ > "${0%/*}/stalled"' \
  'exec sleep 30' > "$pWork/bin/tr"
chmod +x "$pWork/bin/tr"
aPatches=(/tmp/icc-patch-*/)
aPipes=(/tmp/icc-pipes-*/)
nPatches=${#aPatches[@]}
nPipes=${#aPipes[@]}
PATH=$pWork/bin:$PATH "$pIccPatch/create" star 1 >/dev/null 2>&1 &
pidCreate=$!
while [ ! -s "$pWork/bin/stalled" ]; do
  kill -0 $pidCreate 2>/dev/null || break
done
kill -TERM $pidCreate
kill "$(cat "$pWork/bin/stalled")"
nStatus=0
wait $pidCreate || nStatus=$?
[ "$nStatus" -eq 1 ]
aPatches=(/tmp/icc-patch-*/)
aPipes=(/tmp/icc-pipes-*/)
[ "${#aPatches[@]}" -eq "$nPatches" ]
[ "${#aPipes[@]}" -eq "$nPipes" ]
for pMine in $osMine; do [ ! -d "$pMine" ]; done
rm -rf "$pWork"
trap - EXIT
echo ok
