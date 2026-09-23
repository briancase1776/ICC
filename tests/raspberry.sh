#!/bin/bash
##
# @file raspberry.sh
# @brief Prove the raspberry: sixteen kinds, the lengths promised, no more.
# @details Prove the raspberry: blow a few hundred moot-sized ones and see
#          each is exactly one of the sixteen kinds, 5 to 40 of body and 1
#          to 15 of spittle, and every kind among them; size them from 4
#          bytes to a mebibyte and see each is exactly that long and still
#          a raspberry; refuse a size that is not one, in the words the
#          pieces use. Makes nothing, so there is nothing to clean up.
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
pIccRaspberry=$(cd .claude/skills/icc-raspberry/scripts && pwd)
# The sixteen kinds, LEAD:BODY, as SKILL.md lists them: what a raspberry is
# held to here, written out apart from the script that blows them.
aKinds=(P:T PF:F PB:B TH:P B:R BL:L BZ:Z PH:T
  FF:T TH:B PS:S PR:R PT:H BF:F TP:P PW:W)

##
# @fn osKindOf()
# @brief Print every kind a raspberry is, one a line: exactly one, if it
#        is a raspberry at all.
# @param $1 osRaspberry - the raspberry
# @param $2 osBodyRun - how long the body run may be, as a regex bound
# @param $3 osSpitRun - how long the spittle run may be, likewise
# @stdout each kind whose shape it has, LEAD:BODY
# @global aKinds - read, the sixteen kinds
# @return 0
##
osKindOf() {
  local osRaspberry=$1
  local osBodyRun=$2
  local osSpitRun=$3
  local osKind
  for osKind in "${aKinds[@]}"; do
    [[ $osRaspberry =~ ^${osKind%:*}(${osKind#*:})$osBodyRun~$osSpitRun$ ]] ||
      continue
    echo "$osKind"
  done
}

# Moot-sized: each exactly one kind, in the bounds, and every kind turning
# up. Three hundred draws leave any one kind out about once in sixteen
# million runs.
declare -A hSeen
for iDraw in $(seq 300); do
  osRaspberry=$("$pIccRaspberry/raspberry")
  mapfile -t aFound < <(osKindOf "$osRaspberry" '{5,40}' '{1,15}')
  [ "${#aFound[@]}" -eq 1 ] || {
    echo "not one kind: $osRaspberry" >&2
    exit 1
  }
  hSeen[${aFound[0]}]=1
done
[ "${#hSeen[@]}" -eq 16 ]
# Sized: exactly that long, and still one kind, down to the smallest a lead,
# a body and some spittle fit in.
for nBytes in 4 5 56 4091 4096 20000; do
  osRaspberry=$("$pIccRaspberry/raspberry" "$nBytes")
  [ "${#osRaspberry}" -eq "$nBytes" ]
  mapfile -t aFound < <(osKindOf "$osRaspberry" '+' '+')
  [ "${#aFound[@]}" -eq 1 ]
done
[ "$("$pIccRaspberry/raspberry" 1048576 | wc -c)" -eq 1048576 ]
[ "$("$pIccRaspberry/raspberry" 0004 | wc -c)" -eq 4 ]
# Refused in the words every piece uses, raspberry speaking.
[ "$("$pIccRaspberry/raspberry" 3 2>&1)" = \
  "raspberry: BYTES must be 4 or more: 3" ]
[ "$("$pIccRaspberry/raspberry" x 2>&1)" = \
  "raspberry: BYTES must be a whole number: x" ]
[ "$("$pIccRaspberry/raspberry" -1 2>&1)" = \
  "raspberry: BYTES must be a whole number: -1" ]
[ "$("$pIccRaspberry/raspberry" 99999999999999999999 2>&1)" = \
  "raspberry: BYTES too big: 99999999999999999999" ]
echo ok
