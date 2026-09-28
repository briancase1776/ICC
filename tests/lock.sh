#!/bin/bash
##
# @file lock.sh
# @brief Prove the lock: one holder per path, the rest told at once.
# @details Prove the lock: bad arguments refused; a path locked, recorded
#          and listed; every spelling of it told held, with nothing made;
#          another path locked beside it; forty creates for one path at
#          once, and exactly one of them the holder; remove giving a lock
#          back by any spelling, refusing a path not locked, and leaving a
#          look-alike in place; and list skipping what is not a lock.
#          Locks paths in a directory of its own, and gives back every lock
#          it took.
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
pIccLock=$(cd .claude/skills/icc-lock/scripts && pwd)
# Armed before anything is made, as icc-lib's vArm says: the one cleanup takes
# whatever is named, so a check that fails leaves nothing of the harness's
# own behind.
pWork=
pFake=
vArm 'if [ -n "$pWork" ]; then
        for osName in file other race kept; do
          "$pIccLock/remove" "$pWork/$osName" 2>/dev/null || :
        done
      fi
      [ -n "$pFake" ] && rm -rf "$pFake" || :
      cd /
      [ -n "$pWork" ] && rm -rf "$pWork" || :'
pWork=$(mktemp -d)
cd "$pWork"
pWork=$(pwd -P)

##
# @fn vRefused()
# @brief Run a command that must be refused, and stop here if it is not.
# @details set -e is ignored for a pipeline that begins with !, so `! cmd`
#          states a refusal without ever being able to fail the harness.
#          vRefused() runs the command and stops here if it succeeds.
# @param $1... aCommand - the command and its arguments
# @stderr "not refused" and the command, when it was not; the command's
#         own stderr goes nowhere
# @return 0 the command was refused; it exits 1 instead when it was not
##
vRefused() {
  local aCommand=("$@")
  if "${aCommand[@]}" 2>/dev/null; then
    echo "not refused: ${aCommand[*]}" >&2
    exit 1
  fi
}

# Refused: no PATH, and a newline anywhere in it, even the one $( ) would
# drop.
vRefused "$pIccLock/create"
vRefused "$pIccLock/create" $'fi\nle'
vRefused "$pIccLock/create" $'file\n'
vRefused "$pIccLock/remove"
# Locked: the directory is named for the path as readlink -m spells it, holds
# it as a line, and list says so.
pLock=$("$pIccLock/create" file)
osKey=$(printf '%s' "$pWork/file" | sha256sum)
[ "$pLock" = "/tmp/icc-lock-${osKey%% *}" ]
[ "$(cat "$pLock/lock")" = "$pWork/file" ]
"$pIccLock/list" | grep -qxF "$pLock $pWork/file"
# Held, every spelling of it is told so at once, with 2, and nothing is
# made: the lock is as it was.
mkdir sub
ln -s "$pWork" link
for osSpelling in file ./file sub/../file "$pWork//file" link/file; do
  nStatus=0
  pOut=$("$pIccLock/create" "$osSpelling" 2> said) || nStatus=$?
  [ "$nStatus" -eq 2 ]
  [ -z "$pOut" ]
  [ "$(cat said)" = "held: $pWork/file" ]
done
[ "$(cat "$pLock/lock")" = "$pWork/file" ]
# Another path is a lock of its own, and so is the directory above.
"$pIccLock/create" other > /dev/null
"$pIccLock/create" "$pWork" > /dev/null
"$pIccLock/remove" other
"$pIccLock/remove" "$pWork"
# Forty creates for one path at once: exactly one holds it, and thirty-nine
# are told it is held.
for iRacer in $(seq 40); do
  (
    nStatus=0
    "$pIccLock/create" race > /dev/null 2>&1 || nStatus=$?
    echo "$nStatus" > "raced.$iRacer"
  ) &
done
wait
[ "$(cat raced.* | grep -cx 0)" -eq 1 ]
[ "$(cat raced.* | grep -cx 2)" -eq 39 ]
"$pIccLock/remove" race
# remove gives a lock back by any spelling, and then it can be taken again;
# a path not locked is refused.
"$pIccLock/remove" link/file
[ ! -e "$pLock" ]
[ "$("$pIccLock/remove" file 2>&1)" = "not locked: $pWork/file" ]
vRefused "$pIccLock/remove" file
[ "$("$pIccLock/create" file)" = "$pLock" ]
"$pIccLock/remove" file
# A lock that holds something create did not make is left in place, and the
# something with it.
pFake=$("$pIccLock/create" kept)
: > "$pFake/kept"
vRefused "$pIccLock/remove" kept
[ -e "$pFake/kept" ]
rm -f "$pFake/kept"
"$pIccLock/remove" kept
pFake=
# list skips a directory that is not a lock.
pFake=$(mktemp -d /tmp/icc-lock-XXXXXXXX)
[ -z "$("$pIccLock/list" | grep -F "$pFake")" ]
rmdir "$pFake"
pFake=
cd /
rm -rf "$pWork"
vDisarm
echo ok
