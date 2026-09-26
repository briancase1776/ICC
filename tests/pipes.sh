#!/bin/bash
##
# @file pipes.sh
# @brief Prove the pipe: make it, refuse bad counts, carry bytes, remove it.
# @details Prove the pipe: create it, refuse a bad lane count, hand bytes
#          from one process to another and back again on every pair,
#          remove it. A create that cannot finish is made to fail four
#          times: before its first fifo, after its last, on a hangup while
#          it waits on its first, and on a signal just after it makes its
#          directory. Each has printed its directory the moment it made
#          it, and that one is checked gone; nothing else in /tmp is
#          looked at.
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
cd "$(dirname "$0")/../.claude/skills/icc-pipes"
source ../icc-lib/scripts/lib
# Armed before anything is made, as icc-lib's vArm says: the one cleanup takes
# whatever is named, so a check that fails leaves nothing of the harness's
# own behind.
pFake=
pFakeBin=
pDir=
vArm '[ -n "$pDir" ] && scripts/remove "$pDir" 2>/dev/null || :
      [ -n "$pFakeBin" ] && rm -rf "$pFakeBin" || :
      [ -n "$pFake" ] && rm -rf "$pFake" || :'
scripts/create 3 2>/dev/null && exit 1
scripts/create 09 2>/dev/null && exit 1
# remove refuses a directory outside /tmp/icc-pipes-*, and leaves its fifos.
pFake=$(mktemp -d)
mkfifo "$pFake/0"
scripts/remove "$pFake" 2>/dev/null && exit 1
[ -p "$pFake/0" ]
rm -rf "$pFake"
# A create that cannot finish leaves nothing behind: the directory it printed
# the moment it made it is gone. Before its first fifo, and after its last,
# with too few descriptors to hold them.
pFakeBin=$(mktemp -d)
printf '#!/bin/bash\nexit 1\n' > "$pFakeBin/mkfifo"
chmod +x "$pFakeBin/mkfifo"
pMade=$(PATH=$pFakeBin:$PATH scripts/create 2 2>/dev/null) && exit 1
[ -n "$pMade" ] && [ ! -e "$pMade" ]
pMade=$(
  ulimit -n 30
  scripts/create 40 2>/dev/null
) && exit 1
[ -n "$pMade" ] && [ ! -e "$pMade" ]
rm -rf "$pFakeBin"
# A hangup is a create that cannot finish too, and exits 1 as a TERM does:
# stalled in mkfifo, with its directory made.
vCutOffAt HUP mkfifo scripts/create 2
# Cut off just after its directory is made, a create takes it with it.
vCutOff scripts/create 2
pDir=$(scripts/create 4)
scripts/list | grep -qx "$pDir up"
# The hold is a server, and a hangup is not its business: it is still up
# after one. TERM, which remove sends, is what ends it.
kill -HUP "$(cat "$pDir/pid")"
sleep 1
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
vDisarm
echo ok
