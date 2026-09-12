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
# set -e is ignored for a pipeline that begins with !, so `! cmd` states a
# refusal without ever being able to fail the harness. no() runs the command
# and stops here if it succeeds.
no() { if "$@" 2>/dev/null; then echo "not refused: $*" >&2; exit 1; fi; }
no "$T/create" "$a" 0
no "$T/create" "$a" 2 "$b"
no "$T/create" "$a" 0 "$x"
no "$T/create" "$a" 0 /tmp
no "$T/create" "$a" 0 "$a"        # SRC as its own DST
no "$T/create" "$a" 0 "$b" "$b"   # the same DST twice
no "$T/create" "$a" 0 "$b" "$b/"  # the same DST spelled two ways
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
# remove signals a copier, not whatever pid sits in the file, and takes the
# two files it made, not the directory. A look-alike holding a stranger's pid
# loses its own two files and nothing else; one with a file beside them is
# left where it is. list does not announce a directory with no DIR/tee.
sleep 60 & s=$!
f=$(mktemp -d /tmp/icc-tee-XXXXXXXX)
printf '%s\n' /tmp/not-a-pipe 0 /tmp/nor-this > "$f/tee"; echo "$s" > "$f/pid"
"$T/remove" "$f"; [ ! -d "$f" ]; kill -0 "$s"; kill "$s"
f=$(mktemp -d /tmp/icc-tee-XXXXXXXX)
printf '%s\n' /tmp/not-a-pipe 0 /tmp/nor-this > "$f/tee"; echo 1 > "$f/pid"
: > "$f/keep"; no "$T/remove" "$f"; [ -f "$f/keep" ]; rm -rf "$f"
f=$(mktemp -d /tmp/icc-tee-XXXXXXXX); echo 1 > "$f/pid"
[ -z "$("$T/list" 2>&1 >/dev/null)" ]
"$T/list" 2>/dev/null | grep -q "$f" && exit 1
rm -rf "$f"
no "$T/remove" "$a"
for p in $a $b $c; do "$P/list" | grep -qx "$p up"; done
"$P/remove" "$x"; "$P/remove" "$c"; "$P/remove" "$b"; "$P/remove" "$a"
rm -f in out
trap - EXIT
echo ok
