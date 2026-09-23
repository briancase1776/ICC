---
name: icc-merge
description: >-
  Merge icc-pipes pipes. Copy what one side writes into any of several
  pipes onto the same lanes of one pipe, byte for byte, in order per
  inlet, until removed. Plain bytes and icc-frames payloads alike come
  out of the outlet as they went in, one inlet at a time. What the bytes
  are, which inlet is talking, and why they are merged, is the caller's
  business.
---

# icc-merge

A merge is N inlet pipes and one outlet pipe. Every byte SIDE writes into
a lane of any inlet comes out of the same lane of the outlet, in the
order it went in on that inlet. It is a fitting: it joins pipes that
icc-pipes already made and makes nothing else. Pipes says what a lane is
and which lanes each side writes; see its SKILL.md.

    /tmp/icc-merge-XXXXXXXX/merge  DST, SIDE, then each SRC, one per line
    /tmp/icc-merge-XXXXXXXX/pid    one copier per lane SIDE writes per SRC,
                                   lane order, then SRC order within a lane

## Operations

    scripts/create DST SIDE SRC...  copy what SIDE writes into every SRC
                                    onto DST, print the merge's directory.
                                    Every pipe must exist and have the
                                    same even lane count, no inlet is the
                                    outlet, and none is given twice.
    scripts/list                    one line per merge: DIR up|down DST SIDE SRC...
    scripts/remove DIR              stop the merge, delete DIR. The pipes on
                                    either end are left as they were.

SIDE is 0 or 1, as Pipes says: side 0 writes the even lanes, side 1 the
odd ones. To use a merge, write an inlet as SIDE and read the outlet as
the other side. There is nothing else to do.

    pPipeA=$(.../icc-pipes/scripts/create 6)
    pPipeB=$(.../icc-pipes/scripts/create 6)
    pPipeC=$(.../icc-pipes/scripts/create 6)
    pMergeDir=$(scripts/create "$pPipeC" 0 "$pPipeA" "$pPipeB")
    .../icc-frames/scripts/write "$pPipeA" 0 < photo.jpg
    timeout 5 .../icc-frames/scripts/read "$pPipeC" 1 > photo.jpg

## Facts about the merge

Each lane SIDE writes, of each SRC, has its own `dd(1)` at `bs=4096`,
that lane of that SRC as its `if=` and that lane of DST as its stdout.
These are properties of that and of the lanes. The skill adds nothing to
them.

- A merge copies one direction of each inlet. The lanes the other side
  writes are not touched. Nothing goes back through it; the way back
  from the outlet to the inlets would be a tee, not this.
- The merge is the reader of every lane it copies. Bytes it takes are
  gone from that inlet and exist only on the outlet. Read the outlet.
- Every inlet lane is copied whole, in order, onto the same lane number
  of the outlet, and every pipe has the same lane count. That is all
  icc-frames' rule needs, so a Frames write into one inlet while the
  others are quiet is a Frames read on the outlet. A payload that fits
  in one frame, a page less its count line, goes over as one write, so
  those come through whole even when inlets write at once, as long as
  no more than a page waits on any one inlet: a copier reads up to a
  page of whatever is there, and more can be cut mid-payload. One that
  spills into a second frame needs the others quiet.
- The merge is one more writer on each outlet lane per inlet. Everything
  Pipes says of a writer holds for each. Between inlets nothing holds:
  a copier writes whatever one read of its inlet lane returned, and
  where that falls against another inlet's is not promised. Nothing on
  the outlet says which inlet a byte came from. Two inlets writing the
  same lane at once is two writers on one lane, as Pipes says.
- Each chunk read from an inlet lane is written to the outlet lane
  before the next chunk is read, and a chunk is at most `bs`, which is
  PIPE_BUF. Every write a copier makes therefore lands whole, so no
  inlet's chunk lands inside another's. Pipes' SKILL.md has the number,
  and says why the copier is not cat. An outlet lane that is full and
  not being drained stalls every copier writing to it, so that lane of
  every inlet stalls behind it once it fills. Nothing is kept between
  the two lanes.
- What a write into an inlet can leave on the wire and walk away from is
  that inlet's lanes plus, while its copiers can move, the outlet's
  lanes, which every inlet shares. Pipes' SKILL.md has the numbers.
- create opens each outlet lane itself and the copiers of that lane
  inherit it. An outlet whose hold is dead blocks that open, so it blocks
  create, where the caller's bound reaches it; Pipes says what a dead
  hold does to an open.
- remove kills the copiers where they stand. A chunk half written to the
  outlet stays half written, so a payload crossing the merge just then
  comes up short of its count; Frames says what that costs. The pipes on
  either end are untouched.
- A copier ends when its inlet lane hits EOF or a write to the outlet
  lane fails. Held lanes never do either, so the merge runs until removed
  or until a pipe on either end is removed. Then list says down. remove
  it and create it again.
- A copier is a server, as Pipes' hold is. It ignores HUP, so a merge
  outlives the terminal or shell it was made from. TERM, which remove
  sends, ends it.
- One inlet, one merge. create refuses the same inlet twice on its own
  command line; it does not know what another merge is doing, and two merges
  from one inlet are two copiers reading one lane, which race as Pipes says
  two readers do. What one takes the other never sees.
- list says up when every copier of a merge still has its inlet lane open,
  and down otherwise. It is all or nothing: one copier gone reads the same
  as all of them gone, and a merge whose copiers have not started yet, or
  whose pipe has been removed, is down.
- A copier is `dd(1)`. Its inlet lane is `if=` in its argv and, once it
  has opened it, on its fd 0, which is /dev/null until then; its outlet
  lane is its stdout and is never in its argv. Both are spelled
  canonically, the way list prints them, not the way the caller spelled
  them. `pkill -f` on a SRC path finds that inlet's copiers; on the DST
  path it finds nothing but a create that is still running. list and
  remove know a copier by that fd, the way Pipes finds a holder.
- A copier's stderr goes nowhere. The outlet carries what the inlets
  wrote and nothing else, so a diagnostic, dd's summary included, has no
  lane to go out on.

## In Claude Code

Every Bash call is a fresh shell. The copiers are their own processes,
so the merge outlives calls. Seats in one session share the container
and its /tmp; sessions do not, so no merge crosses that line.
