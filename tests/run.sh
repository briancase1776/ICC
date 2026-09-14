#!/bin/bash
# tests/run.sh
# Prove read and write: get a pipe, push a payload bigger than one lane holds
# through it, read it back whole, compare bytes, both directions, remove it.
# Copyright (c) 2026 Brian Case. All rights reserved.
# AI contributor: Claude (Anthropic)
#
# MIT License text omitted for brevity, See LICENCE.TXT
set -eu
cd "$(dirname "$0")/.."
P=${ICC_PIPES:-../ICC-Pipes}/.claude/skills/icc-pipes/scripts
F=.claude/skills/icc-frames/scripts
d=$("$P/create" 6)
trap '"$P/remove" "$d" 2>/dev/null || :; rm -f in out' EXIT
head -c 150000 /dev/urandom > in
"$F/write" "$d" 0 < in
timeout 5 "$F/read" "$d" 1 > out
cmp in out
"$F/write" "$d" 1 < in
timeout 5 "$F/read" "$d" 0 > out
cmp in out
printf 'done' | "$F/write" "$d" 0
[[ $(timeout 5 "$F/read" "$d" 1) == done ]]
"$P/remove" "$d"
rm -f in out
trap - EXIT
echo ok
