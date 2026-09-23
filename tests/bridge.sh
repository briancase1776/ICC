#!/bin/bash
##
# @file bridge.sh
# @brief Prove the transcription: a payload goes out as text and back whole.
# @details Prove the transcription: get two pipes from Pipes, put a Frames
#          payload bigger than one lane holds on one, take it off as text,
#          see the text is the alphabet and nothing else, put it on the
#          other, read it back whole, compare bytes, both directions; an
#          empty payload; text that is not the alphabet puts nothing on
#          the wire, and a wire with nothing on it prints nothing; a copy
#          of the skills outside .claude still finds Frames; each end cut
#          off just after it makes its temp file takes it with it; remove
#          the pipes.
# @stdin nothing
# @stdout ok, once every check has passed
# @stderr whatever a failing check printed
# @exit 0 every check passed; otherwise the status of the first that
#       did not
#
# Copyright (c) 2026 Brian Case. All rights reserved.
# AI contributor: Claude (Anthropic)
#
# MIT Licence. See LICENCE.TXT
##
set -eu
cd "$(dirname "$0")/.."
source .claude/skills/icc-lib/scripts/lib
pIccPipes=$(cd .claude/skills/icc-pipes/scripts && pwd)
pIccFrames=$(cd .claude/skills/icc-frames/scripts && pwd)
pIccBridge=$(cd .claude/skills/icc-bridge/scripts && pwd)
# Armed before anything is made, as icc-lib's vArm says: the one cleanup takes
# whatever is named, so a check that fails leaves nothing of the harness's
# own behind.
pWork=
pPipeA=
pPipeB=
vArm 'for pPipe in $pPipeA $pPipeB; do
        "$pIccPipes/remove" "$pPipe" 2>/dev/null || rm -rf "$pPipe"
      done
      cd /
      [ -n "$pWork" ] && rm -rf "$pWork" || :'
pWork=$(mktemp -d)
cd "$pWork"
pPipeA=$("$pIccPipes/create" 6)
pPipeB=$("$pIccPipes/create" 6)
head -c 150000 /dev/urandom > in
"$pIccFrames/write" "$pPipeA" 0 < in
timeout 5 "$pIccBridge/out" "$pPipeA" 1 > text
base64 in | cmp - text
LC_ALL=C grep -q '[^A-Za-z0-9+/=]' text && exit 1
"$pIccBridge/in" "$pPipeB" 0 < text
timeout 5 "$pIccFrames/read" "$pPipeB" 1 > out
cmp in out
"$pIccFrames/write" "$pPipeB" 1 < in
timeout 5 "$pIccBridge/out" "$pPipeB" 0 > text
"$pIccBridge/in" "$pPipeA" 1 < text
timeout 5 "$pIccFrames/read" "$pPipeA" 0 > out
cmp in out
# Cut off just after it makes its temp file, each end takes it with it.
vCutOff "$pIccBridge/in" "$pPipeA" 0
vCutOff "$pIccBridge/out" "$pPipeA" 1
: | "$pIccBridge/in" "$pPipeA" 0
[ -z "$(timeout 5 "$pIccBridge/out" "$pPipeA" 1)" ]
echo 'not the alphabet' | "$pIccBridge/in" "$pPipeA" 0 2>/dev/null && exit 1
timeout 1 "$pIccBridge/out" "$pPipeA" 1 > text 2>/dev/null && exit 1
[ ! -s text ]
# Frames is found beside the bridge, wherever the skills sit: here, a copy of
# them in a directory that is not .claude/skills.
cp -r "$pIccBridge/../.." skills
"$pIccFrames/write" "$pPipeA" 0 < in
timeout 5 skills/icc-bridge/scripts/out "$pPipeA" 1 > text
skills/icc-bridge/scripts/in "$pPipeB" 0 < text
timeout 5 "$pIccFrames/read" "$pPipeB" 1 > out
cmp in out
"$pIccPipes/remove" "$pPipeA"
"$pIccPipes/remove" "$pPipeB"
cd /
rm -rf "$pWork"
vDisarm
echo ok
