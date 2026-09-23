---
name: icc-pipes
description: >-
  Create, list, and remove named pipes between whoever holds their ends,
  in one container. Transport only. A pipe is an even number of lanes, each a FIFO
  going one way, held open so nothing blocks on open. What goes through it,
  and what it means, is the caller's business.
---

# icc-pipes

A pipe is a fresh directory holding N lanes, N even, each lane a FIFO
going one way, all kept open by one background process:

    /tmp/icc-pipes-XXXXXXXX/0
    /tmp/icc-pipes-XXXXXXXX/1
    ...
    /tmp/icc-pipes-XXXXXXXX/N-1
    /tmp/icc-pipes-XXXXXXXX/pid    the hold's process id, not a lane

`pid` is the only thing in there that is not a FIFO. list reads it to say
up or down, and remove reads it to know what to kill, so a glob of the
directory catches it and writing over it breaks both.

One side writes the even lanes and reads the odd ones. The other side
writes the odd lanes and reads the even ones. Lanes 0 and 1 are a pair,
2 and 3 are a pair, and so on; every pair is the same link over again.
Which side you are, and what any pair is for, is agreed outside this
skill, like which end of a cable you are holding. Whoever ran create
laid the cable; it need not hold either end.

## Operations

    scripts/create [N]     make a fresh pipe of N lanes (default 2), hold
                           every lane open, print its directory
    scripts/list           one line per pipe: DIR up|down
    scripts/remove DIR     drop the hold, delete the pipe

To attach, open the path. There is nothing else to do.

The scripts source icc-lib's shared functions from beside this skill,
`../../icc-lib/scripts/lib` in the same skills directory, so icc-lib has
to be installed with it.

## Bytes on, bytes off

A lane is a file. Move bytes with `dd bs=4096`. Do not use `cat`.

    # lane to lane
    dd if="$pSrc/0" of="$pDst/0" bs=4096 status=none
    # stdout to a lane
    printf '%s' "$osBytes" | dd of="$pDir/0" bs=4096 status=none
    # a lane to stdout
    timeout 1 dd if="$pDir/1" bs=4096 status=none

`bs=4096` is PIPE_BUF and the page both; `getconf PIPE_BUF /tmp` and
`getconf PAGESIZE` say so. Two things follow.

Every write dd makes is at most PIPE_BUF, so it lands whole and no
other writer's can land inside it. cat promises no such bound, so a
write of cat's can be torn.

dd writes exactly what each read returned, at once, and holds nothing
else. Fed a lane in 100-byte dribbles it reports `0+20 records in,
0+20 records out`: twenty short reads, twenty short writes, nothing
accumulated. cat holds whatever its read returned, so between two
lanes it is a third store whose size nobody chose. Why cat's varies
is not written here: that it varies was measured, the reason was
not.

That store is the chain's capacity. Two lanes joined by a copier with
nobody draining the far end: `dd bs=4096` takes 135168 bytes and
blocks at 139264, every run, which is the two lanes and one page. cat
takes 163840 in four runs of six and blocks in the other two. Only one
of them answers the same way twice.

Do not add `iflag=fullblock`. It makes dd wait for a whole block
before passing anything on: latency on a lane that dribbles, a stall
on one that stops.

One write under PIPE_BUF needs no copier at all.
`printf '%s' "$osBytes" > "$pDir/0"` is a single write and lands whole.

## Facts about the pipe

These are properties of a FIFO. The skill adds nothing to them. Where
Linux and POSIX differ, both are given; this skill is Linux.

- A write of at most PIPE_BUF bytes lands whole. Larger writes can
  interleave with another writer's. PIPE_BUF is 4096 on Linux; POSIX
  promises only 512. `getconf PIPE_BUF /tmp` says.
- Each lane buffers 64K on Linux; POSIX promises only PIPE_BUF. A write
  past the buffer blocks until someone reads. Lanes fill and drain
  independently, so N lanes is N times the bytes in flight. More lanes
  is more bandwidth, nothing else.
- A read on an empty lane blocks, and never sees EOF while the pipe is
  up, because the hold keeps a writer open. Bound every read (timeout,
  nonblocking) or the call hangs.
- A bounded read spends its whole bound. With no EOF the reader is still
  waiting when the bound runs out, so `timeout 1 dd` prints what it got
  and exits 124. That status is the bound, not a failure, and the read
  costs the bound every time.
- Bytes read are gone. Nothing is kept.
- Order holds within one lane and nowhere else.
- The hold opens every lane O_RDWR. On Linux that open never blocks.
  POSIX leaves it undefined.
- Because a lane is open both ways, nothing stops a side reading the
  lane it writes. A side that does takes its own bytes off the wire:
  no error here, and nothing at the peer's end to show they were taken.
  Which side writes which lane is agreed outside this skill, and nothing
  here checks it.
- The scripts are bash, not sh. dash cannot redirect a two-digit fd, so
  under sh create holds no lane past 6.
- The dd above is GNU. `status=none` is a coreutils extension; the
  portable spelling is `2>/dev/null`, which hides the message and not
  the exit status. `dd` itself, and `bs=`, are POSIX.
- The holder is `sleep infinity`. The pipe's path is in its open file
  descriptors, not its argv, so `pkill -f` on the path finds nothing
  but the shell that expanded it. Find a holder under /proc/PID/fd,
  as list does.
- If the hold dies (list says down), opens and writes can block.
  remove it and create it again.
- The hold is a server. It ignores HUP, as one run under nohup does, so
  a pipe outlives the terminal or shell it was made from. TERM, which
  remove sends, ends it.

## In Claude Code

Every Bash call is a fresh shell. The hold is its own process, so the
pipe outlives calls. A foreground read that does not return hangs the
tool call until the harness times it out.

Seats in one session share the container, so they share
/tmp. Sessions do not share a container; no pipe crosses
that line.
