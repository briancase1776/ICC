---
name: icc-lock
description: >-
  Lock a path with mkdir. Of any number of agents or processes that ask
  for one path at once, one gets it and the rest are refused at once.
  Held until someone removes it: no timeout, no waiting. Advisory: it
  keeps out only those who take it too. What the path is, and what
  holding it is for, is the caller's business.
---

# icc-lock

A lock is a directory. create makes it with mkdir(1), which makes it or
fails, and does either at once. Forty agents ask for one path together:
one gets the lock, thirty-nine are refused. remove takes it away with
rmdir(1). That is all there is.

    /tmp/icc-lock-KEY          the lock, KEY the sha256 of PATH

## Operations

    scripts/create PATH   mkdir the lock on PATH and print PATH as
                          readlink -m spells it; or say why not, as
                          mkdir says it, and exit 1
    scripts/list          one line per lock: its directory
    scripts/remove PATH   rmdir the lock on PATH

PATH is any path, there or not: a file can be locked before it is
written. It is taken as `readlink -m` spells it, so `src/a.c`,
`./src/a.c` and the same file through a symlink are one lock, and
remove takes any of them, and what create printed.

Name PATH absolutely. A relative path is read from the caller's own
working directory, and no two holders need share one: the root is the
only frame of reference every holder has in common.

    scripts/create /home/me/proj/src/a.c    # locked, or refused, and why
    # ... edit it, over as many tool calls as it takes ...
    scripts/remove /home/me/proj/src/a.c

remove a lock only when your own create took it, with exit 0, and only
once. remove takes away whoever's lock it finds; one said twice, or for
a path you were refused, takes away someone else's.

A holder that needs several paths and is refused a later one gives back
the ones it already took, and tries again later.

create and remove source icc-lib's shared functions from beside this
skill, `../../icc-lib/scripts/lib` in the same skills directory, so
icc-lib has to be installed with it.

## Facts about the lock

- Advisory. A lock keeps out only those who ask for it. Nothing stops a
  write to PATH: not an editor, not a tool, not a process that never
  called create. Every party that touches PATH agrees, outside this
  skill, to take the lock first.
- One holder. mkdir either makes the directory or finds it there, as one
  step, so of any number of creates at once exactly one makes it.
- No waiting. create answers at once. mkdir's exit says whether the lock
  was taken, and its message says why not: `File exists` is held, and
  anything else is a fault. Either way, do something else and ask again
  later; asking again where the fault is does no harm.
- No end. A lock is held until remove, and nothing else ends it. A lock
  that ran out on its own would let a second holder in while the first
  was still at work. So a holder that stops without remove leaves its
  lock behind, and so does a create cut off once mkdir has made it:
  list shows it, and anyone's remove takes it.
- Not re-entrant. A create for a path you already hold is refused.
- One path, one lock. A lock on a directory's path is on that name, not
  on what is under it. Two hard links to one file are two paths and two
  locks. A symlink is resolved when create runs.
- Nothing runs. A lock is a directory, so it outlives every shell, tool
  call and agent that had a hand in it.
- Nothing is written down: not whose a lock is, not which path it is
  for. list names each lock by its hash, and mkdir and rmdir name it
  that way when they refuse.
- rmdir refuses a lock with anything in it. create never puts anything
  there.
- A PATH with a newline in it is refused: `$( )` drops a trailing one,
  which would name some other path's lock.
- The scripts are bash, not sh. Run one by its path and let its first
  line pick the interpreter.

## In Claude Code

Every Bash call is a fresh shell, and a lock is a directory, so it is
there in the next call and the one after: take it in one call, work
across as many as it takes, give it back in another.

Read, Edit and Write know nothing of the lock. Agents that build side by
side take it before they touch PATH, because they agreed to, and for no
other reason.

A lock is on a path on this machine. Seats that work on one set of files
work in one tree; a seat in a clone or a `git worktree` of its own has
other paths, and other locks.

Everything that shares /tmp shares the locks: every subagent of a
session, and every session run on one machine. Sessions in separate
containers share no /tmp, and no files to lock either; no lock crosses
that line.
