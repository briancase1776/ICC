---
name: icc-lock
description: >-
  Lock a path, and everything under it, so that one holder at a time
  has it, across the tool calls, agents and processes that share /tmp.
  In a git work tree a path is locked as a file of its repository, in
  every work tree of it at once. Take it, waiting while someone else
  has it; hold it for SECONDS at most; give it back. Advisory: it keeps
  out only those who take it too. What the path is, and what holding it
  is for, is the caller's business.
---

# icc-lock

A lock is a path, everything under it, and one holder. create waits
until nobody holds PATH, anything above it or anything under it, then
holds PATH in a process of its own, the hold, until you remove it or
SECONDS run out, whichever comes first. Anyone else who asks for PATH,
or for something above or under it, meanwhile waits. The lock itself is
the kernel's: flock(2), on files named for PATH and each directory above
it, held open by the hold, so the lock goes the moment the hold does,
however the hold goes.

    /tmp/icc-lock/KEY                 the file the kernel locks for a
                                      name, KEY the sha256 of the name
    /tmp/icc-lock/KEY.gate            its gate; see below
    /tmp/icc-lock-XXXXXXXX/lock       PATH, then PATH's file, then the
                                      file of each directory above it,
                                      top down, one per line
    /tmp/icc-lock-XXXXXXXX/pid        the hold's process id

## Operations

    scripts/create PATH SECONDS   wait until nobody holds PATH, hold it
                                  for SECONDS at most, print the hold's
                                  directory
    scripts/list                  one line per hold: DIR up|down PATH
    scripts/remove DIR            give the lock back, delete DIR

PATH is any path, there or not: a file can be locked before it is
written. It is taken as `readlink -m` spells it, so `src/a.c`,
`./src/a.c` and the same file through a symlink are one lock.

    pLock=$(timeout 60 scripts/create src/a.c 600)   # one tool call
    # ... edit src/a.c, over as many tool calls as it takes ...
    scripts/remove "$pLock"                          # another

A directory is locked the same way, and its lock is on all of it. A
process takes one the same way, and gives it back on its way out:

    pLock=$(timeout 60 scripts/create "$pRepo" 120)   # the whole tree
    trap 'scripts/remove "$pLock"' EXIT
    git -C "$pRepo" commit ...

## What a lock covers

A lock on a directory covers everything under it, at any depth, there
or not. Underneath, every create takes its PATH exclusively and every
directory above PATH shared, top down, from / to PATH:

- A file and the directory it is in wait for each other. A file and a
  file beside it do not; neither do two directories side by side.
- The files and directories under a held one wait until it is given
  back, and a directory waits until nothing under it is held.
- Every name has a gate. A create passes each gate above PATH on its
  way to the shared lock there, and holds PATH's own gate while it
  waits for PATH. So a directory waiting for what is under it to be
  given back goes ahead of anything that comes for under it after:
  a lock on a whole tree waits for the holders it found, not for
  every one that comes along later.
- Every wait is for something further down than anything the waiter
  holds, so no two creates can each wait on the other.

## Code in git

A path is locked by its name. Outside git the name is the path. In a
git work tree the name is the repository, its common git directory, and
where the path sits in the tree, so:

- One file in every work tree of a repository is one lock, whichever
  tree it is locked from, and whether it is there or not: `git worktree
  add` gives a second tree, and `src/a.c` in either is the same lock.
- The top of a work tree is the whole repository, in every work tree of
  it. A tree's top is what to lock for a commit, a pull, a checkout, or
  anything else that touches more than a file.
- A clone is a repository of its own, with a git directory of its own,
  and its files are other files. Two clones of one repository share no
  locks; two work trees of one repository share all of them.
- A path inside `.git` is named by its path. A lock on a tree's top does
  not cover it.
- A directory above a work tree is named by its path, as it always was,
  and still covers that work tree, and only that one.
- A path that is in no work tree is named by its path, whether a
  repository is meant for it later or not.

