#!/bin/bash
# tests/run.sh
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
t=$(mktemp -d); printf '#!/bin/sh\nexit 1\n' > "$t/mkfifo"; chmod +x "$t/mkfifo"
was=$(ls -d /tmp/icc-pipes-*/ 2>/dev/null || :)
PATH=$t:$PATH scripts/create 2 2>/dev/null && exit 1
( ulimit -n 30; scripts/create 40 2>/dev/null ) && exit 1
for x in $(ls -d /tmp/icc-pipes-*/ 2>/dev/null || :); do
  printf '%s\n' "$was" | grep -qxF "$x" || [ -n "$(ls -A "$x")" ]
done
rm -rf "$t"
d=$(scripts/create 4)
trap 'scripts/remove "$d" 2>/dev/null || :' EXIT
scripts/list | grep -qx "$d up"
# The other side is a child of this shell: it reads the even lanes and
# answers on their odd partners, so nothing is read at the end that wrote
# it, and every lane carries.
( for l in 0 2; do
    IFS= read -r -t 5 m < "$d/$l"
    printf '%s back\n' "$m" > "$d/$((l + 1))"
  done ) &
# The token is made after the child is forked, so the child has no copy of
# it and cannot answer with it unless the even lane carried it across.
tok=$RANDOM-$RANDOM
for l in 0 2; do printf '%s %s\n' "$tok" "$l" > "$d/$l"; done
for l in 0 2; do
  IFS= read -r -t 5 r < "$d/$((l + 1))"
  [ "$r" = "$tok $l back" ]
done
wait
# The read SKILL.md teaches, from the end that did not write it: it gets the
# bytes and still exits 124, because the hold leaves no EOF to end it early.
# Only $( ) discarding that status keeps this line from ending the harness.
( printf 'bound\n' > "$d/1" ) &
r=0; out=$(timeout 1 cat "$d/1") || r=$?
[ "$out" = bound ]
[ "$r" -eq 124 ]
wait
scripts/remove "$d"
[ ! -d "$d" ]
trap - EXIT
echo ok
