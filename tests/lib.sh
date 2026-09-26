#!/bin/bash
##
# @file lib.sh
# @brief Prove the lib: every function it shares does what it says.
# @details Prove the lib: counts taken and refused in the words the pieces
#          use, osWho in front when set; SIDE refused and never worked
#          out; lanes counted from pipes made of bare fifos, which no
#          piece has to make, and refused when a pipe is not one, is odd,
#          differs, or has a file for a lane; a cleanup armed that INT,
#          TERM and HUP each run and exit 1, and that vDisarm clears; a
#          server that a hangup leaves standing and TERM ends; a piece's
#          directory made and printed at once; the cut-off check passing a
#          command that arms first and failing one that does not; and cut
#          off in a command it names, passing one that printed what it made
#          and failing one that printed nothing. Runs in a directory of its
#          own.
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
pIccLib=$(cd .claude/skills/icc-lib/scripts && pwd)
source "$pIccLib/lib"
pWork=
pidServer=
vArm '[ -n "$pidServer" ] && kill "$pidServer" 2>/dev/null || :
      cd /
      [ -n "$pWork" ] && rm -rf "$pWork" || :'
pWork=$(mktemp -d)
cd "$pWork"
# Counts, in the words every piece uses, and base ten whatever the zeros.
[ "$(nCount seats 010)" = 10 ]
[ "$(nCount seats 0)" = 0 ]
[ "$(nCount lanes x 2>&1)" = "lanes must be a whole number: x" ]
[ "$(nCount lanes '' 2>&1)" = "lanes must be a whole number: " ]
[ "$(nCount lanes -1 2>&1)" = "lanes must be a whole number: -1" ]
[ "$(nCount seats 99999999999999999999 2>&1)" = \
  "seats too big: 99999999999999999999" ]
[ "$(nCount seats 0000000000000000000000001)" = 1 ]
[ "$(osWho=write; nCount lanes x 2>&1)" = \
  "write: lanes must be a whole number: x" ]
[ "$(nLanesGiven 08)" = 8 ]
[ "$(nLanesGiven 3 2>&1)" = "lanes must be even: 3" ]
[ "$(nLanesGiven 0 2>&1)" = "lanes must be more than zero" ]
[ "$(nLanesGiven 99999999999999999998 2>&1)" = \
  "lanes too big: 99999999999999999998" ]
# SIDE is 0 or 1, and anything else is refused before it is worked out.
(vSide 0)
(vSide 1)
[ "$(vSide 2 2>&1)" = "SIDE is 0 or 1, not 2" ]
(vSide 'x[$(touch pwned)]') 2>/dev/null && exit 1
[ ! -e pwned ]
# Lanes from pipes of bare fifos: nLanesOf reads names, and opens nothing.
mkdir four also two odd filed stray
mkfifo four/0 four/1 four/2 four/3 also/0 also/1 also/2 also/3
mkfifo two/0 two/1 odd/0 odd/1 odd/2 filed/0 filed/1 filed/3
: > filed/2
mkfifo stray/0 stray/1
: > stray/2x
: > stray/$'2\n3'
[ "$(nLanesOf four)" = 4 ]
[ "$(nLanesOf four also)" = 4 ]
[ "$(nLanesOf stray)" = 2 ]
[ "$(nLanesOf four two 2>&1)" = "lanes differ: two" ]
[ "$(nLanesOf four /tmp 2>&1)" = "not a pipe: /tmp" ]
[ "$(nLanesOf odd 2>&1)" = "lanes must be even: odd" ]
[ "$(nLanesOf filed 2>&1)" = "not a pipe: filed" ]
[ "$(osWho=read; nLanesOf odd 2>&1)" = "read: lanes must be even: odd" ]
# A cleanup armed runs on every signal it names, and the exit is 1.
for osSignal in INT TERM HUP; do
  nStatus=0
  (
    vArm 'touch "ran-$osSignal"'
    kill -"$osSignal" "$BASHPID"
    sleep 5
  ) || nStatus=$?
  [ "$nStatus" -eq 1 ]
  [ -e "ran-$osSignal" ]
done
(
  vArm 'touch disarmed'
  vDisarm
)
[ ! -e disarmed ]
# A server shrugs off a hangup, and TERM, which remove sends, ends it.
(
  vServe
  exec sleep 30
) &
pidServer=$!
# Until vServe has run, a subshell has bash's default for HUP, which ends it,
# so the hangup waits until the server is sleep and nothing else.
while [ "$(cat "/proc/$pidServer/comm" 2>/dev/null)" != sleep ]; do
  kill -0 "$pidServer"
done
kill -HUP "$pidServer"
sleep 1
kill -0 "$pidServer"
kill -TERM "$pidServer"
nStatus=0
wait "$pidServer" || nStatus=$?
pidServer=
[ "$nStatus" -eq 143 ]
# The cut-off check passes a command that arms before it makes, and fails
# one that makes first.
printf '%s\n' '#!/bin/bash' "source '$pIccLib/lib'" 'pDir=' \
  "vArm '[ -n \"\$pDir\" ] && rmdir \"\$pDir\" || :'" \
  'pDir=$(mktemp -d)' 'sleep 30' > first
printf '%s\n' '#!/bin/bash' "source '$pIccLib/lib'" 'pDir=$(mktemp -d)' \
  "vArm '[ -n \"\$pDir\" ] && rmdir \"\$pDir\" || :'" 'sleep 30' > late
chmod +x first late
vCutOff "$pWork/first"
(vCutOff "$pWork/late") 2>/dev/null && exit 1
# pMakeDir makes a directory, sets pDir to it, and prints it.
pDir=
pMakeDir icc-lib > printed
rmdir "$pDir"
[ "$(cat printed)" = "$pDir" ]
# Cut off in a command it names, the check passes a command that printed the
# directory it made, and fails one that printed nothing, whatever it took.
printf '%s\n' '#!/bin/bash' "source '$pIccLib/lib'" 'pDir=' \
  "vArm '[ -n \"\$pDir\" ] && rmdir \"\$pDir\" || :'" \
  'pMakeDir icc-lib' 'echo x | tr x y' 'sleep 30' > printer
printf '%s\n' '#!/bin/bash' "source '$pIccLib/lib'" 'pDir=' \
  "vArm '[ -n \"\$pDir\" ] && rmdir \"\$pDir\" || :'" \
  'pDir=$(mktemp -d)' 'echo x | tr x y' 'sleep 30' > silent
chmod +x printer silent
vCutOffAt TERM tr "$pWork/printer"
(vCutOffAt TERM tr "$pWork/silent") 2>/dev/null && exit 1
cd /
rm -rf "$pWork"
vDisarm
echo ok
