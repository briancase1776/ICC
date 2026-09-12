#!/bin/bash
# tests/run.sh
# Prove the tee: get three pipes, tee side 0 of one into the other two, push
# a Frames payload bigger than one lane holds, read it back whole from both
# outlets, then plain bytes on one lane, remove it. The pipes stay up.
# Copyright (c) 2026 Brian Case. All rights reserved.
# AI contributor: Claude (Anthropic)
#
# MIT License text omitted for brevity, See LICENCE.TXT
set -eu
cd "$(dirname "$0")/.."
P=${ICC_PIPES:-../ICC-Pipes}/.claude/skills/icc-pipes/scripts
F=${ICC_FRAMES:-../ICC-Frames}/.claude/skills/icc-frames/scripts
T=.claude/skills/icc-tee/scripts
a=$("$P/create" 6); b=$("$P/create" 6); c=$("$P/create" 6); x=$("$P/create" 2)
trap 'for p in $a $b $c $x; do "$P/remove" "$p" 2>/dev/null || :; done; rm -f in out' EXIT
! "$T/create" "$a" 0 2>/dev/null
! "$T/create" "$a" 2 "$b" 2>/dev/null
! "$T/create" "$a" 0 "$x" 2>/dev/null
! "$T/create" "$a" 0 /tmp 2>/dev/null
t=$("$T/create" "$a" 0 "$b" "$c")
trap '"$T/remove" "$t" 2>/dev/null || :; for p in $a $b $c $x; do "$P/remove" "$p" 2>/dev/null || :; done; rm -f in out' EXIT
"$T/list" | grep -qx "$t up $a 0 $b $c"
head -c 150000 /dev/urandom > in
"$F/write" "$a" 0 < in
timeout 5 "$F/read" "$b" 1 > out; cmp in out
timeout 5 "$F/read" "$c" 1 > out; cmp in out
printf 'plain' > "$a/2"
[ "$(timeout 1 cat "$b/2")" = plain ] && [ "$(timeout 1 cat "$c/2")" = plain ]
"$T/remove" "$t"
[ ! -d "$t" ]
for p in $a $b $c; do "$P/list" | grep -qx "$p up"; done
"$P/remove" "$x"; "$P/remove" "$c"; "$P/remove" "$b"; "$P/remove" "$a"
rm -f in out
trap - EXIT
echo ok
