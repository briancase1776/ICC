#!/bin/bash
##
# @file pipes.sh
# @brief Prove the pipe: make it, refuse bad counts, carry bytes, remove it.
# @details Prove the pipe: create it, refuse a bad lane count, hand bytes
#          from one process to another and back again on every pair,
#          remove it. A create that cannot finish is made to fail three
#          times: before its first fifo, after its last, and on a hangup
#          while it waits on its first. What is left in /tmp is checked
#          only for new directories that are empty, since one with lanes
#          in it may be anyone's pipe, so a leak from the second failure
#          would pass.
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
# What is in /tmp is counted from globs, never from ls, and a glob that
# matches nothing is no paths at all, not the pattern itself.
shopt -s nullglob
cd "$(dirname "$0")/../.claude/skills/icc-pipes"
scripts/create 3 2>/dev/null && exit 1
scripts/create 09 2>/dev/null && exit 1
# remove refuses a directory outside /tmp/icc-pipes-*, and leaves its fifos.
pFake=$(mktemp -d)
mkfifo "$pFake/0"
scripts/remove "$pFake" 2>/dev/null && exit 1
[ -p "$pFake/0" ]
rm -rf "$pFake"
# a create that cannot finish leaves nothing behind. Checked against what
# was there before, not by emptying /tmp: other pipes may be up beside this
# one, which is also why a new directory with lanes in it is let pass.
pFakeBin=$(mktemp -d)
printf '#!/bin/sh\nexit 1\n' > "$pFakeBin/mkfifo"
chmod +x "$pFakeBin/mkfifo"
aBefore=(/tmp/icc-pipes-*/)
PATH=$pFakeBin:$PATH scripts/create 2 2>/dev/null && exit 1
(
  ulimit -n 30
  scripts/create 40 2>/dev/null
) && exit 1
# A hangup is a create that cannot finish too, and exits 1 as a TERM does.
# This mkfifo stalls until it is killed, so the signal lands while create
# waits on it, with its directory made.
printf '#!/bin/bash\necho $$ > "${0%%/*}/stalled"\nexec sleep 30\n' \
  > "$pFakeBin/mkfifo"
PATH=$pFakeBin:$PATH scripts/create 2 >/dev/null 2>&1 &
pidCreate=$!
while [ ! -s "$pFakeBin/stalled" ]; do
  kill -0 $pidCreate 2>/dev/null || break
done
kill -HUP $pidCreate
kill "$(cat "$pFakeBin/stalled")"
nStatus=0
wait $pidCreate || nStatus=$?
[ "$nStatus" -eq 1 ]
for pPipe in /tmp/icc-pipes-*/; do
  printf '%s\n' "${aBefore[@]}" | grep -qxF "$pPipe" ||
    [ -n "$(find "$pPipe" -mindepth 1 -print -quit)" ]
done
rm -rf "$pFakeBin"
pDir=$(scripts/create 4)
trap 'scripts/remove "$pDir" 2>/dev/null || :' EXIT
scripts/list | grep -qx "$pDir up"
# The other side is a child of this shell: it reads the even lanes and
# answers on their odd partners, so nothing is read at the end that wrote
# it, and every lane carries.
(
  for iLane in 0 2; do
    IFS= read -r -t 5 osLine < "$pDir/$iLane"
    printf '%s back\n' "$osLine" > "$pDir/$((iLane + 1))"
  done
) &
# The token is made after the child is forked, so the child has no copy of
# it and cannot answer with it unless the even lane carried it across.
osToken=$RANDOM-$RANDOM
for iLane in 0 2; do
  printf '%s %s\n' "$osToken" "$iLane" > "$pDir/$iLane"
done
for iLane in 0 2; do
  IFS= read -r -t 5 osReply < "$pDir/$((iLane + 1))"
  [ "$osReply" = "$osToken $iLane back" ]
done
wait
# The read SKILL.md teaches, from the end that did not write it: it gets the
# bytes and still exits 124, because the hold leaves no EOF to end it early.
# Only $( ) discarding that status keeps this line from ending the harness.
( printf 'bound\n' > "$pDir/1" ) &
nStatus=0
osOut=$(timeout 1 cat "$pDir/1") || nStatus=$?
[ "$osOut" = bound ]
[ "$nStatus" -eq 124 ]
wait
scripts/remove "$pDir"
[ ! -d "$pDir" ]
trap - EXIT
echo ok
