#!/bin/bash
# tests/run.sh
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
P=${ICC_PIPES:-../ICC-Pipes}/.claude/skills/icc-pipes/scripts
F=${ICC_FRAMES:-../ICC-Frames}/.claude/skills/icc-frames/scripts
S=.claude/skills/icc-patch/scripts
end() { awk -v s="$1" -v i="$2" -v p="$3" \
  '$1==s && $2==i && ("," $4 ",") ~ ("," p ",") {print $3}' "$x/patch"; }
at() { e=$(end "$@"); [ -n "$e" ] || { echo "no end: $*" >&2; exit 1; }; echo "$e"; }
made() { [ "$(grep -c "$1" "$x/made")" -eq "$2" ]; }
mk() { x=$("$S/create" "$@"); mine="$mine $x"; }
holder() { for f in /proc/[0-9]*/fd/*; do
  [ "$(readlink "$f" 2>/dev/null)" = "$1/0" ] && { echo "$f" | cut -d/ -f3; return; }
done; }
"$S/create" 2>/dev/null && exit 1
"$S/create" bus 3 2>/dev/null && exit 1
"$S/create" ring 0 2>/dev/null && exit 1
"$S/create" ring 3 3 2>/dev/null && exit 1
"$S/create" mesh 1 banana 2>/dev/null && exit 1
mine=; w=$(mktemp -d); in=$w/in; out=$w/out
head -c 150000 /dev/urandom > "$in"
trap 'for q in $mine; do "$S/remove" "$q" 2>/dev/null || :; done; rm -rf "$w"' EXIT
mk star 3 6
"$S/list" | grep -qx "$x up star 3 6"
made icc-pipes 3; made icc-tee 0; made icc-merge 0
[ "$(grep -c '^p ' "$x/patch")" -eq 3 ]
"$F/write" "$(at 1 0 p)" 0 < "$in"
timeout 5 "$F/read" "$(at p 1 1)" 1 > "$out"; cmp "$in" "$out"
"$F/write" "$(at p 1 2)" 1 < "$in"
timeout 5 "$F/read" "$(at 2 0 p)" 0 > "$out"; cmp "$in" "$out"
printf 'me' > "$(at 0 0 p)/0"; [ "$(timeout 1 cat "$(at p 1 0)/0")" = me ]
[ -z "$(end 0 0 2)" ]; [ -z "$(end 0 1 p)" ]
"$S/remove" "$x"; [ ! -d "$x" ]
mk star 1; made icc-pipes 1; "$S/remove" "$x"
mk ring 3 6
"$S/list" | grep -qx "$x up ring 3 6"
made icc-pipes 3; made icc-tee 0; made icc-merge 0
"$F/write" "$(at 2 0 0)" 0 < "$in"
timeout 5 "$F/read" "$(at 0 1 2)" 1 > "$out"; cmp "$in" "$out"
"$F/write" "$(at 0 1 2)" 1 < "$in"
timeout 5 "$F/read" "$(at 2 0 0)" 0 > "$out"; cmp "$in" "$out"
[ -z "$(end 0 0 2)" ]
"$S/remove" "$x"; [ ! -d "$x" ]
mk ring 2; made icc-pipes 1; "$S/remove" "$x"
mk ring 1; made icc-pipes 1
printf 'me' > "$(at 0 0 0)/0"; [ "$(timeout 1 cat "$(at 0 1 0)/0")" = me ]
"$S/remove" "$x"
mk mesh 4 6
"$S/list" | grep -qx "$x up mesh 4 6"
made icc-pipes 9; made icc-tee 1; made icc-merge 1
[ "$(grep -c '^3 ' "$x/patch")" -eq 2 ]
"$F/write" "$(at 1 0 3)" 0 < "$in"
for r in 0 1 2 3; do timeout 5 "$F/read" "$(at $r 1 1)" 1 > "$out"; cmp "$in" "$out"; done
printf 'a' > "$(at 0 0 2)/2"; printf 'b' > "$(at 2 0 0)/2"
case $(timeout 1 cat "$(at 3 1 0)/2") in ab|ba) ;; *) exit 1;; esac
mkdir "$x/lock"; "$S/remove" "$x"; [ ! -d "$x" ]
mk mesh 2; made icc-pipes 1; made icc-tee 0
mv "$x/made" "$x/gone"; "$S/list" | grep -qx "$x down mesh 2 2"
mv "$x/gone" "$x/made"; "$S/remove" "$x"
mk mesh 1; made icc-pipes 0; "$S/remove" "$x"
mk mesh-p 1; made icc-pipes 1; made icc-merge 0
printf 'hi' > "$(at 0 0 p)/0"; [ "$(timeout 1 cat "$(at p 1 0)/0")" = hi ]
printf 'yo' > "$(at p 1 0)/1"; [ "$(timeout 1 cat "$(at 0 0 p)/1")" = yo ]
"$S/remove" "$x"
mk mesh-p 2; made icc-pipes 7; made icc-tee 1; made icc-merge 1
printf 'all' > "$(at p 0 1)/0"
for r in 0 1 p; do [ "$(timeout 1 cat "$(at $r 1 p)/0")" = all ]; done
"$S/remove" "$x"
mk ring-p 3 6
made icc-pipes 14; made icc-tee 4; made icc-merge 1
[ "$(end 1 1 0)" != "$(end 1 1 p)" ]
"$F/write" "$(at 1 0 2)" 0 < "$in"
timeout 5 "$F/read" "$(at 2 1 1)" 1 > "$out"; cmp "$in" "$out"
timeout 5 "$F/read" "$(at p 1 1)" 1 > "$out"; cmp "$in" "$out"
[ -z "$(end 0 1 1)" ]
printf 'all' > "$(at p 0 1)/2"
for r in 0 1 2; do [ "$(timeout 1 cat "$(at $r 1 p)/2")" = all ]; done
m=$(cut -d' ' -f2 "$x/made")
"$S/remove" "$x"; [ ! -d "$x" ]
for p in $m; do [ ! -e "$p" ]; done
mk ring-p 1; made icc-pipes 4; made icc-tee 1; made icc-merge 0
printf 'hi' > "$(at p 0 0)/0"; [ "$(timeout 1 cat "$(at 0 1 p)/0")" = hi ]
"$S/remove" "$x"
mk star 1 2; e=$(at 0 0 p); h=$(holder "$e"); [ -n "$h" ]
"$S/remove" "$x"; sleep 1   # dead is dead: reaped, or a zombie nobody reaped
case $(ps -o stat= -p "$h" 2>/dev/null) in ''|Z*) ;; *) exit 1;; esac
mk star 1 2; e=$(at 0 0 p); touch "$e/obstruct"
"$S/remove" "$x" 2>/dev/null && exit 1
[ -d "$x" ]; rm -f "$e/obstruct"
"$S/remove" "$x" 2>/dev/null; [ ! -d "$x" ]; rmdir "$e" 2>/dev/null || :
for q in $mine; do [ ! -d "$q" ]; done
rm -rf "$w"
trap - EXIT
echo ok
