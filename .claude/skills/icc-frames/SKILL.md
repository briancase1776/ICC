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
  lane the side writes.
- Then the payload in frames of PIPE_BUF bytes, the last one shorter.
  Frame k goes on the k-th lane the side writes, round-robin, lane order.
- Read takes the count, then frame k from the same lane, never skipping,
  until it has that many bytes.

That count is the only thing Frames adds. Bytes in, the same bytes out.

## Facts

- Every lane opens with `<>`. Nothing here blocks on open.
- A frame is at most PIPE_BUF so it lands whole, and fits a lane even
  when the kernel has shrunk its buffer.
- Write returns with nobody reading as long as the payload fits in
  flight: the lanes one side writes, times what each holds. Bigger than
  that, write waits for read. Pipes' SKILL.md has the numbers.
- Read waits on an empty lane. Bound the call with `timeout`, as Pipes
  says. A read that stops halfway leaves the rest on the wire.
- Two lanes is one straw each way and the same script.
