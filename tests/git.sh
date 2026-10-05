#!/bin/bash
##
# @file git.sh
# @brief Prove the git wire: bytes sent to a path, read back whole, and a
#        path once sent never changed.
# @details Prove the git wire, on bare repos of its own on local disk: bad
#          arguments refused, by send, read and list, and a closed stdin
#          refused by send; a wire nobody has sent on, empty to list and
#          refused to read; bytes of every value, and text under autocrlf,
#          sent and read back byte for byte; a path that holds the bytes
#          sent already, sent again with nothing to do; other bytes, a
#          directory and the paths git refuses, refused; a push that landed
#          with its report lost, landed; forty sends at once on paths of
#          their own, on a wire nobody has sent on, all landing, and twelve
#          on one path landing once; a branch made between a failed fetch
#          and the ls-remote after it, fetched; a remote that refuses every
#          push, refused in git's words, and one that holds its branch
#          locked a while, landed on; list printing every path, odd
#          bytes and all; the caller's own repo, branch and index
#          untouched, and a remote's name from it not taken for a remote;
#          send, read and list cut off, at their first mktemp and while a
#          push waits, each taking its scratch repo with it; and every
#          scratch repo they made, gone. git runs with no config but the
#          harness's own, so what a caller's config does is not proved.
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
pGit=$(command -v git)
export GIT_CONFIG_GLOBAL=/dev/null
export GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=icc GIT_AUTHOR_EMAIL=icc@localhost
export GIT_COMMITTER_NAME=icc GIT_COMMITTER_EMAIL=icc@localhost
# Armed before anything is made, as icc-lib's vArm says. The remotes, the
# caller's clone and every file the harness writes are in pWork.
pWork=
pidSend=
vArm '[ -n "$pidSend" ] && kill "$pidSend" 2>/dev/null || :
      cd /
      [ -n "$pWork" ] && rm -rf "$pWork" || :'
pWork=$(mktemp -d)
cd "$pWork"
pWork=$(pwd -P)
pRemote=$pWork/remote.git
git init -q --bare "$pRemote"
# A stand-in for mktemp, first on PATH, logs every scratch repo the
# scripts make, so the harness checks its own and looks at nothing else in
# /tmp.
mkdir bin
printf '%s\n' '#!/bin/bash' 'pMade=$(command -p mktemp "$@") || exit 1' \
  "echo \"\$pMade\" >> '$pWork/made'" 'echo "$pMade"' > bin/mktemp
chmod +x bin/mktemp
PATH=$pWork/bin:$PATH

##
# @fn pGitStandIn()
# @brief Make a stand-in for git that runs osDo first when git is called to
#        osVerb, and print the directory to put first on PATH.
# @details The stand-in is git for every other call. In osDo, $pGit is the
#          real git and "$@" is what git was called with.
# @param $1 osName - the directory's name, in pWork
# @param $2 osVerb - the git command it watches: push, ls-remote
# @param $3 osDo - bash, run first when git is called so
# @stdout the directory
# @return 0
##
pGitStandIn() {
  local osName=$1
  local osVerb=$2
  local osDo=$3
  mkdir "$pWork/$osName"
  printf '%s\n' '#!/bin/bash' "pGit='$pGit'" 'case " $* " in' \
    "  *' $osVerb '*)" "    $osDo" '    ;;' 'esac' 'exec "$pGit" "$@"' \
    > "$pWork/$osName/git"
  chmod +x "$pWork/$osName/git"
  echo "$pWork/$osName"
}

# Refused: an argument missing, a REF git refuses, a PATH with a newline in
# it, a remote that is not one, and a closed stdin.
vRefused "$pIccGit/send" < /dev/null
vRefused "$pIccGit/send" "$pRemote" < /dev/null
vRefused "$pIccGit/send" "$pRemote" wire < /dev/null
for osRef in 'a b' -x '@{-1}' HEAD; do
  vRefused "$pIccGit/send" "$pRemote" "$osRef" p < /dev/null
  vRefused "$pIccGit/read" "$pRemote" "$osRef" p
  vRefused "$pIccGit/list" "$pRemote" "$osRef"
