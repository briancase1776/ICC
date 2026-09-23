---
name: icc-tee
description: >-
  Tee an icc-pipes pipe. Copy what one side writes into a pipe onto the
  same lanes of other pipes, byte for byte, in order, until removed. Plain
  bytes and icc-frames payloads alike come out of every outlet as they
  went in. What the bytes are, and why they are copied, is the caller's
  business.
---

# icc-tee

A tee is one inlet pipe and N outlet pipes. Every byte SIDE writes into
a lane of the inlet comes out of the same lane of every outlet, in the
order it went in. It is a fitting: it joins pipes that icc-pipes already
made and makes nothing else. Pipes says what a lane is and which lanes
each side writes; see its SKILL.md.

    /tmp/icc-tee-XXXXXXXX/tee    SRC, SIDE, then each DST, one per line
    /tmp/icc-tee-XXXXXXXX/pid    one copier per lane SIDE writes, lane order

## Operations

    scripts/create SRC SIDE DST...  copy what SIDE writes into SRC onto
                                    every DST, print the tee's directory.
                                    Every pipe must exist and have the
                                    same even lane count.
    scripts/list                    one line per tee: DIR up|down SRC SIDE DST...
    scripts/remove DIR              stop the tee, delete DIR. The pipes on
                                    either end are left as they were.

SIDE is 0 or 1, as Pipes says: side 0 writes the even lanes, side 1 the
odd ones. To use a tee, write the inlet as SIDE and read each outlet as
the other side. There is nothing else to do.

    pPipeA=$(.../icc-pipes/scripts/create 6)
    pPipeB=$(.../icc-pipes/scripts/create 6)
    pTeeDir=$(scripts/create "$pPipeA" 0 "$pPipeB")
    .../icc-frames/scripts/write "$pPipeA" 0 < photo.jpg
    timeout 5 .../icc-frames/scripts/read "$pPipeB" 1 > photo.jpg

## Facts about the tee

Each lane SIDE writes has its own `tee(1)`, that lane of SRC on its
stdin and that lane of every DST as its outputs. These are properties
of that and of the lanes. The skill adds nothing to them.

- A tee copies one direction of one pipe. The lanes the other side
  writes are not touched. Nothing goes back through it.
- The tee is the reader of every lane it copies. Bytes it takes are
  gone from SRC and exist only on the outlets. Read the outlets.
- Every lane is copied whole, in order, onto the same lane number, and
  every pipe has the same lane count. That is all icc-frames' rule
  needs, so a Frames read on any outlet yields the payload.
- A copier writes 8192 bytes at a time, which is larger than PIPE_BUF;
  Pipes' SKILL.md says what that means for a lane. So the line above
  holds while the tee is the only writer on that outlet lane. Put a
  second writer on it and both streams are torn, in pieces neither one
  chose.
- The tee is one more writer on each outlet lane. Everything Pipes says
  of a writer holds for it.
- Each chunk read from a lane is written to that lane of every outlet,
  in order, before the next chunk is read. An outlet lane that is full
  and not being drained stalls its copier, so the same lane of every
  other outlet, and of SRC once it fills, stalls behind it. Nothing is
  kept.
- What a write into SRC can leave on the wire and walk away from is
  SRC's lanes plus, while the copiers can move, the outlets' lanes.
  Pipes' SKILL.md has the numbers.
- A copier ends when its lane of SRC hits EOF or a write to an outlet
  lane fails. Held lanes never do either, so the tee runs until removed
  or until a pipe on either end is removed. SRC's removal ends every
  copier at once. An outlet's is found only by writing to it, so the
  copiers end one at a time as traffic reaches their lanes, and a tee
  that has lost an outlet goes on copying the lanes that are quiet.
  list says up while every copier still has its lane of SRC, so one
  ended lane reads down for the whole fitting, and so does a tee with
  no copier yet. remove it and create it again.
- A copier is a server, as Pipes' hold is. It ignores HUP, so a tee
  outlives the terminal or shell it was made from. TERM, which remove
  sends, ends it.
- A copier opens its lane of SRC when it starts. A lane whose pipe has no
  writer blocks that open, so the copier waits there and list says down.
  create neither waits with it nor fails: it prints the tee either way,
  and list is where the caller finds out.
- remove kills the copiers where they stand, inside a write included, so
  a payload in flight can be left part-written on the outlets and short
  of its count. Nothing waits or drains: what is in flight is bytes.
- A copier that is copying is `tee(1)`: its outlet lanes are in argv,
  canonical, as list prints them, and its inlet lane is not, so
  `pkill -f` on a DST lane finds it and on the SRC path finds nothing.
  One still waiting on its lane of SRC has not reached that yet and
  carries create's own argv — SRC, SIDE and the DSTs as the caller
  spelled them, no lane numbers — so for that one the two searches
  trade places.

## In Claude Code

Every Bash call is a fresh shell. The copiers are their own processes,
so the tee outlives calls. Seats in one session share the container and
its /tmp; sessions do not, so no tee crosses that line.
