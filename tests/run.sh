#!/bin/sh
# tests/run.sh
# Prove the transcription: get two pipes from Pipes, put a Frames payload
# bigger than one lane holds on one, take it off as text, see the text is
# the alphabet and nothing else, put it on the other, read it back whole,
# compare bytes, both directions; an empty payload; text that is not the
# alphabet puts nothing on the wire, and a wire with nothing on it prints
# nothing; remove the pipes.
# Copyright (c) 2026 Brian Case. All rights reserved.
# AI contributor: Claude (Anthropic)
#
# MIT License text omitted for brevity, See LICENCE.TXT
set -eu
cd "$(dirname "$0")/.."
P=${ICC_PIPES:-../ICC-Pipes}/.claude/skills/icc-pipes/scripts
F=${ICC_FRAMES:-../ICC-Frames}/.claude/skills/icc-frames/scripts
B=.claude/skills/icc-bridge/scripts
a=$("$P/create" 6); b=$("$P/create" 6)
trap '"$P/remove" "$a" 2>/dev/null || :; "$P/remove" "$b" 2>/dev/null || :
  rm -f in out text' EXIT
head -c 150000 /dev/urandom > in
"$F/write" "$a" 0 < in
timeout 5 "$B/out" "$a" 1 > text
base64 in | cmp - text
LC_ALL=C grep -q '[^A-Za-z0-9+/=]' text && exit 1
"$B/in" "$b" 0 < text
timeout 5 "$F/read" "$b" 1 > out; cmp in out
"$F/write" "$b" 1 < in
timeout 5 "$B/out" "$b" 0 > text
"$B/in" "$a" 1 < text
timeout 5 "$F/read" "$a" 0 > out; cmp in out
: | "$B/in" "$a" 0
[ -z "$(timeout 5 "$B/out" "$a" 1)" ]
echo 'not the alphabet' | "$B/in" "$a" 0 2>/dev/null && exit 1
timeout 1 "$B/out" "$a" 1 > text 2>/dev/null && exit 1
[ ! -s text ]
"$P/remove" "$a"; "$P/remove" "$b"
rm -f in out text
trap - EXIT
echo ok
