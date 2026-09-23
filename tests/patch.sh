#!/bin/bash
# tests/patch.sh
# Prove the bay: make each shape, see the map name the cables the shape says
# and no more, push a Frames payload bigger than one lane holds from a seat
# to its peers and read it back whole at every one, plain bytes back the
# other way, see a hold go when the patch does, see a piece that will not go
# named and tried again, remove it, see nothing left.
# Copyright (c) 2026 Brian Case. All rights reserved.
# AI contributor: Claude (Anthropic)
#
# MIT License text omitted for brevity, See LICENCE.TXT
set -eu
cd "$(dirname "$0")/.."
pIccPipes=.claude/skills/icc-pipes/scripts
pIccFrames=.claude/skills/icc-frames/scripts
pIccPatch=.claude/skills/icc-patch/scripts
pEnd() { local osSeat=$1 eSide=$2 osPeer=$3; awk -v s="$osSeat" -v i="$eSide" -v p="$osPeer" \
  '$1==s && $2==i && ("," $4 ",") ~ ("," p ",") {print $3}' "$pDir/patch"; }
pAt() { local osSeat=$1 eSide=$2 osPeer=$3 pFound; pFound=$(pEnd "$osSeat" "$eSide" "$osPeer"); [ -n "$pFound" ] || { echo "no end: $osSeat $eSide $osPeer" >&2; exit 1; }; echo "$pFound"; }
vMade() { local osSkill=$1 nCount=$2; [ "$(grep -c "$osSkill" "$pDir/made")" -eq "$nCount" ]; }
vEnds() { local nEnds=$1; [ "$(( $(wc -l < "$pDir/patch") - 1 ))" -eq "$nEnds" ]; }   # the map, and no more
vMake() { pDir=$("$pIccPatch/create" "$@"); osMine="$osMine $pDir"; }
pidHolder() { local pPipe=$1; for pFd in /proc/[0-9]*/fd/*; do
  [ "$(readlink "$pFd" 2>/dev/null)" = "$pPipe/0" ] && { echo "$pFd" | cut -d/ -f3; return; }
done; }
"$pIccPatch/create" 2>/dev/null && exit 1
"$pIccPatch/create" bus 3 2>/dev/null && exit 1
"$pIccPatch/create" ring 0 2>/dev/null && exit 1
"$pIccPatch/create" ring 3 3 2>/dev/null && exit 1
"$pIccPatch/create" mesh 1 banana 2>/dev/null && exit 1
osMine=; pWork=$(mktemp -d); pIn=$pWork/in; pOut=$pWork/out
head -c 150000 /dev/urandom > "$pIn"
trap 'for pMine in $osMine; do "$pIccPatch/remove" "$pMine" 2>/dev/null || :; done; rm -rf "$pWork"' EXIT
vMake star 3 6
"$pIccPatch/list" | grep -qx "$pDir up star 3 6"
vMade icc-pipes 3; vMade icc-tee 0; vMade icc-merge 0; vEnds 6
[ "$(grep -c '^p ' "$pDir/patch")" -eq 3 ]
"$pIccFrames/write" "$(pAt 1 0 p)" 0 < "$pIn"
timeout 5 "$pIccFrames/read" "$(pAt p 1 1)" 1 > "$pOut"; cmp "$pIn" "$pOut"
"$pIccFrames/write" "$(pAt p 1 2)" 1 < "$pIn"
timeout 5 "$pIccFrames/read" "$(pAt 2 0 p)" 0 > "$pOut"; cmp "$pIn" "$pOut"
printf 'me' > "$(pAt 0 0 p)/0"; [ "$(timeout 1 cat "$(pAt p 1 0)/0")" = me ]
[ -z "$(pEnd 0 0 2)" ]; [ -z "$(pEnd 0 1 p)" ]
"$pIccPatch/remove" "$pDir"; [ ! -d "$pDir" ]
vMake star 1; vMade icc-pipes 1; vEnds 2; "$pIccPatch/remove" "$pDir"
vMake ring 3 6
"$pIccPatch/list" | grep -qx "$pDir up ring 3 6"
vMade icc-pipes 3; vMade icc-tee 0; vMade icc-merge 0; vEnds 6
"$pIccFrames/write" "$(pAt 2 0 0)" 0 < "$pIn"
timeout 5 "$pIccFrames/read" "$(pAt 0 1 2)" 1 > "$pOut"; cmp "$pIn" "$pOut"
"$pIccFrames/write" "$(pAt 0 1 2)" 1 < "$pIn"
timeout 5 "$pIccFrames/read" "$(pAt 2 0 0)" 0 > "$pOut"; cmp "$pIn" "$pOut"
[ -z "$(pEnd 0 0 2)" ]
"$pIccPatch/remove" "$pDir"; [ ! -d "$pDir" ]
vMake ring 2; vMade icc-pipes 1; vEnds 2; "$pIccPatch/remove" "$pDir"
vMake ring 1; vMade icc-pipes 1; vEnds 2
printf 'me' > "$(pAt 0 0 0)/0"; [ "$(timeout 1 cat "$(pAt 0 1 0)/0")" = me ]
"$pIccPatch/remove" "$pDir"
vMake mesh 4 6
"$pIccPatch/list" | grep -qx "$pDir up mesh 4 6"
vMade icc-pipes 9; vMade icc-tee 1; vMade icc-merge 1; vEnds 9
[ "$(grep -c '^- ' "$pDir/patch")" -eq 1 ]          # the hub, named, held by nobody
[ "$(grep -c '^3 ' "$pDir/patch")" -eq 2 ]
"$pIccFrames/write" "$(pAt 1 0 3)" 0 < "$pIn"
for osSeat in 0 1 2 3; do timeout 5 "$pIccFrames/read" "$(pAt $osSeat 1 1)" 1 > "$pOut"; cmp "$pIn" "$pOut"; done
printf 'a' > "$(pAt 0 0 2)/2"; printf 'b' > "$(pAt 2 0 0)/2"
case $(timeout 1 cat "$(pAt 3 1 0)/2") in ab|ba) ;; *) exit 1;; esac
mkdir "$pDir/lock"; "$pIccPatch/remove" "$pDir"; [ ! -d "$pDir" ]
vMake mesh 2; vMade icc-pipes 1; vMade icc-tee 0; vEnds 2
mv "$pDir/made" "$pDir/gone"; "$pIccPatch/list" | grep -qx "$pDir down mesh 2 2"
mv "$pDir/gone" "$pDir/made"; "$pIccPatch/remove" "$pDir"
vMake mesh 1; vMade icc-pipes 0; vEnds 0; "$pIccPatch/remove" "$pDir"
vMake mesh-p 1; vMade icc-pipes 1; vMade icc-merge 0; vEnds 2
printf 'hi' > "$(pAt 0 0 p)/0"; [ "$(timeout 1 cat "$(pAt p 1 0)/0")" = hi ]
printf 'yo' > "$(pAt p 1 0)/1"; [ "$(timeout 1 cat "$(pAt 0 0 p)/1")" = yo ]
"$pIccPatch/remove" "$pDir"
vMake mesh-p 2; vMade icc-pipes 7; vMade icc-tee 1; vMade icc-merge 1; vEnds 7
printf 'all' > "$(pAt p 0 1)/0"
for osSeat in 0 1 p; do [ "$(timeout 1 cat "$(pAt $osSeat 1 p)/0")" = all ]; done
"$pIccPatch/remove" "$pDir"
vMake ring-p 3 6
vMade icc-pipes 14; vMade icc-tee 4; vMade icc-merge 1; vEnds 14
[ "$(grep -c '^- ' "$pDir/patch")" -eq 3 ]          # one coupler per seat
[ "$(pEnd 1 1 0)" != "$(pEnd 1 1 p)" ]
"$pIccFrames/write" "$(pAt 1 0 2)" 0 < "$pIn"
timeout 5 "$pIccFrames/read" "$(pAt 2 1 1)" 1 > "$pOut"; cmp "$pIn" "$pOut"
timeout 5 "$pIccFrames/read" "$(pAt p 1 1)" 1 > "$pOut"; cmp "$pIn" "$pOut"
[ -z "$(pEnd 0 1 1)" ]
printf 'all' > "$(pAt p 0 1)/2"
for osSeat in 0 1 2; do [ "$(timeout 1 cat "$(pAt $osSeat 1 p)/2")" = all ]; done
osPieces=$(cut -d' ' -f2 "$pDir/made")
"$pIccPatch/remove" "$pDir"; [ ! -d "$pDir" ]
for pPiece in $osPieces; do [ ! -e "$pPiece" ]; done
vMake ring-p 1; vMade icc-pipes 4; vMade icc-tee 1; vMade icc-merge 0; vEnds 5
[ -z "$(grep '^- ' "$pDir/patch")" ]                # ring-p 1 has no coupler: p holds both
printf 'hi' > "$(pAt p 0 0)/0"; [ "$(timeout 1 cat "$(pAt 0 1 p)/0")" = hi ]
"$pIccPatch/remove" "$pDir"
vMake star 1 2; pHeld=$(pAt 0 0 p); pidHold=$(pidHolder "$pHeld"); [ -n "$pidHold" ]
"$pIccPatch/remove" "$pDir"; sleep 1   # dead is dead: reaped, or a zombie nobody reaped
case $(ps -o stat= -p "$pidHold" 2>/dev/null) in ''|Z*) ;; *) exit 1;; esac
vMake star 1 2; pHeld=$(pAt 0 0 p); touch "$pHeld/obstruct"
"$pIccPatch/remove" "$pDir" 2>/dev/null && exit 1
[ -d "$pDir" ]; rm -f "$pHeld/obstruct"
"$pIccPatch/remove" "$pDir" 2>/dev/null; [ ! -d "$pDir" ]; rmdir "$pHeld" 2>/dev/null || :
for pMine in $osMine; do [ ! -d "$pMine" ]; done
rm -rf "$pWork"
trap - EXIT
echo ok
