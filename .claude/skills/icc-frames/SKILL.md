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
  lane the side writes, and the head of the payload goes out in the same
  write. A pipe gives out whole pages, so a count on its own would take
  a page no frame could ever share.
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
  when the kernel has shrunk its buffer.
- Write returns with nobody reading as long as the payload fits in
  flight: the lanes one side writes, times what each holds. Bigger than
  that, write waits for read, as far as the hold below allows. Pipes'
  SKILL.md has the numbers.
- Read waits on an empty lane. Bound the call with `timeout`, as Pipes
  says. A read that stops halfway leaves the rest on the wire.
- Write holds the whole payload while it counts it, because the count
  goes in front. The hold is a chain of cats, one per lane this side
  writes, and what it holds is the pipes between them and the two at
  its ends, about 64K apiece. With nobody reading, the lanes fill first
  and the hold never shows. With a read running the lanes stop being
  the limit and the hold becomes it.
- Where the hold stops is a band, not a number. It is a race between the
  chain draining and the lanes filling, so at the edge the same size
  goes through some runs and not others: on two lanes, five runs each,
  131072 went through five times and 196608 twice. Stay well inside it.
  Past it a write does not return, and a read cannot free it, because
  nothing reaches the lanes until the count does.
- That the hold never shows depends on a lane being 64K, since a cat
  holds more than that. A lane's buffer can be grown as far as
  `/proc/sys/fs/pipe-max-size` and the size sticks for later openers, so
  a wider buffer moves the limit here: with six lanes grown to a
  megabyte each, a write that could leave 2M on the wire and walk away
  leaves 512K. Nothing in this project can grow its own chain to match.
- Because nothing grows the chain, what the hold carries is the same number
  however wide the lanes are: n+1 times 64K, n being the lanes this side
  writes. Given a file, write knows the size before it makes anything and
  refuses one past that, saying both numbers. Given a pipe it cannot know,
  and there a payload past the hold still does not return.
- `1<>` is dropped, silently, as an outer redirection on `$( )` or
  `>( )`. `1>` and `1>>` are not. A lane write wrapped in a command
  substitution therefore goes to the substitution's own pipe instead of
  the wire, and whoever is waiting for it waits for bytes nobody sent.
- Two lanes is one straw each way and the same script.