The scripts source icc-lib's shared functions from beside this skill,
`../../icc-lib/scripts/lib` in the same skills directory, so icc-lib has
to be installed with it.

## Facts about the lock

These are properties of flock(2) and of the hold. The skill adds
nothing to them.

- Advisory. A lock keeps out only those who ask for it. Nothing stops a
  write to PATH: not an editor, not a tool, not a process that never
  called create. Every party that touches PATH agrees, outside this
  skill, to take the lock first.
- One holder. Of two creates that ask at once, one gets PATH and the
  other waits. Of several waiting for one PATH when it is given back,
  one gets it, and nothing says which: there is no queue.
- create waits as long as it takes. Bound it with `timeout`, as Pipes
  says to bound a read. `timeout 60 scripts/create PATH 600` exits 124
  when someone held PATH all 60 seconds, and then it has made nothing,
  printed nothing, and left nothing waiting. Unlike a read, a create
  does not spend its whole bound: it returns the moment PATH is free.
- Not re-entrant, and not widened. A create for a PATH you already
  hold, or for a directory above something you hold, waits for your own
  hold, like anyone else's. Give back what you hold, then take the
  directory.
- SECONDS is a lease, and it runs out whether you are done or not. Then
  the lock is free, and the next create gets PATH while you may still be
  working on it. remove tells you after the fact: it says `lapsed` and
  exits 1 when the hold was already gone. Ask for longer than the work
  takes. There is no renewing a lease; a new create is a new lock, and
  someone else may get PATH first.
- SECONDS is also what a holder that stops costs everyone else. The
  hold outlives the shell that made it, which is how a lock spans tool
  calls, so an agent or a process that ends without remove holds PATH
  until SECONDS run out, and no longer.
- The lock goes with the hold. Lease run out, killed by TERM, killed by
  KILL: the kernel frees the lock as the process goes, with nobody left
  to forget to.
- The hold is a server, as Pipes' hold is. It ignores HUP, so a lock
  outlives the terminal or shell it was taken from. TERM, which remove
  sends, ends it.
- remove sends TERM and returns. The lock goes as the hold does, a
  moment later, and a create waiting on it gets it then.
- A hold that has gone, by its lease or by a kill, says down in list,
  and its directory stays until someone removes it. remove takes a down
  hold's directory like any other, and kills nothing.
- The files in /tmp/icc-lock/ are never removed. Removing one that a
  create has open and is waiting on would hand PATH to two holders at
  once: the waiter on the old file and the next create on a new one.
  They are empty, two per name ever locked.
- The work tree is git's to say: `git rev-parse`, asked from the
  nearest directory of PATH that is there, with GIT_DIR and
  GIT_WORK_TREE unset. Where git is not there, or says PATH is in no
  work tree, the name is the path.
- The hold is `sleep SECONDS`. PATH is not in its argv, so `pkill -f`
  on PATH finds nothing. Find a hold under /proc/PID/fd, as list does,
  or by its directory.
- Two hard links to one file are two paths and two locks. A symlink is
  resolved when create runs; one that changes after points somewhere
  the lock is not.
- A PATH with a newline in it is refused: the directory keeps PATH as a
  line.
- The scripts are bash, not sh. Run one by its path and let its first
  line pick the interpreter.

## In Claude Code

Every Bash call is a fresh shell. The hold is its own process, so a
lock outlives the call that took it: take it in one call, work across
as many as it takes, give it back in another. Keep the directory create
printed; remove needs it, and nothing else knows which hold is yours.

Read, Edit and Write know nothing of the lock. Agents that build side by
side take it before they touch PATH, because they agreed to, and for no
other reason.

Subagents that each work in a `git worktree` of one repository share
its locks, as seats in one tree do. Subagents that each clone it do
not.

A create that waits in the foreground hangs the tool call until the
harness times it out. Bound it, and when it says 124, do something else
and come back.

Everything that shares /tmp shares the locks: every subagent of a
session, and every session run on one machine. Sessions in separate
containers share no /tmp, and no files to lock either; no lock crosses
that line.
