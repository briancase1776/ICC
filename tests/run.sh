#!/bin/bash
# tests/run.sh
# Prove the bay: make each shape, see the map name the cables the shape says
# and no more, push a Frames payload bigger than one lane holds from a seat
# to its peers and read it back whole at every one, plain bytes back the
# other way, take the lock and see nobody else can, remove it, see nothing
# left.
# Copyright (c) 2026 Brian Case. All rights reserved.
# AI contributor: Claude (Anthropic)
#
# MIT License text omitted for brevity, See LICENCE.TXT
set -eu
cd "$(dirname "$0")/.."
P=${ICC_PIPES:-../ICC-Pipes}/.claude/skills/icc-pipes/scripts
F=${ICC_FRAMES:-../ICC-Frames}/.claude/skills/icc-frames/scripts
S=.claude/skills/icc-patch/scripts
end() { awk -v s="$1" -v i="$2" -v p="$3" \
  '$1==s && $2==i && ("," $4 ",") ~ ("," p ",") {print $3}' "$x/patch"; }
made() { [ "$(grep -c "$1" "$x/made")" -eq "$2" ]; }
"$S/create" 2>/dev/null && exit 1
"$S/create" bus 3 2>/dev/null && exit 1
"$S/create" ring 0 2>/dev/null && exit 1
"$S/create" ring 3 3 2>/dev/null && exit 1
[ -z "$("$S/list")" ]
head -c 150000 /dev/urandom > in
trap 'for x in /tmp/icc-patch-*; do "$S/remove" "$x" 2>/dev/null || :; done; rm -f in out' EXIT
x=$("$S/create" star 3 6)
"$S/list" | grep -qx "$x up star 3 6"
made icc-pipes 3; made icc-tee 0; made icc-merge 0
[ "$(grep -c '^p ' "$x/patch")" -eq 3 ]
"$F/write" "$(end 1 0 p)" 0 < in
timeout 5 "$F/read" "$(end p 1 1)" 1 > out; cmp in out
"$F/write" "$(end p 1 2)" 1 < in
timeout 5 "$F/read" "$(end 2 0 p)" 0 > out; cmp in out
printf 'me' > "$(end 0 0 p)/0"; [ "$(timeout 1 cat "$(end p 1 0)/0")" = me ]
[ -z "$(end 0 0 2)" ]; [ -z "$(end 0 1 p)" ]
"$S/remove" "$x"; [ ! -d "$x" ]
x=$("$S/create" star 1); made icc-pipes 1; "$S/remove" "$x"
x=$("$S/create" ring 3 6)
"$S/list" | grep -qx "$x up ring 3 6"
made icc-pipes 3; made icc-tee 0; made icc-merge 0
"$F/write" "$(end 2 0 0)" 0 < in
timeout 5 "$F/read" "$(end 0 1 2)" 1 > out; cmp in out
"$F/write" "$(end 0 1 2)" 1 < in
timeout 5 "$F/read" "$(end 2 0 0)" 0 > out; cmp in out
[ -z "$(end 0 0 2)" ]
"$S/remove" "$x"; [ ! -d "$x" ]
x=$("$S/create" ring 2); made icc-pipes 1; "$S/remove" "$x"
x=$("$S/create" ring 1); made icc-pipes 1
printf 'me' > "$(end 0 0 0)/0"; [ "$(timeout 1 cat "$(end 0 1 0)/0")" = me ]
"$S/remove" "$x"
x=$("$S/create" mesh 4 6)
"$S/list" | grep -qx "$x up mesh 4 6"
made icc-pipes 9; made icc-tee 1; made icc-merge 1
[ "$(grep -c '^3 ' "$x/patch")" -eq 2 ]
mkdir "$x/lock"; mkdir "$x/lock" 2>/dev/null && exit 1; rmdir "$x/lock"
"$F/write" "$(end 1 0 3)" 0 < in
for r in 0 1 2 3; do timeout 5 "$F/read" "$(end $r 1 1)" 1 > out; cmp in out; done
printf 'a' > "$(end 0 0 2)/2"; printf 'b' > "$(end 2 0 0)/2"
case $(timeout 1 cat "$(end 3 1 0)/2") in ab|ba) ;; *) exit 1;; esac
mkdir "$x/lock"; "$S/remove" "$x"; [ ! -d "$x" ]
x=$("$S/create" mesh 2); made icc-pipes 1; made icc-tee 0; "$S/remove" "$x"
x=$("$S/create" mesh 1); made icc-pipes 0; "$S/remove" "$x"
x=$("$S/create" mesh-p 1); made icc-pipes 1; made icc-merge 0
printf 'hi' > "$(end p 0 0)/0"; [ "$(timeout 1 cat "$(end 0 1 p)/0")" = hi ]
printf 'yo' > "$(end 0 1 p)/1"; [ "$(timeout 1 cat "$(end p 0 0)/1")" = yo ]
"$S/remove" "$x"
x=$("$S/create" mesh-p 2); made icc-pipes 7; made icc-tee 1; made icc-merge 1
printf 'all' > "$(end p 0 1)/0"
for r in 0 1 p; do [ "$(timeout 1 cat "$(end $r 1 p)/0")" = all ]; done
"$S/remove" "$x"
x=$("$S/create" ring-p 3 6)
made icc-pipes 11; made icc-tee 4; made icc-merge 1
"$F/write" "$(end 1 0 2)" 0 < in
timeout 5 "$F/read" "$(end 2 1 1)" 1 > out; cmp in out
timeout 5 "$F/read" "$(end p 1 1)" 1 > out; cmp in out
[ -z "$(end 0 1 1)" ]
printf 'all' > "$(end p 0 1)/2"
for r in 0 1 2; do [ "$(timeout 1 cat "$(end $r 1 p)/2")" = all ]; done
m=$(cut -d' ' -f2 "$x/made")
"$S/remove" "$x"; [ ! -d "$x" ]
for p in $m; do [ ! -e "$p" ]; done
x=$("$S/create" ring-p 1); made icc-pipes 3; made icc-tee 1; made icc-merge 0
printf 'hi' > "$(end p 0 0)/0"; [ "$(timeout 1 cat "$(end 0 1 p)/0")" = hi ]
"$S/remove" "$x"
[ -z "$("$S/list")" ]
rm -f in out
trap - EXIT
echo ok
