#!/bin/bash
##
# @file lock.sh
# @brief Prove the lock: one holder per path, the rest refused at once.
# @details Prove the lock: bad arguments refused, by remove as by create; a
#          path locked, printed as readlink -m spells it, and listed; every
#          spelling of it refused, with nothing printed; another path, and
#          the directory above, locked beside it; forty creates for one
#          path at once, and exactly one of them the holder; remove giving
#          a lock back by any spelling, refusing a path not locked, and
#          leaving a directory with anything in it; and list skipping what
#          is not a lock. Locks paths in a directory of its own, and gives
#          back every lock it took.
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
# own behind. Every path the harness locks is in pWork, and pWork itself.
pWork=
pKept=
vArm 'if [ -n "$pWork" ]; then
        [ -z "$pKept" ] || rm -f "$pKept/kept"
        for osName in file other race kept; do
          "$pIccLock/remove" "$pWork/$osName" 2>/dev/null || :
        done
        "$pIccLock/remove" "$pWork" 2>/dev/null || :
      fi
      cd /
      [ -n "$pWork" ] && rm -rf "$pWork" || :'
pWork=$(mktemp -d)
cd "$pWork"
pWork=$(pwd -P)

##
# @fn pLockOf()
# @brief Print the directory a path is locked by.
# @details Written out apart from icc-lib's vLockOf, as what it is held to:
#          the sha256 of the path.
# @param $1 pPath - the path, as readlink -m spells it
# @stdout the directory
# @return 0
##
pLockOf() {
  local pPath=$1
  local osKey
  osKey=$(printf '%s' "$pPath" | sha256sum)
  echo "/tmp/icc-lock-${osKey%% *}"
}

# Refused, by remove as by create: no PATH, and a newline anywhere in it,
# even the one $( ) would drop.
vRefused "$pIccLock/create"
vRefused "$pIccLock/create" $'fi\nle'
vRefused "$pIccLock/create" $'file\n'
vRefused "$pIccLock/remove"
# Locked: create prints the path as readlink -m spells it, the lock is the
# directory named for it, and list says so.
[ "$("$pIccLock/create" file)" = "$pWork/file" ]
pLock=$(pLockOf "$pWork/file")
[ -d "$pLock" ]
"$pIccLock/list" | grep -qxF "$pLock"
# Held, every spelling of it is refused, with nothing printed, and mkdir
# names the lock in saying why.
mkdir sub
ln -s "$pWork" link
for osSpelling in file ./file sub/../file "$pWork//file" link/file; do
  nStatus=0
  pOut=$("$pIccLock/create" "$osSpelling" 2> said) || nStatus=$?
  [ "$nStatus" -eq 1 ]
  [ -z "$pOut" ]
  grep -qF "$pLock" said
done
# A spelling create refuses, remove refuses too, and gives back nothing.
vRefused "$pIccLock/remove" $'file\n'
[ -d "$pLock" ]
# Another path is a lock of its own, and so is the directory above.
"$pIccLock/remove" "$("$pIccLock/create" other)"
"$pIccLock/remove" "$("$pIccLock/create" "$pWork")"
# Forty creates for one path at once: exactly one holds it, and thirty-nine
# are refused.
for iRacer in $(seq 40); do
  (
    nStatus=0
    "$pIccLock/create" race > /dev/null 2>&1 || nStatus=$?
    echo "$nStatus" > "raced.$iRacer"
  ) &
done
wait
[ "$(cat raced.* | grep -cx 0)" -eq 1 ]
[ "$(cat raced.* | grep -cx 1)" -eq 39 ]
"$pIccLock/remove" race
# remove gives a lock back by any spelling, and then it can be taken again; a
# path not locked is refused.
"$pIccLock/remove" link/file
[ ! -e "$pLock" ]
vRefused "$pIccLock/remove" file
"$pIccLock/remove" "$("$pIccLock/create" file)"
# A lock that holds anything is left, and the anything with it.
"$pIccLock/create" kept > /dev/null
pKept=$(pLockOf "$pWork/kept")
: > "$pKept/kept"
vRefused "$pIccLock/remove" kept
[ -e "$pKept/kept" ]
rm -f "$pKept/kept"
pKept=
"$pIccLock/remove" kept
# list skips a directory that is not a lock.
pFake=$(mktemp -d /tmp/icc-lock-XXXXXXXX)
[ -z "$("$pIccLock/list" | grep -F "$pFake")" ]
rmdir "$pFake"
cd /
rm -rf "$pWork"
vDisarm
echo ok
