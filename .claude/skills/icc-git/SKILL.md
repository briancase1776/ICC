---
name: icc-git
description: >-
  Send bytes to a path on a git branch, and read them back, from any
  session or machine that can reach the remote. A wire that keeps what it
  carries: one file per send, at a path new on the branch, never changed
  by a later send. What the bytes are, which paths are whose, and who is
  told to look, is the caller's business.
---

# icc-git

A wire is a branch on a git remote. Each send is one commit on the
branch's tip that adds one file, at a path that was not on the branch
before:

    REF          a branch on REMOTE, named by the caller
      A/1        a file one writer sent
      A/2        the same writer's next
      B/1        another writer's

Which paths are whose is agreed outside this skill. Writers that never
send the same path never stand in each other's way: every send lands,
in some order. Of sends to one path, one lands and the rest are
refused.

## Operations

    scripts/send REMOTE REF PATH   put stdin at PATH on REF, as one commit
                                   on REF's tip, push it, print the
                                   commit; refuse a PATH already there
    scripts/read REMOTE REF PATH   print PATH's bytes, as they are on REF
    scripts/list REMOTE REF        print every path on REF, one a line

REMOTE is what `git fetch` takes: a URL, or the path of a repo on this
machine. The name of a remote in some repo's config is not one. REF is
a branch name, and the first send makes it. PATH is a path inside the
branch, as git takes one: relative, with no `.` or `..` part, no `.git`,
and no newline.

    printf '%s' "$osSay" |
      .claude/skills/icc-git/scripts/send "$osRemote" moot-7 seat0/r1
    .claude/skills/icc-git/scripts/read "$osRemote" moot-7 seat0/r1

REMOTE, REF and PATH name the same bytes for as long as the branch
stands, so the three of them can be handed on as a pointer, in a
message or by hand. A wire is ended with git itself, by deleting the
branch: `git push REMOTE --delete REF`.

Each script works in a scratch repo of its own under /tmp, with an
index of its own and no checkout, and takes it away when it ends. The
caller's own repo, branch, index and working tree are not touched, and
the scripts need not be run from inside a repo at all.

The scripts source icc-lib's shared functions from beside this skill,
`../../icc-lib/scripts/lib` in the same skills directory, so icc-lib
has to be installed with it.

## Facts about the wire

These are properties of git. The skill adds two things: send refuses a
path already on the branch, and a send turned away pushes again.

- Kept. A read takes nothing off the wire. Every reader reads the same
  bytes, as often as it likes, and what was sent stays on the branch
  until someone rewrites it.
- Not changed by send. A second send to a path is refused, so a pointer
  stays true. git itself can still rewrite the branch, for anyone the
  remote lets push to it, and nothing here stops that.
- Bytes as sent. send stores stdin as git stores a blob read from stdin:
  no filter and no line-ending change. read prints the blob as stored.
  A NUL, or no newline at the end, comes back as it went.
- Order is the branch's. Each send is a commit on the tip it was built
  on, and that tip is the commit's parent: what was on the wire when
  the sender sent.
- Sends at once. The push is a fast-forward, so of several sends built
  on one tip, one lands and the rest are turned away. A send turned away
  fetches the new tip, builds on it and pushes again, for as long as the
  branch keeps moving. A push that fails while the branch has not moved
  is a fault, and send says why in git's words. Nothing is forced.
  Forty sends at once on paths of their own, on a remote on local disk,
  all land, ten runs in ten.
- A branch made under a send. The first sends to a branch race to make
  it. One makes it, and the rest build on it and land, as above.
- Nobody is woken. A send lands on the remote and stops there. Telling a
  reader to look is the caller's.
- Only the tip is fetched, `--depth=1`: no history, but every file on
  the tip, whole. Each call costs the wire's size, so a wire that keeps
  growing makes every call slower. A new branch starts from nothing.
- The commit is made as the caller's git config makes one: user.name,
  user.email, and a signature if signing is on. Its message is PATH.
- Reaching REMOTE is git's: its URLs, credentials and proxy, as the
  caller's config and environment give them. Whether a push is let in
  is the remote's.
- main is a poor branch for a wire. Every send moves a branch others
  build on, and whatever a project runs on that branch runs on the wire
  too. A branch of the wire's own keeps them apart. The caller names it.
- A PATH with a newline in it is refused: list prints a path a line.
- The scripts are bash, not sh. Run one by its path and let its first
  line pick the interpreter.

## In Claude Code

Every Bash call is a fresh shell. send, read and list are one call
each, and hold nothing between calls: the wire is on the remote.

A send that keeps being turned away keeps trying, for as long as the
branch keeps moving. The call's timeout is its only bound.

Where a session may push is set outside this skill: by the remote, by
the session's credentials, and by the branches its harness gives it. A
session names as REF a branch it may push to.

A message carries the pointer, and the wire carries the bytes. Bridge
has the facts about the messages that cross the session line.
