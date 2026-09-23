#!/bin/bash
##
# @file frames.sh
# @brief Prove read and write: payloads round trip whole, and bad input fails.
# @details Prove read and write: get a pipe, push a payload bigger than one
#          lane holds through it, read it back whole, compare bytes, both
#          directions; push one far bigger with a read draining it;
#          refuse a SIDE that is not a side and a count that is not a
#          count, too big to count among them; do the round trip again on
#          two lanes, the bundle CLAUDE.md calls the baseline; remove the
#          pipes. Runs in a directory of its own and touches nothing else.
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
pIccPipes=$(cd ".claude/skills/icc-pipes/scripts" && pwd)
pIccFrames=$PWD/.claude/skills/icc-frames/scripts
pWork=$(mktemp -d)
cd "$pWork"
pDir=$("$pIccPipes/create" 6)
osMade=$pDir
trap 'for pPipe in $osMade; do
        "$pIccPipes/remove" "$pPipe" 2>/dev/null || :
      done
      cd /
      rm -rf "$pWork"' EXIT
# A read with nothing on its lane waits for the writer, and that is the
# usage: <> means the lane never says EOF, so a count that has not come
# cannot be told from one that never will. What it must not do is come back
# empty and call it a payload.
nStatus=0
timeout 1 "$pIccFrames/read" "$pDir" 1 >/dev/null 2>&1 || nStatus=$?
[ "$nStatus" -eq 124 ]
head -c 150000 /dev/urandom > in
"$pIccFrames/write" "$pDir" 0 < in
timeout 5 "$pIccFrames/read" "$pDir" 1 > out
cmp in out
"$pIccFrames/write" "$pDir" 1 < in
timeout 5 "$pIccFrames/read" "$pDir" 0 > out
cmp in out
printf 'done' | "$pIccFrames/write" "$pDir" 0
[[ $(timeout 5 "$pIccFrames/read" "$pDir" 1) == done ]]
# Bigger than the lanes hold, with a read draining it: the write cannot
# return until the read has taken enough, and both must still be exact.
# Sized inside the hold's depth, which is what bounds a write a read is
# already draining; SKILL.md says what that depth is.
head -c 262144 /dev/urandom > big
timeout 60 "$pIccFrames/write" "$pDir" 0 < big &
pidWrite=$!
timeout 60 "$pIccFrames/read" "$pDir" 1 > bigout &
pidRead=$!
wait $pidWrite
wait $pidRead
cmp big bigout
# A SIDE that is not a side is refused before anything is opened, so the
# pipe is as it was: <> creates, and a file among the lanes outlives them.
osBefore=$(ls "$pDir")
"$pIccFrames/write" "$pDir" 2 < /dev/null 2>/dev/null && exit 1
"$pIccFrames/read" "$pDir" 'x[$(touch pwned)]' 2>/dev/null && exit 1
[ ! -e pwned ]
[ "$(ls "$pDir")" = "$osBefore" ]
# A count that is not a count is a failure, and a leading zero is base ten.
printf 'garbage\n' 1<> "$pDir/0"
timeout 5 "$pIccFrames/read" "$pDir" 1 >/dev/null 2>&1 && exit 1
printf '99999999999999999999\n' 1<> "$pDir/0"
timeout 5 "$pIccFrames/read" "$pDir" 1 >/dev/null 2>&1 && exit 1
printf '010\n0123456789' 1<> "$pDir/0"
[[ $(timeout 5 "$pIccFrames/read" "$pDir" 1) == 0123456789 ]]
# Two lanes is one straw each way and the same script, which is the bundle
# CLAUDE.md names as the baseline. Bigger than the one lane this side writes
# cannot be left on the wire here at all, so the read drains while the write
# runs, as above; sized inside the hold's depth, which is one pipe more.
pDir2=$("$pIccPipes/create" 2)
osMade="$osMade $pDir2"
# Past the hold nothing reaches a lane, so no read can free it, and the
# write is refused instead of waiting on a read that cannot help. A file and
# a pipe both, since what says so is the byte after the last one the hold
# took, not the size. The round trip after proves the wire was left alone.
head -c 200000 /dev/urandom > past
timeout 20 "$pIccFrames/write" "$pDir2" 0 < past 2>/dev/null && exit 1
timeout 20 "$pIccFrames/write" "$pDir2" 0 < <(cat past) 2>/dev/null && exit 1
cat past | timeout 20 "$pIccFrames/write" "$pDir2" 0 2>/dev/null && exit 1
head -c 100000 /dev/urandom > in2
timeout 60 "$pIccFrames/write" "$pDir2" 0 < in2 &
pidWrite=$!
timeout 60 "$pIccFrames/read" "$pDir2" 1 > out2 &
pidRead=$!
wait $pidWrite
wait $pidRead
cmp in2 out2
timeout 60 "$pIccFrames/write" "$pDir2" 1 < in2 &
pidWrite=$!
timeout 60 "$pIccFrames/read" "$pDir2" 0 > out2 &
pidRead=$!
wait $pidWrite
wait $pidRead
cmp in2 out2
for pPipe in $osMade; do "$pIccPipes/remove" "$pPipe"; done
trap - EXIT
cd /
rm -rf "$pWork"
echo ok
