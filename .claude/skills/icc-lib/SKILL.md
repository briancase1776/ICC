---
name: icc-lib
description: >-
  The bash functions every ICC skill sources: counts and pipes checked,
  cleanup armed before anything is made, a piece's directory made and
  printed at once, servers deaf to a hangup, and the harnesses' cut-off
  checks. Not for a session to call; the other ICC skills need it beside
  them, in the same skills directory.
---

# icc-lib

What more than one ICC piece does, written once, so they all do it one
way. Every other ICC skill sources this file by fixed path, from beside
itself, so it has to be there:

    .claude/skills/icc-lib/scripts/lib

A session has no reason to call it. It is a skill so that it travels
with the others: install the ICC skills together, into one skills
directory.

## The functions

    nCount WHAT VALUE     VALUE as a count: digits, at most 18 significant,
                          printed in base ten
    nLanesGiven VALUE     a lane count as Pipes takes N: a count, even,
                          more than zero
    vSide SIDE            SIDE is 0 or 1
    nLanesOf PIPE...      the lane count the pipes share: each a pipe,
                          the count even, the same, every lane a fifo
    vArm CLEANUP          arm CLEANUP on EXIT, and INT, TERM and HUP to
                          exit 1, before anything is made
    vStopOnSignal         INT, TERM and HUP exit 1 again, after a handler
                          swapped them
    vDisarm               clear it all: what was made is whole
    pMakeDir KIND         make /tmp/KIND-XXXXXXXX, set pDir to it, and
                          print it at once, before anything goes in it
    vServe                first thing in a hold or a copier: no traps,
                          and deaf to HUP, as a server under nohup is
    vCutOffAt SIGNAL STUB COMMAND...
                          for the harnesses: send SIGNAL to COMMAND
                          while it waits in STUB, and check it exits 1
                          and what it made is gone: what it printed
                          first, or what a stand-in mktemp made
    vCutOff COMMAND...    vCutOffAt TERM mktemp COMMAND: just after its
                          first mktemp

A function that refuses says why on stderr and exits 1. Called in
`$( )`, as the n functions are, that ends only the substitution, and
the caller's failed assignment stops the caller under `set -e`. A
script that sets `osWho` gets it in front of every refusal, as Frames'
read and write do.

Sourcing turns on `extglob`, which nLanesOf's glob needs. It does not
turn on `nullglob`: nLanesOf checks lane 0 first, so its glob always
matches, and nullglob would change what an unmatched glob does in the
script that sourced it.
