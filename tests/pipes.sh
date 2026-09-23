#!/bin/bash
# tests/pipes.sh
# Prove the pipe: create it, refuse a bad lane count, hand bytes from one
# process to another and back again on every pair, remove it.
# Copyright (c) 2026 Brian Case. All rights reserved.
# AI contributor: Claude (Anthropic)
#
# MIT License text omitted for brevity, See LICENCE.TXT
set -eu
cd "$(dirname "$0")/../.claude/skills/icc-pipes"
scripts/create 3 2>/dev/null && exit 1
scripts/create 09 2>/dev/null && exit 1
# a create that cannot finish leaves nothing behind. Counted, not emptied:
# other pipes may be up beside this one.
pFakeBin=$(mktemp -d); printf '#!/bin/sh\nexit 1\n' > "$pFakeBin/mkfifo"; chmod +x "$pFakeBin/mkfifo"
osBefore=$(ls -d /tmp/icc-pipes-*/ 2>/dev/null || :)
PATH=$pFakeBin:$PATH scripts/create 2 2>/dev/null && exit 1
( ulimit -n 30; scripts/create 40 2>/dev/null ) && exit 1
for pPipe in $(ls -d /tmp/icc-pipes-*/ 2>/dev/null || :); do
  printf '%s\n' "$osBefore" | grep -qxF "$pPipe" || [ -n "$(ls -A "$pPipe")" ]
done
rm -rf "$pFakeBin"
pDir=$(scripts/create 4)
trap 'scripts/remove "$pDir" 2>/dev/null || :' EXIT
scripts/list | grep -qx "$pDir up"
# The other side is a child of this shell: it reads the even lanes and
# answers on their odd partners, so nothing is read at the end that wrote
# it, and every lane carries.
( for iLane in 0 2; do
    IFS= read -r -t 5 osLine < "$pDir/$iLane"
    printf '%s back\n' "$osLine" > "$pDir/$((iLane + 1))"
  done ) &
# The token is made after the child is forked, so the child has no copy of
# it and cannot answer with it unless the even lane carried it across.
osToken=$RANDOM-$RANDOM
for iLane in 0 2; do printf '%s %s\n' "$osToken" "$iLane" > "$pDir/$iLane"; done
for iLane in 0 2; do
  IFS= read -r -t 5 osReply < "$pDir/$((iLane + 1))"
  [ "$osReply" = "$osToken $iLane back" ]
done
wait
# The read SKILL.md teaches, from the end that did not write it: it gets the
# bytes and still exits 124, because the hold leaves no EOF to end it early.
# Only $( ) discarding that status keeps this line from ending the harness.
( printf 'bound\n' > "$pDir/1" ) &
nStatus=0; osOut=$(timeout 1 cat "$pDir/1") || nStatus=$?
[ "$osOut" = bound ]
[ "$nStatus" -eq 124 ]
wait
scripts/remove "$pDir"
[ ! -d "$pDir" ]
trap - EXIT
echo ok
