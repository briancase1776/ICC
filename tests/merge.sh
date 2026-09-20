#!/bin/bash
# tests/merge.sh
# Prove the merge: get three pipes, merge side 0 of two into the third, push a
# Frames payload bigger than one lane holds through each inlet in turn, read it
# back whole from the outlet each time, then plain bytes on one lane from both
# inlets, remove it. The pipes stay up. An inlet that is the outlet, one
# given twice, and a lane that is not a lane are refused; remove takes what
# create made and not a path out of it or a look-alike; list answers for
# every merge whatever else /tmp holds, and calls a copierless merge down.
# Copyright (c) 2026 Brian Case. All rights reserved.
# AI contributor: Claude (Anthropic)
#
# MIT License text omitted for brevity, See LICENCE.TXT
set -eu
cd "$(dirname "$0")/.."
P=$(cd .claude/skills/icc-pipes/scripts && pwd)
F=$(cd .claude/skills/icc-frames/scripts && pwd)
M=$(cd .claude/skills/icc-merge/scripts && pwd)
t=$(mktemp -d); cd "$t"
a=$("$P/create" 6); b=$("$P/create" 6); c=$("$P/create" 6); x=$("$P/create" 2)
trap 'for p in $a $b $c $x; do "$P/remove" "$p" 2>/dev/null || :; done
      cd /; rm -rf "$t"' EXIT
"$M/create" "$c" 0 2>/dev/null && exit 1
"$M/create" "$c" 2 "$a" 2>/dev/null && exit 1
"$M/create" "$c" 0 "$x" 2>/dev/null && exit 1
"$M/create" "$c" 0 /tmp 2>/dev/null && exit 1
"$M/create" "$c" 0 "$c" 2>/dev/null && exit 1
"$M/create" "$c" 0 "$a" "$a" 2>/dev/null && exit 1
y=$("$P/create" 6); rm -f "$y/2"; mkdir "$y/2"
"$M/create" "$c" 0 "$y" 2>/dev/null && exit 1   # a lane that is not a lane
rmdir "$y/2"; "$P/remove" "$y"
m=$("$M/create" "$c" 0 "$a" "$b")
trap '"$M/remove" "$m" 2>/dev/null || :; for p in $a $b $c $x; do "$P/remove" "$p" 2>/dev/null || :; done
      cd /; rm -rf "$t"' EXIT
"$M/list" | grep -qx "$m up $c 0 $a $b"
# remove takes what create made and nothing else, and list answers for every
# merge whatever else is in /tmp.
v=$(mktemp -d); mkdir "$v/deep"; printf '%s\n0\n%s\n' "$c" "$a" > "$v/merge"; : > "$v/pid"
"$M/remove" "$m/../$(basename "$v")" 2>/dev/null && exit 1
[ -d "$v/deep" ]
k=$(mktemp -d /tmp/icc-merge-XXXXXXXX); mkdir "$k/deep"
printf '%s\n0\n%s\n' "$c" "$a" > "$k/merge"; : > "$k/pid"
"$M/remove" "$k" 2>/dev/null && exit 1
[ -d "$k/deep" ]
s=$(mktemp -d /tmp/icc-merge-XXXXXXXX); printf '%s\n0\n' "$c" > "$s/merge"; echo 1 > "$s/pid"
"$M/list" | grep -qx "$m up $c 0 $a $b"
h=$(mktemp -d /tmp/icc-merge-XXXXXXXX); printf '%s\n0\n%s\n' "$c" "$a" > "$h/merge"; : > "$h/pid"
"$M/list" | grep -qx "$h down $c 0 $a"
"$M/remove" "$h"; [ ! -d "$h" ]
rm -rf "$v" "$k" "$s"
head -c 150000 /dev/urandom > in
"$F/write" "$a" 0 < in
timeout 5 "$F/read" "$c" 1 > out; cmp in out
"$F/write" "$b" 0 < in
timeout 5 "$F/read" "$c" 1 > out; cmp in out
printf 'a' > "$a/2"; printf 'b' > "$b/2"
case $(timeout 1 dd if="$c/2" bs=4096 status=none) in ab|ba) ;; *) exit 1;; esac
"$M/remove" "$m"
[ ! -d "$m" ]
for p in $a $b $c; do "$P/list" | grep -qx "$p up"; done
"$P/remove" "$x"; "$P/remove" "$c"; "$P/remove" "$b"; "$P/remove" "$a"
cd /; rm -rf "$t"
trap - EXIT
echo ok
