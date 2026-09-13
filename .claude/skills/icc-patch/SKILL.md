---
name: icc-patch
description: >-
  Patch icc-pipes pipes, icc-tee tees and icc-merge merges into a star,
  a ring or a mesh over N seats, with or without a parent in on it, and
  hand every seat a map of the ends it holds. The bay makes nothing but
  the map. What goes down the cables, and who sits where, is the
  caller's business.
---

# icc-patch

A patch is pipes that icc-pipes made, tees that icc-tee made and merges
that icc-merge made, plugged into a shape over N seats, and a map. A seat
is a number. Which Claude holds it is agreed outside this skill, like
whose desk a cable runs to. The parent, when it is in on it, is seat p.

    /tmp/icc-patch-XXXXXXXX/patch    SHAPE N LANES, then one line per end
    /tmp/icc-patch-XXXXXXXX/made     SCRIPTS DIR per pipe and fitting, in order
    /tmp/icc-patch-XXXXXXXX/lock     while a seat holds the wire; see Facts

## Operations

    scripts/create SHAPE N [LANES]  make the pipes and fittings SHAPE needs
                                    over N seats, LANES lanes each (even,
                                    default 2), print the patch's directory
    scripts/list                    one line per patch: DIR up|down SHAPE N LANES
    scripts/remove DIR              remove the fittings, then the pipes,
                                    then DIR

create runs the create scripts in `$ICC_PIPES`, `$ICC_TEE` and
`$ICC_MERGE`, by default `../ICC-Pipes`, `../ICC-Tee` and `../ICC-Merge`
beside this repo. remove runs the remove scripts create used. If a piece
is missing, create makes nothing.

## Shapes

    star     seat i shares a pipe with seat p, i on side 0, p on side 1.
             Nothing joins the seats to each other
    ring     seat i shares a pipe with seat i+1, i on side 0, i+1 on
             side 1, around the end back to 0
    mesh     a merge and a tee in the middle. Every seat writes one end
             into the merge; the tee hands what comes out to every
             seat's read end, the writer's too
    ring-p   ring, and each hop is a tee: one outlet to the next seat,
             one to a merge that seat p reads. p writes one end, and a
             tee hands it to every seat's read end
    mesh-p   mesh, with seat p on it like any other

N counts seats other than p. Fewer seats, fewer cables, by the shape
alone: a fitting with one end on a side is no fitting. mesh 2 is one
pipe, and so is mesh-p 1, one seat with its parent, and so is star 1.
ring 2 is mesh 2. ring 1 is one pipe with seat 0 on both ends. mesh 1 is
no pipe.

## The map

After the first line, one line per end a seat holds:

    SEAT SIDE DIR PEERS

Seat SEAT holds side SIDE of the pipe at DIR. PEERS is the seats on the
other side, comma separated. Pipes says what a side writes and reads.

- On a pipe two seats share, what SEAT writes there reaches PEERS and
  what it reads there came from PEERS. Both ways. On a star every end is
  one of these, so p holds one end per seat and knows which seat it is
  talking to.
- Through fittings, an end goes one way. A write end, side 0, sends to
  PEERS and reads nothing. A read end, side 1, receives from PEERS and
  sends nowhere. Tee's and Merge's SKILL.md say why.

    grep '^3 ' "$x/patch"                          every end seat 3 holds

    x=$(scripts/create mesh 4 6)
    e=$(awk '$1==0 && $2==0 {print $3}' "$x/patch")  # seat 0's write end
    .../icc-frames/scripts/write "$e" 0 < photo.jpg
    e=$(awk '$1==2 && $2==1 {print $3}' "$x/patch")  # seat 2's read end
    timeout 5 .../icc-frames/scripts/read "$e" 1 > photo.jpg

## Facts

- A patch is the sum of its parts. Every fact in Pipes' SKILL.md holds
  for every end, and every fact in Tee's and Merge's for every copy. The
  bay adds nothing to them.
- On a read end with more than one PEER, nothing says which one a byte
  came from, and two writing at once interleave, as Pipes, Tee and Merge
  say. Whose turn it is, is agreed above this skill.
- On a mesh or a ring-p every write meets every other write somewhere,
  so the patch has one lock: `DIR/lock`, in the patch's directory. A seat
  that wants the wire to itself makes it with mkdir(1) before it writes
  and removes it with rmdir(1) after. mkdir is atomic: of two that try
  at once, one gets it and the other fails. Nothing here looks at it;
  remove deletes it with the rest. What the write left on the wire, as
  Tee and Merge say, is still moving when it returns; the lock does not
  wait for that. On a mesh it is past the merge once its end is back at
  the writer's own read end: the tee puts each chunk on every outlet
  before it reads the next, as Tee says, so nothing written after it
  can come before it at any seat. A star and a ring have no fittings and
  nothing to lock.
- Through fittings, a seat that never reads stalls every writer once its
  end fills. Read every end, or keep the payload inside one. Tee's and
  Merge's SKILL.md have the numbers.
- A seat may sit in more than one patch. A ring and a mesh over the same
  seats is two patches.
- list says up when every pipe and fitting says up. If one is down, the
  patch is down; remove it and create it again.
- Nothing holds a patch open. Its pipes and fittings do their own
  holding. Remove one of them by hand and list says down.
- The scripts are bash, not sh. Run one by its path and let its first
  line pick the interpreter; `sh scripts/create` overrides it.

## In Claude Code

Every Bash call is a fresh shell. The pipes and fittings are their own
processes, as their skills say, so a patch outlives calls. Seats in one
session share the container and its /tmp; sessions do not, so no patch
crosses that line.
