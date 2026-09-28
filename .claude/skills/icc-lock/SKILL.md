---
name: icc-lock
description: >-
  Lock a path with mkdir. Of any number of agents or processes that ask
  for one path at once, one gets it and the rest are told at once that
  it is held. Held until someone removes it: no timeout, no waiting.
  Advisory: it keeps out only those who take it too. What the path is,
  and what holding it is for, is the caller's business.
---

# icc-lock

A lock is a directory. create makes it with mkdir(1), which makes it or
fails, and does either at once. Forty agents ask for one path together:
one gets the lock, thirty-nine are told it is held. remove gives it
back. That is all there is.

    /tmp/icc-lock-KEY          the lock, KEY the sha256 of PATH
    /tmp/icc-lock-KEY/lock     PATH, one line

## Operations

    scripts/create PATH   take the lock on PATH and print its directory;
                          or, when someone has it, say "held: PATH" and
                          exit 2
    scripts/list          one line per lock: DIR PATH
    scripts/remove PATH   give the lock on PATH back

PATH is any path, there or not: a file can be locked before it is
written. It is taken as `readlink -m` spells it, so `src/a.c`,
`./src/a.c` and the same file through a symlink are one lock, and
remove takes any of them.

    scripts/create src/a.c    # one tool call: locked, or "held" and 2
    # ... edit src/a.c, over as many tool calls as it takes ...
    scripts/remove src/a.c    # another

The scripts source icc-lib's shared functions from beside this skill,
`../../icc-lib/scripts/lib` in the same skills directory, so icc-lib has
to be installed with it.

## Facts about the lock

- Advisory. A lock keeps out only those who ask for it. Nothing stops a
  write to PATH: not an editor, not a tool, not a process that never
  called create. Every party that touches PATH agrees, outside this
  skill, to take the lock first.
- One holder. mkdir either makes the directory or finds it there, as one
  step, so of any number of creates at once exactly one makes it.
- No waiting. create answers at once. Held means held: do something
  else and ask again later.
- No end. A lock is held until remove, and nothing else ends it. A lock
  that ran out on its own would let a second holder in while the first
  was still at work. So a holder that stops without remove leaves its
  lock behind: list shows it, and anyone's remove takes it.
- Not re-entrant. A create for a path you already hold says held.
- One path, one lock. A lock on a directory's path is on that name, not
  on what is under it. Two hard links to one file are two paths and two
  locks. A symlink is resolved when create runs.
- Nothing runs. A lock is a directory and a file, so it outlives every
  shell, tool call and agent that had a hand in it.
- Who holds a lock is not written down. Whose it is, is agreed outside
  this skill.
- A PATH with a newline in it is refused: the lock keeps PATH as a line.
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
