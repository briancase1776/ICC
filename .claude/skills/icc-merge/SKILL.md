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
    /tmp/icc-merge-XXXXXXXX/pid    the copier's

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

The scripts source icc-lib's shared functions from beside this skill,
`../../icc-lib/scripts/lib` in the same skills directory, so icc-lib has
to be installed with it.

## Facts about the merge

One copier per merge, a shell of its own, holds every lane it moves: the
lanes SIDE writes of each SRC for reading, the same lanes of DST for
writing. It goes round the SRCs in the order create was given them and
drains each before the next: for each lane with bytes waiting it forks
one `dd(1)` at `bs=4096`, which moves block after block, up to 16, and
stops at the first read that finds the lane empty. These are properties
of that and of the lanes. The skill adds nothing to them.

- A merge copies one direction of each inlet. The lanes the other side
  writes are not touched. Nothing goes back through it; the way back
  from the outlet to the inlets would be a tee, not this.
- The merge is the reader of every lane it copies. Bytes it takes are
  gone from that inlet and exist only on the outlet. Read the outlet.
- Every inlet lane is copied whole, in order, onto the same lane number
  of the outlet, and every pipe has the same lane count. That is all
  icc-frames' rule needs, so a Frames write into one inlet while the
  others are quiet is a Frames read on the outlet.
- One inlet at a time. While any lane of an inlet has bytes waiting, and
  until a hundredth of a second has passed with none, the copier takes
  from that inlet and no other, so what one writer puts on without
  pausing that long comes out of the outlet whole, with no other inlet's
  bytes inside it, even when inlets write at once. A copier as quick as
  its writer finds the inlet empty between two of its writes: the
  hundredth is what keeps the writer's turn, and every inlet that has
  just spoken adds it to the wait of the next. Forty blocks two
  thousandths of a second apart, with another inlet waiting, came out
  together in eight runs of eight; looked at once and not again, they
  were cut three times of three. Empty that long is all the copier sees:
  it does not know where anything ends, so a writer that pauses longer
  partway through lets another inlet in. One dd from a file does not pause that
  long, and a writer blocked on a full inlet has not paused at all; the
  inlet is full. Frames' write
  puts each frame on with a process of its own, and between two of them
  the inlet can be empty, so a Frames payload that spills into a second
  frame still needs the others quiet. One that fits in one frame, a page
  less its count line, is one write and comes through whole either way.
- Each block is read from an inlet lane and written to the outlet lane
  before the next is read, and a block is at most `bs`, which is
  PIPE_BUF, so every write lands whole. Pipes' SKILL.md has the number,
  and says why the copier is not cat. An outlet lane that is full and
  not being drained stalls the copier, and with it every inlet. Nothing
  is kept between the two lanes but the one block in hand. A lane's turn
  is at most 16 blocks, a lane's 64K in pages, so no turn gives an outlet
  lane more than it holds, and the copier goes on to the next lane before
  it waits on a full one. A copier that took all a lane had in one turn
  hung on a Frames payload of 262144 bytes put on six-lane pipes while it
  was stopped, five times of five: it filled one outlet lane and waited
  there with the others empty.
- When no inlet has anything, the copier waits by a timed read of a pipe
  it holds both ends of, a twentieth of a second at a time, so a payload
  that arrives at a quiet merge can wait that long before it moves.
  Nothing is forked to wait, nor for the hundredth of a second spent on
  an inlet the copier has just moved from. A dd is forked for each turn,
  not for each block: 4 MiB put on by one dd from a file took 64, where
  a dd for every block took 1024, and crossed in a median of 192 ms
  where that took 2322, with no load added.
- What a write into an inlet can leave on the wire and walk away from is
  that inlet's lanes plus, while the copier can move, the outlet's lanes,
  which every inlet shares. Pipes' SKILL.md has the numbers.
- The outlet carries every inlet, so a reader that falls behind on it
  falls behind on all of them. For no writer to wait on that reader,
  the outlet and whatever lies past it have to hold all that every
  inlet writes in the meantime: N inlets that each write as much, N
  times what one does.
- create opens every lane the copier uses itself, and the copier
  inherits them. A pipe whose hold is dead blocks that open, so it blocks
  create, where the caller's bound reaches it; Pipes says what a dead
  hold does to an open.
- remove stops the copier where it stands, kills the dd it has running,
  if any, and then the copier. A block that dd had taken off an inlet and
  not yet written is lost, and what it had not taken stays on the inlet,
  so a payload crossing the merge just then
  comes up short of its count; Frames says what that costs. The pipes on
  either end are untouched.
- The copier ends when an inlet lane it reads hits EOF or a write to the
  outlet fails. Held lanes never do either, so the merge runs until
  removed or until a pipe on either end is removed. Then list says down.
  remove it and create it again.
- The copier is a server, as Pipes' hold is. It ignores HUP, and so does
  every dd it forks, so a merge outlives the terminal or shell it was
  made from. TERM, which remove sends, ends it.
- One inlet, one merge. create refuses the same inlet twice on its own
  command line; it does not know what another merge is doing, and two
  merges from one inlet are two readers of one lane, which race as Pipes
  says two readers do. What one takes the other never sees.
- list says up while the copier still has its mark, and down otherwise:
  a merge whose copier has not started yet, or has ended, or whose pipe
  has been removed, is down.
- The copier's fd 0 is the first SRC's first lane it reads, spelled
  canonically, the way list prints it. list and remove know the copier by
  that fd, the way Pipes finds a holder. Its argv is create's, spelled as
  the caller spelled it, so `pkill -f` on a path finds it only in that
  spelling. The dd it forks for each turn has no path in its argv.
- The copier's stdout and stderr go nowhere. The outlet carries what the
  inlets wrote and nothing else. What dd says is read by the copier for
  the read that found a lane empty and the summary that says an inlet
  has ended, and goes no further. Both are GNU dd's own words with
  `LC_ALL=C`, and `iflag=nonblock` is GNU's: a dd that says an empty lane
  some other way ends the merge at its first turn.
- `iflag=nonblock` sets O_NONBLOCK on the inlet lane's open file and
  leaves it set. That open file is the one create opened, which only the
  copier and its dd's hold, so no writer's end and no hold changes, and
  the copier only looks at a lane with `read -t 0`, which does not mind.

## In Claude Code

Every Bash call is a fresh shell. The copier is its own process,
so the merge outlives calls. Everything that shares /tmp can share a
merge: every subagent of a session, and every session run on one
machine. Sessions in separate containers share no /tmp, so no merge
crosses that line.
