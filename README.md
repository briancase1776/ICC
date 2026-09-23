# ICC

Wires between running things, made out of what is already on the box.

A pipe is a FIFO held open. A fitting is `tee(1)` or `dd(1)`. A patch is a
text file saying which end went where. Whoever holds an end can be an
agent, a program, or a person at a terminal — the name says Claude for
historical reasons and only one piece still means it.

    # four parties on a mesh, six lanes each
    pPatchDir=$(.claude/skills/icc-patch/scripts/create mesh 4 6)

    # seat 0 sends a photo
    pWriteEnd=$(awk '$1==0 && $2==0 {print $3}' "$pPatchDir/patch")
    .claude/skills/icc-frames/scripts/write "$pWriteEnd" 0 < photo.jpg

    # every seat reads it whole, the sender included -- and every seat
    # must read, because the one that does not stalls the rest
    for osSeat in 0 1 2 3; do
      pReadEnd=$(awk -v s="$osSeat" '$1==s && $2==1 {print $3}' \
        "$pPatchDir/patch")
      timeout 5 .claude/skills/icc-frames/scripts/read "$pReadEnd" 1 \
        > "seat$osSeat.jpg"
    done

Nothing in the middle looked at a byte. Six lanes carry about 200K across
a mesh that size; a bigger payload wants more lanes, and `write` refuses
rather than hangs when you ask for more than the wire holds.

## The pieces

    icc-bridge   the spelling  a payload as a message, and back
    icc-patch    the bay       shapes over N seats, and a map
    icc-frames   the payload   slice, carry, reassemble
    icc-tee      the fitting   copy one pipe onto many
    icc-merge    the fitting   copy many pipes onto one
    icc-pipes    the lane      a bidirectional channel at a path

Six Claude Code skills in one repo, under one `.claude/skills/`.

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

    git clone https://github.com/briancase1776/ICC
    ./tests/run.sh

If you had this repo while the pieces were submodules, pulling leaves
all six of them in your working tree and says nothing: git drops the
link and leaves the directory, so `git status` is clean while six stale
checkouts sit beside the new `.claude/`, their old scripts still
running from their old paths. Take them out once:

    git submodule deinit -f . 2>/dev/null || :
    rm -rf ICC-Pipes ICC-Frames ICC-Tee ICC-Merge ICC-Patch ICC-Bridge
    rm -rf .git/modules

Every piece's harness, bottom up: a payload bigger than one lane holds,
pushed through pipes, fittings and shapes, and compared byte for byte at
the far end.

## What it will not do

It does not know what your bytes mean, who is at the other end, or whose
turn it is. There is nowhere to put any of that, on purpose.

## Licence

MIT. See LICENCE.TXT.