done
vRefused "$pIccGit/send" "$pRemote" wire $'a\nb' < /dev/null
vRefused "$pIccGit/send" "$pWork/none.git" wire p < /dev/null
vRefused "$pIccGit/read" "$pRemote" wire
vRefused "$pIccGit/read" "$pWork/none.git" wire p
vRefused "$pIccGit/list" "$pRemote"
vRefused "$pIccGit/list" "$pWork/none.git" wire
# A closed stdin is refused at once, and said so.
nStatus=0
timeout 10 "$pIccGit/send" "$pRemote" wire p <&- 2> said || nStatus=$?
[ "$nStatus" -eq 1 ]
grep -qF 'stdin is closed' said
# A wire nobody has sent on: nothing to list, and that is no refusal;
# nothing to read.
"$pIccGit/list" "$pRemote" wire > listed
[ ! -s listed ]
vRefused "$pIccGit/read" "$pRemote" wire a/1
# Sent: bytes of every value, a NUL among them and no newline at the end,
# come back byte for byte, and send prints nothing.
head -c 300000 /dev/urandom > bytes
[ -z "$("$pIccGit/send" "$pRemote" wire a/1 < bytes)" ]
"$pIccGit/read" "$pRemote" wire a/1 > heard
cmp bytes heard
# Text comes back as it went, line ends and all, under a config that would
# change them on a checkout.
printf 'one\r\ntwo\nthree' > text
GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=core.autocrlf GIT_CONFIG_VALUE_0=true \
  "$pIccGit/send" "$pRemote" wire t/1 < text
GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=core.autocrlf GIT_CONFIG_VALUE_0=true \
  "$pIccGit/read" "$pRemote" wire t/1 | cmp - text
# A path that holds the bytes sent already has nothing to do. Other bytes
# to it are refused, and its bytes stand. A path not on the wire, and a
# directory, are refused to read.
"$pIccGit/send" "$pRemote" wire a/1 < bytes
printf 'other' | vRefused "$pIccGit/send" "$pRemote" wire a/1
"$pIccGit/read" "$pRemote" wire a/1 | cmp - bytes
vRefused "$pIccGit/read" "$pRemote" wire a/2
vRefused "$pIccGit/read" "$pRemote" wire a
# Refused by send: a directory on the wire. Refused by git: up and out,
# from the root, into .git, an empty part, and a path under a file.
for osPath in a ../x /x .git/x a//b a/1/b; do
  vRefused "$pIccGit/send" "$pRemote" wire "$osPath" < /dev/null
done
# Nothing sent is a file of nothing.
"$pIccGit/send" "$pRemote" wire a/0 < /dev/null
[ "$("$pIccGit/read" "$pRemote" wire a/0 | wc -c)" -eq 0 ]
# A push that landed while its report was lost: send looks, finds its
# bytes at PATH, and has landed.
pLost=$(pGitStandIn lost push '"$pGit" "$@"; exit 1')
printf 'lost' | PATH=$pLost:$PATH "$pIccGit/send" "$pRemote" wire l/1
[ "$("$pIccGit/read" "$pRemote" wire l/1)" = lost ]
# Forty sends at once, each on a path of its own, on a wire nobody has
# sent on: the first to land makes the branch under the others, and every
# one lands and reads back as it was sent.
for iSender in $(seq 40); do
  (
    nStatus=0
    printf 'say %s' "$iSender" |
      "$pIccGit/send" "$pRemote" fresh "s/$iSender" 2> /dev/null ||
      nStatus=$?
    echo "$nStatus" > "own.$iSender"
  ) &
done
wait
[ "$(cat own.* | grep -cx 0)" -eq 40 ]
for iSender in $(seq 40); do
  [ "$("$pIccGit/read" "$pRemote" fresh "s/$iSender")" = "say $iSender" ]
done
[ "$("$pIccGit/list" "$pRemote" fresh | wc -l)" -eq 40 ]
# Twelve sends at once on one path, each with bytes of its own: one lands,
# eleven are refused, and the path holds the bytes of the one that landed.
for iSender in $(seq 12); do
  (
    nStatus=0
    printf '%s' "$iSender" |
      "$pIccGit/send" "$pRemote" wire one 2> /dev/null || nStatus=$?
    echo "$nStatus" > "one.$iSender"
  ) &
