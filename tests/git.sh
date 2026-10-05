#!/bin/bash
##
# @file git.sh
# @brief Prove the git wire: bytes sent to a new path, read back whole, and
#        a path once sent never sent again.
# @details Prove the git wire, on a bare repo of its own on local disk:
#          bad arguments refused, by send, read and list; a wire nobody
#          has sent on, empty to list and refused to read; bytes of every
#          value sent, and read back byte for byte, and the commit send
#          prints the branch's tip; a path once sent refused, its bytes
#          standing; the paths git refuses, refused; nothing sent as a
#          file of nothing; twelve sends at once on paths of their own all
#          landing, and twelve on one path landing once; list printing
#          every path; the caller's own repo, branch and index untouched,
#          and a remote's name from it not taken for a remote; and send,
#          read and list cut off, each taking its scratch repo with it.
#          git runs with no config but the harness's own, so what the
#          caller's config does is not what is proved.
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
pIccGit=$(cd .claude/skills/icc-git/scripts && pwd)
export GIT_CONFIG_GLOBAL=/dev/null
export GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=icc GIT_AUTHOR_EMAIL=icc@localhost
export GIT_COMMITTER_NAME=icc GIT_COMMITTER_EMAIL=icc@localhost
# Armed before anything is made, as icc-lib's vArm says. The remote, the
# caller's clone and every file the harness writes are in pWork.
pWork=
vArm 'cd /
      [ -n "$pWork" ] && rm -rf "$pWork" || :'
pWork=$(mktemp -d)
cd "$pWork"
pWork=$(pwd -P)
pRemote=$pWork/remote.git
git init -q --bare "$pRemote"
aBefore=(/tmp/icc-git-*)

# Refused: an argument missing, a REF git refuses, a PATH with a newline in
# it, and a remote that is not one.
vRefused "$pIccGit/send" < /dev/null
vRefused "$pIccGit/send" "$pRemote" < /dev/null
vRefused "$pIccGit/send" "$pRemote" wire < /dev/null
vRefused "$pIccGit/send" "$pRemote" 'a b' p < /dev/null
vRefused "$pIccGit/send" "$pRemote" -x p < /dev/null
vRefused "$pIccGit/send" "$pRemote" wire $'a\nb' < /dev/null
vRefused "$pIccGit/send" "$pWork/none.git" wire p < /dev/null
vRefused "$pIccGit/read" "$pRemote" wire
vRefused "$pIccGit/read" "$pRemote" 'a b' p
vRefused "$pIccGit/read" "$pWork/none.git" wire p
vRefused "$pIccGit/list" "$pRemote"
vRefused "$pIccGit/list" "$pRemote" 'a b'
vRefused "$pIccGit/list" "$pWork/none.git" wire
# A wire nobody has sent on: nothing to list, nothing to read.
[ -z "$("$pIccGit/list" "$pRemote" wire)" ]
vRefused "$pIccGit/read" "$pRemote" wire a/1
# Sent: bytes of every value, a NUL among them and no newline at the end,
# come back byte for byte, and the commit send prints is the branch's tip.
head -c 300000 /dev/urandom > bytes
osCommit=$("$pIccGit/send" "$pRemote" wire a/1 < bytes)
[ "$osCommit" = "$(git --git-dir="$pRemote" rev-parse refs/heads/wire)" ]
"$pIccGit/read" "$pRemote" wire a/1 > heard
cmp bytes heard
# A path once sent is refused, and its bytes stand. A path not on the wire
# is refused to read.
printf 'other' | vRefused "$pIccGit/send" "$pRemote" wire a/1
"$pIccGit/read" "$pRemote" wire a/1 | cmp - bytes
vRefused "$pIccGit/read" "$pRemote" wire a/2
# git refuses what it would not check out: up and out, from the root, into
# .git, an empty part; and a file where a directory is, and the reverse.
for osPath in ../x /x .git/x a//b a/1/b a; do
  vRefused "$pIccGit/send" "$pRemote" wire "$osPath" < /dev/null
done
# Nothing sent is a file of nothing.
"$pIccGit/send" "$pRemote" wire a/0 < /dev/null > /dev/null
[ "$("$pIccGit/read" "$pRemote" wire a/0 | wc -c)" -eq 0 ]
# Twelve sends at once, each on a path of its own: every one lands, and
# each reads back as it was sent. Once on the wire, and once on a wire
# nobody has sent on, where the first to land makes the branch under the
# others.
for osWire in wire fresh; do
  for iSender in $(seq 12); do
    (
      nStatus=0
      printf 'say %s' "$iSender" |
        "$pIccGit/send" "$pRemote" "$osWire" "s/$iSender" > /dev/null 2>&1 ||
        nStatus=$?
      echo "$nStatus" > "own.$osWire.$iSender"
    ) &
  done
  wait
  [ "$(cat own."$osWire".* | grep -cx 0)" -eq 12 ]
  for iSender in $(seq 12); do
    [ "$("$pIccGit/read" "$pRemote" "$osWire" "s/$iSender")" = \
      "say $iSender" ]
  done
done
# Twelve sends at once on one path: one lands, eleven are refused, and the
# path holds the bytes of the one that landed.
for iSender in $(seq 12); do
  (
    nStatus=0
    printf '%s' "$iSender" |
      "$pIccGit/send" "$pRemote" wire one > /dev/null 2>&1 || nStatus=$?
    echo "$nStatus" > "one.$iSender"
  ) &
done
wait
[ "$(cat one.* | grep -cx 0)" -eq 1 ]
[ "$(cat one.* | grep -cx 1)" -eq 11 ]
osLanded=$(grep -lx 0 one.*)
[ "$("$pIccGit/read" "$pRemote" wire one)" = "${osLanded#one.}" ]
# list prints every path, one a line, in git's order.
{
  echo a/0
  echo a/1
  echo one
  for iSender in $(seq 12); do
    echo "s/$iSender"
  done
} | LC_ALL=C sort > expected
"$pIccGit/list" "$pRemote" wire > listed
cmp expected listed
# The caller's own repo is not touched: its branch, its index and its tree
# are as they were, it has no FETCH_HEAD, an index the caller names is not
# written, and its remote's name is not taken for a remote.
git clone -q -b wire "$pRemote" clone
cd clone
git checkout -q -b mine
: > staged
git add staged
osBefore=$(git rev-parse HEAD; git branch --show-current; git status --short)
"$pIccGit/send" "$pRemote" wire c/1 < /dev/null > /dev/null
GIT_INDEX_FILE=$pWork/theirs "$pIccGit/send" "$pRemote" wire c/2 \
  < /dev/null > /dev/null
[ ! -e "$pWork/theirs" ]
vRefused "$pIccGit/send" origin wire c/3 < /dev/null
[ "$(git rev-parse HEAD; git branch --show-current; git status --short)" = \
  "$osBefore" ]
[ ! -e .git/FETCH_HEAD ]
cd "$pWork"
# Cut off, send, read and list each take their scratch repo with them.
vCutOff "$pIccGit/send" "$pRemote" wire cut/1
vCutOff "$pIccGit/read" "$pRemote" wire a/1
vCutOff "$pIccGit/list" "$pRemote" wire
# Nothing of theirs is left under /tmp.
[ "$(echo /tmp/icc-git-*)" = "${aBefore[*]}" ]
cd /
rm -rf "$pWork"
vDisarm
echo ok
