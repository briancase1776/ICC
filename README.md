# ICC-Frames

Push something big down a bundle of narrow pipes and take it off whole at
the other end.

Two operations. `write` takes bytes and puts them on the lanes its side
writes. `read` takes them off the lanes its side reads and hands the bytes
back. What goes in comes out: the same bytes in the same order, across the
whole bundle and not merely within one lane. A JPEG goes in as a JPEG and
comes out as a JPEG, top at the top.

The pipes come from
[ICC-Pipes](https://github.com/briancase1776/ICC-Pipes), the layer below.
This one never makes a pipe and never looks at what is going through it.

## Using it

It is a Claude Code skill. Get a pipe from Pipes, then:

    d=$(icc-pipes/scripts/create 8)
    icc-frames/scripts/write "$d" 0 < photo.jpg          # one side
    timeout 60 icc-frames/scripts/read "$d" 1 > photo.jpg # the other

`SIDE` is 0 or 1 and says which lanes you write and which you read; Pipes
says which is which, and which side you are is agreed outside this skill.
Nothing here blocks on opening a pipe. The one thing that waits is a read
with nothing to read yet, so bound it with `timeout`.

Both ends follow one rule and nothing on the wire announces it, so both
ends have to be this layer.
`.claude/skills/icc-frames/SKILL.md` is that rule.

    tests/run.sh    prove it: a payload bigger than one lane holds, both
                    directions, on six lanes and on two

## How much it carries

A bundle carries what its width allows, and the figure does not change with
anything else you do to the pipe:

| lanes | carries |
|---|---|
| 2 | 131072 |
| 6 | 262144 |
| 8 | 327680 |
| 64 | 2162688 |
| 128 | 4259840 |

Build for the payload: roughly a lane per 32K. Two lanes carry 128K and
sixty-four carry two megabytes, byte for byte.

Past that figure there is nothing to be done at the far end — a reader
cannot rescue it — so ask for a wider bundle instead. Given a file, `write`
refuses one it cannot carry before it starts:

    $ write "$d" 0 < too-big.bin
    write: 200000 bytes is past the hold: these lanes carry 131072, and more lanes is the only remedy

Given bytes piped in rather than a file, there is no size to check in
advance, and a payload past the figure hangs instead of being refused. That
one is open.

## What it does not do

It does not make, list, remove or hold pipes, and it does not choose lane
counts or decide which side you are. That is Pipes, and this repo does not
wrap it, copy it or vendor it.

It does not know what your bytes mean. No message types, no schemas, no
encodings, no timestamps, no tag saying what a payload is. There is nowhere
to put one, on purpose.

It does not route, retry, queue, replay, persist, or tell you whether anyone
is listening at the other end.

## Licence

MIT. See LICENCE.TXT.