done
wait
[ "$(cat one.* | grep -cx 0)" -eq 1 ]
[ "$(cat one.* | grep -cx 1)" -eq 11 ]
osLanded=$(grep -lx 0 one.*)
[ "$("$pIccGit/read" "$pRemote" wire one)" = "${osLanded#one.}" ]
# A branch made between a fetch that fails and the ls-remote after it is
# fetched once more, and found.
pRace=$(pGitStandIn race ls-remote "[ -e '$pWork/race.marked' ] ||
      { : > '$pWork/race.marked'; \"\$pGit\" --git-dir='$pRemote' update-ref \
refs/heads/race refs/heads/wire; }")
PATH=$pRace:$PATH "$pIccGit/read" "$pRemote" race l/1 > raced
[ "$(cat raced)" = lost ]
# A remote that holds its branch locked a while for each update, as a slow
# disk or a replicating server does: a send turned away while the branch
# has not moved yet looks again, and every send on a path of its own lands.
git init -q --bare slow.git
printf '%s\n' '#!/bin/bash' '[ "$1" != prepared ] || sleep 0.3' \
  > slow.git/hooks/reference-transaction
chmod +x slow.git/hooks/reference-transaction
for iSender in $(seq 6); do
  (
    nStatus=0
    printf 'slow %s' "$iSender" |
      "$pIccGit/send" "$pWork/slow.git" wire "s/$iSender" 2> /dev/null ||
      nStatus=$?
    echo "$nStatus" > "late.$iSender"
  ) &
done
wait
[ "$(cat late.* | grep -cx 0)" -eq 6 ]
# A remote that refuses every push: send looks again while the branch has
# not moved, then is refused, in git's words.
git init -q --bare refusing.git
printf '%s\n' '#!/bin/bash' 'exit 1' > refusing.git/hooks/pre-receive
chmod +x refusing.git/hooks/pre-receive
nStatus=0
timeout 60 "$pIccGit/send" "$pWork/refusing.git" wire p < /dev/null \
  2> said || nStatus=$?
[ "$nStatus" -eq 1 ]
grep -qF 'pre-receive hook declined' said
# list prints every path, one a line, in git's order, and a path with bytes
# git would quote is printed as it is, and reads back by that line.
osOdd=$'q\t"\xc3\xa9 x'
printf 'odd' | "$pIccGit/send" "$pRemote" wire "$osOdd"
{
  printf '%s\n' a/0 a/1 l/1 one t/1 "$osOdd"
} | LC_ALL=C sort > expected
"$pIccGit/list" "$pRemote" wire > listed
cmp expected listed
[ "$("$pIccGit/read" "$pRemote" wire "$(grep '^q' listed)")" = odd ]
# The caller's own repo is not touched: its branch, its index and its tree
# are as they were, it has no FETCH_HEAD, git's variables naming its index
# or objects are not written through, and its remote's name is not taken
# for a remote, nor its last branch for a REF.
git clone -q -b wire "$pRemote" clone
cd clone
git checkout -q -b mine
: > staged
git add staged
osBefore=$(git rev-parse HEAD; git branch --show-current; git status --short)
nObjects=$(find .git/objects -type f | wc -l)
"$pIccGit/send" "$pRemote" wire c/1 < /dev/null
GIT_INDEX_FILE=$pWork/theirs "$pIccGit/send" "$pRemote" wire c/2 < /dev/null
[ ! -e "$pWork/theirs" ]
printf 'kept' |
  GIT_OBJECT_DIRECTORY=$PWD/.git/objects "$pIccGit/send" "$pRemote" wire c/3
[ "$(find .git/objects -type f | wc -l)" -eq "$nObjects" ]
vRefused "$pIccGit/send" origin wire c/4 < /dev/null
vRefused "$pIccGit/list" "$pRemote" '@{-1}'
[ "$(git rev-parse HEAD; git branch --show-current; git status --short)" = \
  "$osBefore" ]
[ ! -e .git/FETCH_HEAD ]
cd "$pWork"
# Cut off, send, read and list each take their scratch repo with them: at
# their first mktemp, while it is still empty, and send while its push
# waits, with the scratch repo full.
vCutOff "$pIccGit/send" "$pRemote" wire cut/1
vCutOff "$pIccGit/read" "$pRemote" wire a/1
vCutOff "$pIccGit/list" "$pRemote" wire
pHang=$(pGitStandIn hang push "echo \$\$ > '$pWork/stalled'; exec sleep 30")
PATH=$pHang:$PATH "$pIccGit/send" "$pRemote" wire cut/2 < bytes &
pidSend=$!
while [ ! -s stalled ]; do
  kill -0 "$pidSend"
done
kill -TERM "$pidSend"
kill "$(cat stalled)"
nStatus=0
wait "$pidSend" || nStatus=$?
pidSend=
[ "$nStatus" -eq 1 ]
vRefused "$pIccGit/read" "$pRemote" wire cut/2
# Every scratch repo the scripts made is gone.
while IFS= read -r pMade; do
  case $pMade in
    /tmp/icc-git-*)
      if [ -e "$pMade" ]; then
        echo "left behind: $pMade" >&2
        exit 1
      fi
      ;;
  esac
done < made
grep -q '^/tmp/icc-git-' made
cd /
rm -rf "$pWork"
vDisarm
echo ok
