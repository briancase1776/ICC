---
name: icc-lock
description: >-
  Lock a path so that one holder at a time has it, across the tool
  calls, agents and processes that share /tmp. Take it, waiting while
  someone else has it; hold it for SECONDS at most; give it back.
  Advisory: it keeps out only those who take it too. What the path is,
  and what holding it is for, is the caller's business.
---

# icc-lock

A lock is a path and one holder. create waits until nobody holds PATH,
then holds it in a process of its own, the hold, until you remove it or
SECONDS run out, whichever comes first. Anyone else who asks for PATH
meanwhile waits. The lock itself is the kernel's: flock(2), exclusive,
on a file named for PATH, held open by the hold, so the lock goes the
moment the hold does, however the hold goes.

    /tmp/icc-lock/KEY                 the file the kernel locks, KEY the
                                      sha256 of PATH, one per PATH
    /tmp/icc-lock-XXXXXXXX/lock       PATH, then that file, one per line
    /tmp/icc-lock-XXXXXXXX/pid        the hold's process id

## Operations

    scripts/create PATH SECONDS   wait until nobody holds PATH, hold it
                                  for SECONDS at most, print the hold's
                                  directory
    scripts/list                  one line per hold: DIR up|down PATH
    scripts/remove DIR            give the lock back, delete DIR

PATH is any path, there or not: a file can be locked before it is
written. It is taken as `readlink -m` spells it, so `src/a.c`,
`./src/a.c` and the same file through a symlink are one lock. A lock on
a directory is a lock on that name, not on anything under it.

    pLock=$(timeout 60 scripts/create src/a.c 600)   # one tool call
    # ... edit src/a.c, over as many tool calls as it takes ...
    scripts/remove "$pLock"                          # another

A process takes one the same way, and gives it back on its way out:

    pLock=$(timeout 60 scripts/create "$pRepo/.git" 120)
    trap 'scripts/remove "$pLock"' EXIT

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
  other waits. Of several waiting when it is given back, one gets it,
  and nothing says which: there is no queue.
- create waits as long as it takes. Bound it with `timeout`, as Pipes
  says to bound a read. `timeout 60 scripts/create PATH 600` exits 124
  when someone held PATH all 60 seconds, and then it has made nothing,
  printed nothing, and left nothing waiting. Unlike a read, a create
  does not spend its whole bound: it returns the moment PATH is free.
- Not re-entrant. A create for a PATH you already hold waits for your
  own hold, like anyone else's.
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
  They are empty, one per PATH ever locked.
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

A create that waits in the foreground hangs the tool call until the
harness times it out. Bound it, and when it says 124, do something else
and come back.

Everything that shares /tmp shares the locks: every subagent of a
session, and every session run on one machine. Sessions in separate
containers share no /tmp, and no files to lock either; no lock crosses
that line.
