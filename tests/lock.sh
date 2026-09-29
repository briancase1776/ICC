#!/bin/bash
##
# @file lock.sh
# @brief Prove the lock: one holder per path, the rest told at once.
# @details Prove the lock: bad arguments refused; a path locked, printed
#          as remove takes it, recorded and listed, a space at its end and
#          all; every spelling of it told held, with nothing made, and a
#          spelling create refuses refused by remove too; another path
#          locked beside it; forty creates for one path at once, and
#          exactly one of them the holder; a lock given back between a
#          failed mkdir and the look after it taken on the second try; a
#          lock cut off before it said its path listed with -, held, and
#          given back by its path; remove giving a lock back by any spelling,
#          refusing a path not locked, saying so when another remove gave
#          it back first, and leaving a look-alike whole. Locks paths in a
#          directory of its own, and gives back every lock it took.
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
        for osName in file other race retry dead gone kept "sp "; do
          "$pIccLock/remove" "$pWork/$osName" 2>/dev/null || :
        done
        "$pIccLock/remove" "$pWork" 2>/dev/null || :
      fi
      cd /
      [ -n "$pWork" ] && rm -rf "$pWork" || :'
pWork=$(mktemp -d)
cd "$pWork"
pWork=$(pwd -P)
mkdir stub

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

##
# @fn vStub()
# @brief Stand a script in for a command, first on PATH, for one call.
# @details The stand-in takes itself away first, with the real rm, so any
#          later call is the real command. The real one and not whatever is
#          first on PATH: a stand-in for rm would call itself, forever.
# @param $1 osCommand - the command stood in for: mkdir, rm
# @param $2... aLines - the script's lines after that
# @return 0
##
vStub() {
  local osCommand=$1
  shift
  printf '%s\n' '#!/bin/bash' 'command -p rm -- "$0"' "$@" > "stub/$osCommand"
  chmod +x "stub/$osCommand"
}

# Refused: no PATH, and a newline anywhere in it, even the one $( ) would
# drop.
vRefused "$pIccLock/create"
vRefused "$pIccLock/create" $'fi\nle'
vRefused "$pIccLock/create" $'file\n'
vRefused "$pIccLock/remove"
# Locked: create prints the path as readlink -m spells it, which is what
# remove takes; the directory is named for it and holds it as a line; and
# list says so.
[ "$("$pIccLock/create" file)" = "$pWork/file" ]
pLock=$(pLockOf "$pWork/file")
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
# A spelling create refuses, remove refuses too, and gives back nothing.
vRefused "$pIccLock/remove" $'file\n'
[ -e "$pLock/lock" ]
# Another path is a lock of its own, and so is the directory above; and a
# path with a space at its end is listed with it.
"$pIccLock/remove" "$("$pIccLock/create" other)"
"$pIccLock/remove" "$("$pIccLock/create" "$pWork")"
"$pIccLock/create" "sp " > /dev/null
"$pIccLock/list" | grep -qxF "$(pLockOf "$pWork/sp ") $pWork/sp "
"$pIccLock/remove" "sp "
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
# A lock given back between a mkdir that failed on it and the look after is
# free, not held: create tries once more and takes it. The stand-in fails
# the first mkdir and gives the lock back, as its holder would, then stands
# aside.
"$pIccLock/create" retry > /dev/null
vStub mkdir 'command -p rm -f -- "$2/lock"' 'command -p rmdir -- "$2"' \
  'exit 1'
[ "$(PATH=$pWork/stub:$PATH "$pIccLock/create" retry)" = "$pWork/retry" ]
"$pIccLock/remove" retry
# A create cut off between mkdir and the lock file leaves a lock that does
# not say its path, as any holder that dies leaves its lock: list shows it
# with -, it is held, and remove gives it back by its path.
pDead=$(pLockOf "$pWork/dead")
mkdir "$pDead"
"$pIccLock/list" | grep -qxF "$pDead -"
nStatus=0
"$pIccLock/create" dead 2>/dev/null || nStatus=$?
[ "$nStatus" -eq 2 ]
"$pIccLock/remove" dead
[ ! -e "$pDead" ]
# remove gives a lock back by any spelling, and then it can be taken again; a
# path not locked is refused.
"$pIccLock/remove" link/file
[ ! -e "$pLock" ]
[ "$("$pIccLock/remove" file 2>&1)" = "not locked: $pWork/file" ]
vRefused "$pIccLock/remove" file
"$pIccLock/remove" "$("$pIccLock/create" file)"
# A lock another remove gave back while this one looked is not locked, not
# left in place: the stand-in for rm takes the whole lock away first.
"$pIccLock/create" gone > /dev/null
vStub rm 'command -p rm "$@"' 'command -p rmdir -- "${2%/*}"'
[ "$(PATH=$pWork/stub:$PATH "$pIccLock/remove" gone 2>&1)" = \
  "not locked: $pWork/gone" ]
[ ! -e "$(pLockOf "$pWork/gone")" ]
# A lock that holds something create did not make is left in place, whole:
# the something, and the lock file with its path.
"$pIccLock/create" kept > /dev/null
pKept=$(pLockOf "$pWork/kept")
: > "$pKept/kept"
vRefused "$pIccLock/remove" kept
[ -e "$pKept/kept" ]
[ "$(cat "$pKept/lock")" = "$pWork/kept" ]
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
