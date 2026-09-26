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
is a number. Who holds it is agreed outside this skill, like whose desk
a cable runs to. The parent, when it is in on it, is seat p.

    /tmp/icc-patch-XXXXXXXX/patch    SHAPE N LANES DEPTH, then one line per end
    /tmp/icc-patch-XXXXXXXX/made     DIR SCRIPTS per pipe and fitting, in order

## Operations

    scripts/create SHAPE N [LANES [DEPTH]]
                                    make the pipes and fittings SHAPE needs
                                    over N seats, LANES lanes each (even,
                                    default 2), every cable a seat reads
                                    through a fitting DEPTH pipes in
                                    series (default 1), print the patch's
                                    directory
    scripts/list                    one line per patch: DIR up|down SHAPE N
                                    LANES DEPTH
    scripts/remove DIR              remove the fittings, then the pipes,
                                    then DIR

create runs icc-pipes', icc-tee' and icc-merge' create scripts from
beside this one, `../../icc-pipes/scripts` and so on in the same skills
directory. There is nothing to configure and nothing to set.
remove runs the remove scripts create used. If a piece is missing,
create makes nothing and says which.

The scripts source icc-lib's shared functions from beside this skill,
`../../icc-lib/scripts/lib` in the same skills directory, so icc-lib has
to be installed with it.

## Shapes

    star     seat i shares a pipe with seat p, i on side 0, p on side 1.
             Nothing joins the seats to each other
    ring     seat i shares a pipe with seat i+1, i on side 0, i+1 on
             side 1, around the end back to 0
    mesh     a tee per seat. Every seat writes one end into its own tee,
             and the tee hands it to a read end of its own at every
             other seat, so a seat holds its write end and one read end
             per other seat, and nothing comes back to the writer. mesh
             2 collapses to one pipe and has no tee
    ring-p   ring, and each hop is a tee: one outlet to the next seat,
             one to a merge that seat p reads. p writes one end, and a
             tee hands it to a read end of its own at every seat, so a
             seat holds three ends: its write end, a read end from the
             seat before it, and a read end from p
    mesh-p   mesh, and every seat's tee hands what it writes to a merge
             too, whose cable is p's alone. p holds that one read end
             and writes nothing

These are the shapes there are. CLAUDE.md says how to add one.

N counts seats other than p. Fewer seats, fewer cables, by the shape
alone: a fitting with one end on a side is no fitting. mesh 2 is one
pipe, and so is mesh-p 1, one seat with its parent, and so is star 1.
ring 2 is mesh 2. ring 1 is one pipe with seat 0 on both ends. mesh 1 is
no pipe. ring-p 1 is seat 0's hop tee round to itself, and a pipe it
shares with p. Where a shape collapses to one pipe the two seats share
it, and each writes and reads there: the lower numbered seat holds side
0 and the other side 1, p counting as the higher, except on a ring-p 1,
where the end p holds is the one p writes, so p holds side 0. ring 1 has
no second seat: seat 0 holds both sides, and what it writes on one it
reads on the other. On the rest a seat's own words do not come back to
it, since there is no tee to hand them round.

DEPTH is how many pipes in series a cable a seat reads through a
fitting is: a tee's to a seat, and on a ring-p a merge's to p and, on a
ring-p 1, the hop tee's to p. Each pipe after the first is a one-outlet
tee from the one before it, lane for lane, so the cable carries one way:
what goes into the first pipe comes out of the last, where the seat
holds it, and the map names that pipe, as it would the one pipe at
DEPTH 1. Depth is room for what waits on a seat that has not read yet.
p's cable from a mesh-p's merge carries what all N seats write, so it
is N times DEPTH. A cable a fitting reads, a seat's into a tee and a
tee's into a merge, keeps moving, and is one pipe. So is a pipe two
seats share, the one that is the whole of a star's cable, a ring's, a
mesh 2 or a mesh-p 1, whatever DEPTH is: it carries both ways, and a
tee carries one.

## The map

After the first line, one line per end a seat holds, and one for every
pipe no seat holds at all:

    SEAT SIDE DIR PEERS

Seat SEAT holds side SIDE of the pipe at DIR. PEERS is the seats on the
other side, comma separated. Pipes says what a side writes and reads.

