#!/bin/bash
# tests/bridge.sh
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
pIccPipes=$(cd .claude/skills/icc-pipes/scripts && pwd)
pIccFrames=$(cd .claude/skills/icc-frames/scripts && pwd)
pIccBridge=$(cd .claude/skills/icc-bridge/scripts && pwd)
pWork=$(mktemp -d); cd "$pWork"
pPipeA=$("$pIccPipes/create" 6); pPipeB=$("$pIccPipes/create" 6)
trap '"$pIccPipes/remove" "$pPipeA" 2>/dev/null || :; "$pIccPipes/remove" "$pPipeB" 2>/dev/null || :
  cd /; rm -rf "$pWork"' EXIT
head -c 150000 /dev/urandom > in
"$pIccFrames/write" "$pPipeA" 0 < in
timeout 5 "$pIccBridge/out" "$pPipeA" 1 > text
base64 in | cmp - text
LC_ALL=C grep -q '[^A-Za-z0-9+/=]' text && exit 1
"$pIccBridge/in" "$pPipeB" 0 < text
timeout 5 "$pIccFrames/read" "$pPipeB" 1 > out; cmp in out
"$pIccFrames/write" "$pPipeB" 1 < in
timeout 5 "$pIccBridge/out" "$pPipeB" 0 > text
"$pIccBridge/in" "$pPipeA" 1 < text
timeout 5 "$pIccFrames/read" "$pPipeA" 0 > out; cmp in out
: | "$pIccBridge/in" "$pPipeA" 0
[ -z "$(timeout 5 "$pIccBridge/out" "$pPipeA" 1)" ]
echo 'not the alphabet' | "$pIccBridge/in" "$pPipeA" 0 2>/dev/null && exit 1
timeout 1 "$pIccBridge/out" "$pPipeA" 1 > text 2>/dev/null && exit 1
[ ! -s text ]
"$pIccPipes/remove" "$pPipeA"; "$pIccPipes/remove" "$pPipeB"
cd /; rm -rf "$pWork"
trap - EXIT
echo ok
