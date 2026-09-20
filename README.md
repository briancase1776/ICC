# ICC

Wires between running things, made out of what is already on the box.

A pipe is a FIFO held open. A fitting is `tee(1)` or `dd(1)`. A patch is a
text file saying which end went where. Whoever holds an end can be an
agent, a program, or a person at a terminal — the name says Claude for
historical reasons and only one piece still means it.

    # four parties on a mesh, six lanes each
    x=$(ICC-Patch/.claude/skills/icc-patch/scripts/create mesh 4 6)

    # seat 0 sends a photo
    e=$(awk '$1==0 && $2==0 {print $3}' "$x/patch")
    ICC-Frames/.claude/skills/icc-frames/scripts/write "$e" 0 < photo.jpg

    # seat 2 gets it whole, and so does everyone else
    e=$(awk '$1==2 && $2==1 {print $3}' "$x/patch")
    timeout 5 ICC-Frames/.claude/skills/icc-frames/scripts/read "$e" 1 \
      > out.jpg

Nothing between those two commands looked at a byte.

## The pieces

    ICC-Bridge   the spelling  a payload as a message, and back
    ICC-Patch    the bay       shapes over N seats, and a map
    ICC-Frames   the payload   slice, carry, reassemble
    ICC-Tee      the fitting   copy one pipe onto many
    ICC-Merge    the fitting   copy many pipes onto one
    ICC-Pipes    the lane      a bidirectional channel at a path

Six Claude Code skills, one repo each, pinned here as submodules so they
sit beside each other the way they expect. Each has its own README.

Bridge is the exception to the first paragraph: it carries a payload
across the session line as a SendMessage, and only a Claude can call that.

## Held open

Two repos are names with no design in them, on purpose. Each says what the
idea was, why it may not need to exist, and what would have to be true
first.

- [ICC-Lock](https://github.com/briancase1776/ICC-Lock) — an exclusive
  turn, and why the obvious design is the wrong one
- [ICC-Switch](https://github.com/briancase1776/ICC-Switch) — a partition
  taking one pattern, and why a party may already do it

## Running it

    git clone --recurse-submodules https://github.com/briancase1776/ICC
    ./tests/run.sh

Every piece's harness, bottom up: a payload bigger than one lane holds,
pushed through pipes, fittings and shapes, and compared byte for byte at
the far end.

## What it will not do

It does not know what your bytes mean, who is at the other end, or whose
turn it is. There is nowhere to put any of that, on purpose.

## Licence

MIT. See LICENCE.TXT.