SEAT and PEERS are both `-` on a pipe that joins two fittings and
nothing else. Nobody holds either side of it, and SIDE names the free
one. A mesh-p and a ring-p have one per seat, between that seat's tee
and p's merge. At a DEPTH past 1, every pipe of a cable but the one a
seat holds is one too.
There is nothing to hold and nothing to do with such a line. It is
there so the map names every pipe the shape made, and remove takes
those pipes with the rest.

- A DIR on two seats' lines is a pipe those two share: what each writes
  there reaches the other and what it reads there came from the other,
  both ways. On a star every end is one of these, so p holds one end per
  seat and knows which seat it is talking to. ring 1 is the one shape
  where both lines are the same seat's: seat 0 holds both sides.
- On a mesh of three or more, or a mesh-p of two or more, a seat holds
  one read end per other seat, with that seat alone in its PEERS, so
  what it reads there came from that seat and no other. A seat is in
  its own PEERS only on a ring 1 and a ring-p 1, the two shapes where
  its own words come back.
- A DIR on one line only is through a fitting, and goes one way. A write
  end, side 0, sends to PEERS and reads nothing. A read end, side 1,
  receives from PEERS and sends nowhere. Tee's and Merge's SKILL.md say
  why. No pipe a seat holds has two writers on it, in any shape, so such a
  line is the whole of it: two names, both ways; one name, one way. A
  merge's outlet does have two, one per inlet, and no seat holds it, so
  its line names none.

    grep '^3 ' "$pPatchDir/patch"                  every end seat 3 holds

    pPatchDir=$(scripts/create mesh 4 6)
    # seat 0's write end
    pWriteEnd=$(awk '$1==0 && $2==0 {print $3}' "$pPatchDir/patch")
    .../icc-frames/scripts/write "$pWriteEnd" 0 < photo.jpg
    # seat 2's read end from seat 0
    pReadEnd=$(awk '$1==2 && $2==1 && $4=="0" {print $3}' \
      "$pPatchDir/patch")
    timeout 5 .../icc-frames/scripts/read "$pReadEnd" 1 > photo.jpg

## Facts

- A patch is the sum of its parts. Every fact in Pipes' SKILL.md holds
  for every end, and every fact in Tee's and Merge's for every copy. The
  bay adds nothing to them.
- On a read end with more than one PEER, nothing says which one a byte
  came from, and two writing at once interleave, as Pipes, Tee and Merge
  say. Whose turn it is, is agreed above this skill.
- Where writes meet is the merge seat p reads on a mesh-p or a ring-p.
  Merge says when two seats writing at once come out each whole there
  and when they interleave, and nowhere else do two writers share a
  pipe. A star and a ring have no fittings, and a mesh no merge: every
  read end on a mesh has one writer, and nothing meets.
- Nothing a seat writes comes back to it through a fitting, and nothing
  p writes comes back to p, except on a ring-p 1, where the hop tee goes
  round to the one seat there is. On a mesh each read end carries one
  writer's words in the order that writer wrote them. Which of two
  writers reaches a seat first, and whether two seats see them in the
  same order, nothing says.
- Whose turn it is, and whatever the seats leave in DIR to agree it, is
  theirs; remove takes DIR whole.
- Through fittings, a seat that never reads stalls every writer once its
  end fills. Read every end, or keep the payload inside one. How much
  that is, is how many pipes lie between a write end and a read end,
  which only the bay knows: a star or a ring one, a ring-p hop two, a
  mesh of three or more two and three to p on a mesh-p, and a shape
  that collapsed to one pipe one, each cable a seat reads through a
  fitting counting DEPTH, and p's from a mesh-p's merge N times that.
  What one pipe holds is Pipes' fact, and Tee's and Merge's SKILL.md say
  what a fitting adds; each joint in a cable is a tee, and holds what
  one does. It is not one number: measured on a mesh 3, 132K went every
  time, 136K went both ways on different runs, and 140K waited every
  time, with nobody reading. A tee waits on its fullest outlet, so for no
  writer to wait on a seat that has not read yet, that seat's cable from
  the tee has to hold all that is written to it in the meantime. A lane
  is 16 pages deep, and a pipe in series adds 16 more and the tee
  between them one: measured, 16, 33, 50 and 67 blocks of 4096 went
  into one lane of 1, 2, 3 and 4 pipes in series before the next waited.
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
