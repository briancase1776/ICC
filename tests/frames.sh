#!/bin/bash
##
# @file frames.sh
# @brief Prove read and write: payloads round trip whole, and bad input fails.
# @details Prove read and write: get a pipe, push a payload bigger than
#          one lane holds through it, read it back whole, compare bytes,
#          both directions; push one far bigger with a read draining it;
#          refuse a SIDE that is not a side, a pipe with an odd lane count
#          or a lane that is a file on either side, and a count that is
#          not a count, too big to count among them; do the round trip
#          again on two lanes, one straw each way; remove the pipes. Runs
#          in a directory of its own and touches nothing else.
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
aBefore=("$pDir"/*)
"$pIccFrames/write" "$pDir" 2 < /dev/null 2>/dev/null && exit 1
"$pIccFrames/read" "$pDir" 'x[$(touch pwned)]' 2>/dev/null && exit 1
[ ! -e pwned ]
aAfter=("$pDir"/*)
[ "${aAfter[*]}" = "${aBefore[*]}" ]
# A count that is not a count is a failure, and a leading zero is base ten.
printf 'garbage\n' 1<> "$pDir/0"
timeout 5 "$pIccFrames/read" "$pDir" 1 >/dev/null 2>&1 && exit 1
printf '99999999999999999999\n' 1<> "$pDir/0"
timeout 5 "$pIccFrames/read" "$pDir" 1 >/dev/null 2>&1 && exit 1
printf '010\n0123456789' 1<> "$pDir/0"
[[ $(timeout 5 "$pIccFrames/read" "$pDir" 1) == 0123456789 ]]
# An odd lane count is not a pipe Pipes makes, and both ends refuse it
# rather than pair it down: the read says so, and does not wait.
pOdd=$("$pIccPipes/create" 4)
osMade="$osMade $pOdd"
rm -f "$pOdd/3"
"$pIccFrames/write" "$pOdd" 0 < /dev/null 2>/dev/null && exit 1
nStatus=0
timeout 1 "$pIccFrames/read" "$pOdd" 1 >/dev/null 2>&1 || nStatus=$?
[ "$nStatus" -eq 1 ]
# Every lane is checked, as the fittings check them, not only the ones this
# end uses: a lane that is a file is refused from either side, and nothing is
# written to it.
pBroken=$("$pIccPipes/create" 4)
osMade="$osMade $pBroken"
rm -f "$pBroken/1"
: > "$pBroken/1"
"$pIccFrames/write" "$pBroken" 0 < /dev/null 2>/dev/null && exit 1
nStatus=0
timeout 1 "$pIccFrames/read" "$pBroken" 1 >/dev/null 2>&1 || nStatus=$?
[ "$nStatus" -eq 1 ]
[ ! -s "$pBroken/1" ]
rm -f "$pBroken/1"
mkfifo "$pBroken/1"
# Lanes are counted as the fittings count them, from a glob: a name that only
# starts with a digit is not a lane, nor is one with a newline in it, which
# ls prints as two lines of digits and a count of its output took for two.
pStray=$("$pIccPipes/create" 2)
osMade="$osMade $pStray"
: > "$pStray/2x"
: > "$pStray/"$'2\n3'
printf 'done' | "$pIccFrames/write" "$pStray" 0
[[ $(timeout 5 "$pIccFrames/read" "$pStray" 1) == done ]]
rm -f "$pStray/2x" "$pStray/"$'2\n3'
# Two lanes is one straw each way and the same script, as Frames' SKILL.md
# says. Bigger than the one lane this side writes cannot be left on the wire
# here at all, so the read drains while the write runs, as above; sized
# inside the hold's depth, which is one pipe more.
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
