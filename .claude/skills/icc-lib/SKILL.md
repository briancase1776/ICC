---
name: icc-lib
description: >-
  The bash functions every ICC skill sources: counts and pipes checked,
  a seat's lanes read off Patch's map and waited on without taking from
  them, cleanup armed before anything is made, a piece's directory made
  and printed at once, servers deaf to a hangup, a copier stopped with
  the dd it has running, a lock named for its path, a git wire's tip fetched, the harnesses' cut-off and refusal
  checks, and the calibrations' ok and off. Not for a session to call;
  the other ICC skills need it beside them, in the same skills directory.
---

# icc-lib

What more than one ICC piece does, written once, so they all do it one
way. Every other ICC skill sources this file by fixed path, from beside
itself, so it has to be there:

    .claude/skills/icc-lib/scripts/lib

A session has no reason to call it. It is a skill so that it travels
with the others: install the ICC skills together, into one skills
directory.

A script outside ICC may source any of these, as one inside does.
oLanes and vWaitFor are the two no piece calls: they are for a script
that sits at a seat and wants its lanes, or waits on them, and they are
here because the map is Patch's and the lanes are Pipes', so reading one
into the other is ICC's to write. All of them change with ICC's pieces.
A script outside that sources one keeps up with it, not it with that
script.

## The functions

    nCount WHAT VALUE     VALUE as a count: digits, at most 18 significant,
                          printed in base ten
    nLanesGiven VALUE     a lane count as Pipes takes N: a count, even,
                          more than zero
    vSide SIDE            SIDE is 0 or 1
    nLanesOf PIPE...      the lane count the pipes share: each a pipe,
                          the count even, the same, every lane a fifo
    oLanes PATCH SEAT w|r the lanes SEAT writes, one per line; or those
                          it reads, each with the seats that write into
                          it: off Patch's map, as Pipes and Patch say
    vWaitFor PATCH SEAT SECONDS
                          wait until every lane SEAT reads has something
                          on it, taking nothing; or say "not yet, nothing
                          taken" and exit 1 once SECONDS, a count, have
                          gone, and 0 looks once; refuse a lane that is
                          not a fifo, before every look
    vArm CLEANUP          arm CLEANUP on EXIT, and INT, TERM and HUP to
                          exit 1, before anything is made
    vStopOnSignal         INT, TERM and HUP exit 1 again, after a handler
                          swapped them
    vDisarm               clear it all: what was made is whole
    pMakeDir KIND         make /tmp/KIND-XXXXXXXX, set pDir to it, and
                          print it at once, before anything goes in it
    vServe                first thing in a hold or a copier: no traps,
                          and deaf to HUP, as a server under nohup is
    vStopCopier PID       stop a copier so that neither it nor the dd it
                          has running moves another byte: STOP it, KILL
                          its children, TERM it, CONT it, as Merge's
                          create and remove both do
    vLockOf PATH          name the lock on PATH, as icc-lock's create
                          and remove both do: set pPath to PATH as
                          readlink -m spells it, and pLock to its
                          directory; refuse a newline
    vWireTip REMOTE REF   fetch the tip of branch REF on REMOTE, as
                          icc-git's send, read and list all do, into a
                          scratch repo it makes and sets pWork to on
                          the first call, clear of the caller's repo:
                          set osTip to the tip, or to nothing when REF
                          is not on REMOTE yet; refuse a REF git
                          refuses, and a REMOTE not read
    vCutOffAt SIGNAL STUB COMMAND...
                          for the harnesses: send SIGNAL to COMMAND
                          while it waits in STUB, and check it exits 1
                          and what it made is gone: what it printed
                          first, or what a stand-in mktemp made
    vCutOff COMMAND...    vCutOffAt TERM mktemp COMMAND: just after its
                          first mktemp
    vRefused COMMAND...   for the harnesses: run COMMAND, and stop when
                          it is not refused
    vFound 1|0 FOUND...   for the calibrations: print what a case found
                          on one line, ok in front when it is what a
                          SKILL.md says and off when not, and count the
                          off ones in nOff

A function that refuses says why on stderr and exits 1. Called in
`$( )`, as the n functions are, that ends only the substitution, and
the caller's failed assignment stops the caller under `set -e`. A
script that sets `osWho` gets it in front of every refusal, as Frames'
read and write do.

Sourcing turns on `extglob`, which nLanesOf's glob needs. It does not
turn on `nullglob`: nLanesOf checks lane 0 first, so its glob always
matches, and nullglob would change what an unmatched glob does in the
script that sourced it.
