#!/bin/bash
##
# @file merge.sh
# @brief Prove the merge: two pipes' side copied whole onto a third.
# @details Prove the merge: get three pipes, merge side 0 of two into the
#          third, push a Frames payload bigger than one lane holds
#          through each inlet in turn, read it back whole from the outlet
#          each time, then plain bytes on one lane from both inlets,
#          remove it. The pipes stay up. An inlet that is the outlet, one
#          given twice, and a lane that is not a lane are refused; remove
#          takes what create made and not a path out of it or a
#          look-alike; list answers for every merge whatever else /tmp
#          holds, and calls a copierless merge down.
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
pIccPipes=$(cd .claude/skills/icc-pipes/scripts && pwd)
pIccFrames=$(cd .claude/skills/icc-frames/scripts && pwd)
pIccMerge=$(cd .claude/skills/icc-merge/scripts && pwd)
pWork=$(mktemp -d)
cd "$pWork"
pPipeA=$("$pIccPipes/create" 6)
pPipeB=$("$pIccPipes/create" 6)
pPipeC=$("$pIccPipes/create" 6)
pNarrow=$("$pIccPipes/create" 2)
trap 'for pPipe in $pPipeA $pPipeB $pPipeC $pNarrow; do
        "$pIccPipes/remove" "$pPipe" 2>/dev/null || :
      done
      cd /
      rm -rf "$pWork"' EXIT
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
pMergeDir=$("$pIccMerge/create" "$pPipeC" 0 "$pPipeA" "$pPipeB")
trap '"$pIccMerge/remove" "$pMergeDir" 2>/dev/null || :
      for pPipe in $pPipeA $pPipeB $pPipeC $pNarrow; do
        "$pIccPipes/remove" "$pPipe" 2>/dev/null || :
      done
      cd /
      rm -rf "$pWork"' EXIT
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
printf 'a' > "$pPipeA/2"
printf 'b' > "$pPipeB/2"
case $(timeout 1 dd if="$pPipeC/2" bs=4096 status=none) in
  ab|ba)
    ;;
  *)
    exit 1
    ;;
esac
"$pIccMerge/remove" "$pMergeDir"
[ ! -d "$pMergeDir" ]
for pPipe in $pPipeA $pPipeB $pPipeC; do
  "$pIccPipes/list" | grep -qx "$pPipe up"
done
"$pIccPipes/remove" "$pNarrow"
"$pIccPipes/remove" "$pPipeC"
"$pIccPipes/remove" "$pPipeB"
"$pIccPipes/remove" "$pPipeA"
cd /
rm -rf "$pWork"
trap - EXIT
echo ok
