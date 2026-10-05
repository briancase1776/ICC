# ICC

Wires between running things, made out of what is already on the box.

A pipe is a FIFO held open. A fitting is `tee(1)` or `dd(1)`. A lock is
a directory `mkdir(1)` made. A patch is a text file saying which end went
where. Whoever holds an end can be an agent, a program, or a person at a
terminal — the name says Claude for historical reasons and only one piece
still means it.

    # four parties on a mesh, six lanes each
    pPatchDir=$(.claude/skills/icc-patch/scripts/create mesh 4 6)

    # seat 0 sends a photo
    pWriteEnd=$(awk '$1==0 && $2==0 {print $3}' "$pPatchDir/patch")
    .claude/skills/icc-frames/scripts/write "$pWriteEnd" 0 < photo.jpg

    # every other seat reads it whole on its read end from seat 0 -- and
    # every one must read, because the one that does not stalls the rest
    for osSeat in 1 2 3; do
      pReadEnd=$(awk -v s="$osSeat" '$1==s && $2==1 && $4=="0" {print $3}' \
        "$pPatchDir/patch")
      timeout 5 .claude/skills/icc-frames/scripts/read "$pReadEnd" 1 \
        > "seat$osSeat.jpg"
    done

Nothing in the middle looked at a byte. Six lanes carry about 200K across
a mesh that size; a bigger payload wants more lanes, and `write` refuses
rather than hangs when you ask for more than the wire holds. Frames,
which does the slicing here, is shelved for now, and so are Bridge's
out and in.

## The pieces

    icc-bridge     the spelling  a message across the session line, and back
    icc-patch      the bay       shapes over N seats, and a map
    icc-frames     the payload   slice, carry, reassemble (shelved)
    icc-tee        the fitting   copy one pipe onto many
    icc-merge      the fitting   copy many pipes onto one
    icc-pipes      the lane      a bidirectional channel at a path
    icc-git        the post      a branch that keeps what is sent to it
    icc-lock       the key       a path to one holder at a time
    icc-lib        the bench     the functions every other piece sources
    icc-raspberry  the egg       test data: sixteen kinds, from urandom

Ten Claude Code skills in one repo, under one `.claude/skills/`.

Bridge is the exception to the first paragraph: it spells a payload as
text that a SendMessage, send_message or a Routine carries across the
session line, and only a Claude can send those.

## Running it

    git clone https://github.com/briancase1776/ICC
    ./tests/run.sh

Every piece's harness, bottom up, each proving its own piece against the
pieces below it. From Frames up, that is a payload bigger than one lane
holds, pushed through pipes, fittings and shapes, and compared byte for
byte at the far end.

    ./tests/cal/run.sh

The calibrations: what the SKILL.md files say was measured, measured
again, a lane's pages and reads, a cable's depth, what p's merge makes
of three seats at once, with no load added and under it, and how fast
a merge moves 4 MiB. Every run is appended to its record in
`tests/cal/data/`, with the date, the commit and the machine, and
nothing in a record is ever taken out, so a figure can be looked up
years later. They take an hour or more and load the machine, so
`run.sh` does not run them. It checks only that no record has lost a
line.

## What it will not do

It does not know what your bytes mean or who is at the other end. It will
keep a path to one holder at a time, and not know who that is or what the
path is for. There is nowhere to put any of that, on purpose.

## Licence

MIT. See LICENCE.TXT.
