#!/bin/bash
# tests/run.sh
# Prove read and write: get a pipe, push a payload bigger than one lane holds
# through it, read it back whole, compare bytes, both directions; push one
# far bigger with a read draining it; refuse a SIDE that is not a side and a
# count that is not a count; remove the pipe. Runs in a directory of its own
# and touches nothing else.
# Copyright (c) 2026 Brian Case. All rights reserved.
# AI contributor: Claude (Anthropic)
#
# MIT License text omitted for brevity, See LICENCE.TXT
set -eu
cd "$(dirname "$0")/.."
P=$(cd "${ICC_PIPES:-../ICC-Pipes}/.claude/skills/icc-pipes/scripts" && pwd)
F=$PWD/.claude/skills/icc-frames/scripts
t=$(mktemp -d); cd "$t"
d=$("$P/create" 6)
trap '"$P/remove" "$d" 2>/dev/null || :; cd /; rm -rf "$t"' EXIT
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
head -c 1000000 /dev/urandom > big
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
printf '010\n0123456789' 1<> "$d/0"
[[ $(timeout 5 "$F/read" "$d" 1) == 0123456789 ]]
"$P/remove" "$d"
trap - EXIT
cd /; rm -rf "$t"
echo ok
