#!/bin/bash
# tests/run.sh
# Prove read and write: get a pipe, push a payload bigger than one lane holds
# through it, read it back whole, compare bytes, both directions; push one
# far bigger with a read draining it; refuse a SIDE that is not a side and a
# count that is not a count, too big to count among them; do the round trip
# again on two lanes, the bundle CLAUDE.md calls the baseline; remove the
# pipes. Runs in a directory of its own and touches nothing else.
# Copyright (c) 2026 Brian Case. All rights reserved.
# AI contributor: Claude (Anthropic)
#
# MIT License text omitted for brevity, See LICENCE.TXT
set -eu
cd "$(dirname "$0")/.."
P=$(cd "${ICC_PIPES:-../ICC-Pipes}/.claude/skills/icc-pipes/scripts" && pwd)
F=$PWD/.claude/skills/icc-frames/scripts
t=$(mktemp -d); cd "$t"
d=$("$P/create" 6); made=$d
trap 'for x in $made; do "$P/remove" "$x" 2>/dev/null || :; done
      cd /; rm -rf "$t"' EXIT
# A read with nothing on its lane waits for the writer, and that is the
# usage: <> means the lane never says EOF, so a count that has not come
# cannot be told from one that never will. What it must not do is come back
# empty and call it a payload.
rc=0; timeout 1 "$F/read" "$d" 1 >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 124 ]
head -c 150000 /dev/urandom > in
"$F/write" "$d" 0 < in
timeout 5 "$F/read" "$d" 1 > out
cmp in out
"$F/write" "$d" 1 < in
timeout 5 "$F/read" "$d" 0 > out
cmp in out
printf 'done' | "$F/write" "$d" 0
[[ $(timeout 5 "$F/read" "$d" 1) == done ]]
# Bigger than the lanes hold, with a read draining it: the write cannot
# return until the read has taken enough, and both must still be exact.
# Sized inside the hold's depth, which is what bounds a write a read is
# already draining; SKILL.md says what that depth is.
head -c 262144 /dev/urandom > big
timeout 60 "$F/write" "$d" 0 < big & w=$!
timeout 60 "$F/read" "$d" 1 > bigout & r=$!
wait $w; wait $r; cmp big bigout
# A SIDE that is not a side is refused before anything is opened, so the
# pipe is as it was: <> creates, and a file among the lanes outlives them.
was=$(ls "$d")
"$F/write" "$d" 2 < /dev/null 2>/dev/null && exit 1
"$F/read" "$d" 'x[$(touch pwned)]' 2>/dev/null && exit 1
[ ! -e pwned ]; [ "$(ls "$d")" = "$was" ]
# A count that is not a count is a failure, and a leading zero is base ten.
printf 'garbage\n' 1<> "$d/0"
timeout 5 "$F/read" "$d" 1 >/dev/null 2>&1 && exit 1
printf '99999999999999999999\n' 1<> "$d/0"
timeout 5 "$F/read" "$d" 1 >/dev/null 2>&1 && exit 1
printf '010\n0123456789' 1<> "$d/0"
[[ $(timeout 5 "$F/read" "$d" 1) == 0123456789 ]]
# Two lanes is one straw each way and the same script, which is the bundle
# CLAUDE.md names as the baseline. Bigger than the one lane this side writes
# cannot be left on the wire here at all, so the read drains while the write
# runs, as above; sized inside the hold's depth, which is one pipe more.
d2=$("$P/create" 2); made="$made $d2"
# Past the hold nothing reaches a lane, so no read can free it, and the
# write is refused instead of waiting on a read that cannot help. A file and
# a pipe both, since what says so is the byte after the last one the hold
# took, not the size. The round trip after proves the wire was left alone.
head -c 200000 /dev/urandom > past
timeout 20 "$F/write" "$d2" 0 < past 2>/dev/null && exit 1
timeout 20 "$F/write" "$d2" 0 < <(cat past) 2>/dev/null && exit 1
cat past | timeout 20 "$F/write" "$d2" 0 2>/dev/null && exit 1
head -c 100000 /dev/urandom > in2
timeout 60 "$F/write" "$d2" 0 < in2 & w=$!
timeout 60 "$F/read" "$d2" 1 > out2 & r=$!
wait $w; wait $r; cmp in2 out2
timeout 60 "$F/write" "$d2" 1 < in2 & w=$!
timeout 60 "$F/read" "$d2" 0 > out2 & r=$!
wait $w; wait $r; cmp in2 out2
for x in $made; do "$P/remove" "$x"; done
trap - EXIT
cd /; rm -rf "$t"
echo ok
