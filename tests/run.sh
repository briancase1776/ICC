#!/bin/bash
# tests/run.sh
# Prove the merge: get three pipes, merge side 0 of two into the third, push a
# Frames payload bigger than one lane holds through each inlet in turn, read it
# back whole from the outlet each time, then plain bytes on one lane from both
# inlets, remove it. The pipes stay up. An inlet that is the outlet, and
# one given twice, are refused.
# Copyright (c) 2026 Brian Case. All rights reserved.
# AI contributor: Claude (Anthropic)
#
# MIT License text omitted for brevity, See LICENCE.TXT
set -eu
cd "$(dirname "$0")/.."
P=${ICC_PIPES:-../ICC-Pipes}/.claude/skills/icc-pipes/scripts
F=${ICC_FRAMES:-../ICC-Frames}/.claude/skills/icc-frames/scripts
M=.claude/skills/icc-merge/scripts
a=$("$P/create" 6); b=$("$P/create" 6); c=$("$P/create" 6); x=$("$P/create" 2)
trap 'for p in $a $b $c $x; do "$P/remove" "$p" 2>/dev/null || :; done; rm -f in out' EXIT
"$M/create" "$c" 0 2>/dev/null && exit 1
"$M/create" "$c" 2 "$a" 2>/dev/null && exit 1
"$M/create" "$c" 0 "$x" 2>/dev/null && exit 1
"$M/create" "$c" 0 /tmp 2>/dev/null && exit 1
"$M/create" "$c" 0 "$c" 2>/dev/null && exit 1
"$M/create" "$c" 0 "$a" "$a" 2>/dev/null && exit 1
m=$("$M/create" "$c" 0 "$a" "$b")
trap '"$M/remove" "$m" 2>/dev/null || :; for p in $a $b $c $x; do "$P/remove" "$p" 2>/dev/null || :; done; rm -f in out' EXIT
"$M/list" | grep -qx "$m up $c 0 $a $b"
head -c 150000 /dev/urandom > in
"$F/write" "$a" 0 < in
timeout 5 "$F/read" "$c" 1 > out; cmp in out
"$F/write" "$b" 0 < in
timeout 5 "$F/read" "$c" 1 > out; cmp in out
printf 'a' > "$a/2"; printf 'b' > "$b/2"
case $(timeout 1 cat "$c/2") in ab|ba) ;; *) exit 1;; esac
"$M/remove" "$m"
[ ! -d "$m" ]
for p in $a $b $c; do "$P/list" | grep -qx "$p up"; done
"$P/remove" "$x"; "$P/remove" "$c"; "$P/remove" "$b"; "$P/remove" "$a"
rm -f in out
trap - EXIT
echo ok
