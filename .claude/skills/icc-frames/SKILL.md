---
name: icc-frames
description: >-
  Write something big down an icc-pipes pipe and read it back whole. Slices
  a payload into frames, spreads them over the lanes, reassembles them in
  order on the other end. What the bytes mean is the caller's business.
---

# icc-frames

Read and write for a pipe that icc-pipes made. Pipes says what a lane is
and which lanes each side writes; see its SKILL.md. Frames says how a
payload of any size goes down those lanes and comes back the same.

## Operations

    scripts/write DIR SIDE < bytes    slice stdin into frames, put them on
                                      the lanes SIDE writes
    scripts/read  DIR SIDE > bytes    take frames off the lanes SIDE reads,
                                      put them back together, print them

DIR is what Pipes' create printed. SIDE is 0 or 1: side 0 writes the even
lanes and reads the odd ones, side 1 the reverse, as Pipes says. Which
side you are is agreed outside this skill.

    d=$(.../icc-pipes/scripts/create 8)
    scripts/write "$d" 0 < photo.jpg          # side 0, one tool call
    timeout 5 scripts/read "$d" 1 > photo.jpg # side 1, another tool call

## The rule

Both ends follow it; nothing on the wire says it.

- The payload's byte count goes first, as a decimal line, on the first
  lane the side writes, and the head of the payload follows it into the
  same page. A pipe gives out whole pages, so a count on its own would
  take a page no frame could ever share. It is two writes and not one,
  the shell's then head's on one descriptor, and they share a page
  because nothing reads between them.
- Then the payload in frames of PIPE_BUF bytes. Frame 0 is short by what
  the count took, the last one is short by what is left, the rest are
  full. Frame k goes on the k-th lane the side writes, round-robin, lane
  order.
- Read takes the count and the rest of that first write, then frame k
  from the k-th lane, never skipping, until it has that many bytes.

That count is the only thing Frames adds. Bytes in, the same bytes out.

## Facts

- Every lane opens with `<>`. Nothing here blocks on open.
- A frame is at most PIPE_BUF so it lands whole, and fits a lane even
  when the kernel has shrunk its buffer. That every frame after the
  first is one write is true and not enforced: head -c writes what its
  read returned, as dd does, and what makes the read whole is that the
  count cannot go out until the payload is already in the chain. head -c
  and not dd on a lane because dd's `count=` counts reads and stops at
  a short one, and the spelling that would not, iflag=fullblock, is the
  one Pipes says never to add. No split has been seen in any trace
  taken, under load or idle. Nothing in the code forbids one.
- The hold, and not the lanes, is what this layer carries: n+1 times
  64K, n being the lanes this side writes. Write takes that much and
  then looks for one byte more; a byte there is a payload past the hold,
  refused before the count goes out, so nothing of it reaches a lane. A
  file and a pipe alike, since the byte after the last one that fitted
  says it either way.
- Read waits on an empty lane. Bound the call with `timeout`, as Pipes
  says. A read that stops halfway leaves the rest on the wire.
- Write holds the whole payload while it counts it, because the count
  goes in front. The hold is a chain of `dd bs=4096`, one per lane this
  side writes, and what it holds is the pipes between them and the two
  at its ends, about 64K apiece, and a page in each copier. dd and not
  cat, as Pipes says: cat's store is a size nobody chose, and the figure
  above is one this layer enforces. This project makes those pipes and
  never grows them, which is why that figure does not move with the
  wire.
- Under that figure a read decides between two regions. What a write can
  leave on the wire and walk away from is the lanes this side writes,
  what Pipes says a lane holds apiece, less the count line; past that it
  waits, and a read frees it, as far as the hold. Six default lanes:
  196601 returns with nobody reading, 196602 waits, 262144 round trips
  with a read draining, 262145 is refused.
- Where the hold stops is a number, not a band. The refusal enforces it
  instead of sampling a race, so the same size does the same thing every
  run: two lanes with a read draining, five runs each, 131071 and 131072
  went through every time and 131073 and 196608 were refused every time,
  the last two without a read being needed to tell. A write past it
  returns 1 and says so. It does not hang, and no read can or need free
  it.
- A lane's buffer can be grown as far as `/proc/sys/fs/pipe-max-size`
  and the size sticks for later openers. That moves the walk-away figure
  and nothing else. Six lanes grown to a megabyte each is sixteen times
  the wire and buys about 64K of it: nobody reading, 196602 and 262144
  return where they used to wait, and 262145 is refused as it was. The
  chain is not grown with them, so the ceiling does not move.
- `1<>` is dropped, silently, as an outer redirection on `$( )` or
  `>( )`. `1>` and `1>>` are not. A lane write wrapped in a command
  substitution therefore goes to the substitution's own pipe instead of
  the wire, and whoever is waiting for it waits for bytes nobody sent.
- Two lanes is one straw each way and the same script.
