# ICC-Frames

Push something big down a bundle of narrow pipes and take it off whole at
the other end.

Two operations. `write` slices what you give it into frames and puts them
on the lanes its side writes. `read` takes them off the lanes its side
reads and hands the bytes back. What goes in comes out, the same bytes in
the same order, across every lane and not just within one.

The pipes are made by [ICC-Pipes](https://github.com/briancase1776/ICC-Pipes),
which is the layer below. This one never makes a pipe and never looks at
what is going through it.

## What is on the wire

One number. The payload's byte count, in front, because a held pipe never
says EOF and the far end has to know when to stop. Nothing else is added:
no header, no type, no length per frame, no mark of who sent it.

Everything else both ends already know. A frame is one write of at most
`PIPE_BUF`, so the kernel lands it whole. Frame *k* goes on the *k*th lane
this side writes, round-robin, lane order, starting at the first. The far
end takes them back off in the same order. Nothing on the wire says any of
that, and nothing needs to.

## What it carries

The payload is weighed in flight. Nothing that came off a wire, or is on
its way to one, is written to a file — so the count in front is paid for by
holding the whole payload in pipes while it is counted. That hold is what
caps the layer, and it is worth knowing before you build:

| lanes | this side writes | carries |
|---|---|---|
| 2 | 1 | 131072 |
| 6 | 3 | 262144 |
| 8 | 4 | 327680 |
| 64 | 32 | 2162688 |
| 128 | 64 | 4259840 |

One more than the lanes this side writes, times 64K. The hold is a chain of
`cat`, one per lane, and the pipes between them are made by this project and
never grown — so that figure is the same however wide the lanes themselves
have been made. Growing six lanes to a megabyte each, sixteen times the
wire, moves it not at all.

So the bundle is the whole point. Two lanes carries 128K; sixty-four lanes
carries two megabytes, byte for byte, measured. **More lanes is the only
remedy**, and the arithmetic for building one is a lane per 32K of payload.

A second, smaller number matters if nobody is reading yet: what a write can
leave on the wire and walk away from is the lanes its own side writes, times
what a lane holds, less the count line. Past that it waits for a read, which
is fine — a reader frees it. Past the hold nothing frees it, because nothing
has reached the lanes for a reader to take.

`write` knows that figure and will not start a file it cannot finish:

    $ write "$d" 0 < too-big.bin
    write: 200000 bytes is past the hold: these lanes carry 131072, and more lanes is the only remedy

Given a pipe rather than a file there is no size to read in advance, and a
payload past the hold still hangs. That one is open.

## Using it

It is a Claude Code skill. Get a pipe from Pipes, then:

    d=$(icc-pipes/scripts/create 8)
    icc-frames/scripts/write "$d" 0 < photo.jpg          # one side
    timeout 60 icc-frames/scripts/read "$d" 1 > photo.jpg # the other

`SIDE` is 0 or 1 and decides which lanes you write and which you read; Pipes
says which is which. Both ends open every lane with `<>`, so nothing here
blocks on open, and a frame written through one comes back with nobody
reading. The one thing that waits is a read on an empty lane — bound it with
`timeout`, as Pipes says.

`.claude/skills/icc-frames/SKILL.md` is the rest: the rule both ends follow,
and the facts that cost an afternoon each.

    tests/run.sh    prove it: a payload bigger than one lane holds, both
                    directions, on six lanes and on two

## What it does not do

It does not make, list, remove or hold pipes. It does not choose lane counts
or decide which side you are. That is Pipes, and this repo does not wrap it,
copy it or vendor it.

It does not know what your bytes mean. No message types, no schemas, no
encodings, no timestamps, no tag saying what a payload is. There is no field
to put one in, on purpose.

It does not route, retry, queue, replay, persist, or tell you whether anyone
is on the other end.

## What a moot found

The issues here are mostly the output of sittings of
[Moot](https://github.com/briancase1776/Moot) — three cold agents auditing
this repo, each reporting alone, then arguing every other seat's position in
turn before voting. Three seats looked for a bug in the slicing and
reassembly and none of them found one: round trips are byte-exact at every
size and lane count tried, both directions, empty payload included, and
nothing leaks under any signal.

What they did find was silence. All three of this layer's real failures
returned nothing and said nothing, in a project where every other fault
prints a reason and exits 1. One of those is now fixed, one is narrowed to
the case where the size cannot be known before the write starts, and one — a
read handed no count at all — is still open. They also overturned the thing all three seats believed at the start — that
the layer carries far less than its framing implies. It carries what the
bundle is built for, and what was missing was the sentence telling you how
wide to build it.

## Licence

MIT. See LICENCE.TXT.
