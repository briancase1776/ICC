# ICC-Patch

A Claude Code skill that patches ICC-Pipes pipes, ICC-Tee tees and
ICC-Merge merges into a shape. That is the whole project.

Think of a patch bay. A box of cables and fittings, a row of seats, and a
plan on paper: seat 0 to seat 1, seat 1 to seat 2, and so on around. The
bay pushes the plugs in and hands each seat the plan. It has no idea what
goes down the cables. This skill is the bay. Nothing more.

## Where this sits

    what the bytes mean                someone else's, above this
    slice, carry, reassemble           ICC-Frames, beside this: it works
                                       any end the bay hands out
    plug pipes and fittings into a shape   this project
    copy one pipe onto many            ICC-Tee, below this
    copy many pipes onto one           ICC-Merge, below this
    the lane itself                    ICC-Pipes, below this

Pipes does not know what is plugged into it. Tee and Merge copy lanes.
Frames does not know what the bytes are. The bay knows none of that: it
runs their create scripts, in a shape, and writes down which end went to
which seat.

## What this is

- A **patch**: the pipes, tees and merges one shape needs over N seats,
  made by their own skills, and a **map** saying which end each seat
  holds and which seats are on the other side of it.
- The shapes are star, and ring and mesh each with or without the
  parent in on it. A star is a pipe from each seat to the parent and
  nothing between the seats. A mesh is a merge and a tee in the middle.
  A ring is a pipe from each seat to the next; with the parent in, each
  hop is a tee, the parent reads one merge of them all and writes one
  tee to them all. Five shapes. Fewer seats means fewer cables, by the
  shape alone: two seats on a mesh is one pipe, one seat with its parent
  is one pipe.
- The skill covers creating, listing, and removing patches. Using one is
  reading the map and holding the ends it names. Nothing else.

## What this is not

Out of scope. Do not build, stub, or "leave room for" any of these:

- **The wire.** Making, holding, or removing a pipe. That is Pipes. The
  bay runs Pipes' scripts; it never copies or reimplements them.
- **The fittings.** Copying lanes, one pipe onto many or many onto one.
  That is Tee and Merge. Same rule.
- **The payload.** Slicing, counts, frames. That is Frames.
- **The content.** What the bytes mean. Formats, protocols, envelopes.
- **Who sits where.** Which Claude is seat 3, how it learns that, how it
  finds the map. Discovery, registries, naming.
- **What a seat does.** Sending, waiting, polling, forwarding around a
  ring, hop counts, tokens, turn taking. A seat holds ends; what it does
  with them is its business.
- **New shapes on demand.** A shape is a few lines in create. Shape
  files, graph input, a wiring language. No.
- Anything Pipes and Tee list as out of scope for themselves: routing,
  persistence, replay, liveness, auth, retries, queues, other transports,
  config, plugins, options.

If a request touches any of the above, stop and say it is out of scope.
Before adding anything, ask: is this a cable, a fitting, what goes through
them, or the bay that plugs them together in a shape and writes down where
each plug went? Only the last one belongs here.

## Depends on ICC-Pipes, ICC-Tee and ICC-Merge, proven through ICC-Frames

The bay makes nothing but the map. create runs Pipes', Tee's and Merge's
create scripts from sibling checkouts, `$ICC_PIPES`, `$ICC_TEE` and
`$ICC_MERGE`, by default `../ICC-Pipes`, `../ICC-Tee` and `../ICC-Merge`
beside this repo, and remove runs their remove scripts. Tests push a
Frames payload through what the bay made, from another sibling. Do not
vendor any of them into this repo.

Do not duplicate their documentation. A fact about lanes is Pipes'; about
copies, Tee's and Merge's; about payloads, Frames'. If one of them is
missing a fact, that is a change there, not a paragraph here.

## Testing

A test harness is allowed **only to prove the bay works**: make each
shape, see the map name the cables the shape says and no more, push a
Frames payload bigger than one lane holds from a seat to its peers and
read it back whole at every one, plain bytes back the other way, remove
it, see nothing left. The harness must not grow into a client, protocol,
or example app. If a test needs more than a few lines of setup, the bay
is too complicated, not the test.

The harness is bash. Run it as `./tests/run.sh` and let the shebang pick
the interpreter. `sh tests/run.sh` overrides it, and so does zsh, or any
other shell put in front of the path. Whether it happens to survive that
today is not the point and is not promised: bash is the only shell this
repo guarantees anything under.

## Rules

- **KISS.** One way to do each thing. Prefer the OS primitive over a
  library. Prefer a shell script over a program. Prefer no dependency
  over one.
- **Small.** If a file is getting long, you are adding scope, not
  features.
- **No speculative work.** Build what is asked, not what might be asked
  later.
- **No abstraction until there are two real callers.**
- **Facts, not recipes.** SKILL.md says what the map means. It does not
  tell a seat when to write, how to wait, or what to do with what it
  reads.
- **The shape decides the cables.** Nothing else does. No knob picks a
  fitting over a pipe; a fitting with one end on a side is no fitting.
- **Never look at the bytes.** No script in the skill reads a lane:
  not create, not list, not remove. The harness does, because proving
  the bay works means pushing a payload through it.
- **Bash, and the shebang decides.** Every script here is bash and says
  so on its first line. Run one by its path and let that line choose the
  interpreter. Never reach for `sh script`, `zsh script` or even
  `bash script`: that overrides what the file declares, and a script
  that runs today only because the caller forced another shell on it
  will break the day it uses anything that shell has not got. Only bash
  is guaranteed, which is simpler than guaranteeing several. The same
  goes for the pieces the bay runs: create and remove call Pipes', Tee's
  and Merge's scripts by path, and their own first lines pick their
  interpreters.

## Layout

```
.claude/skills/icc-patch/SKILL.md     the skill definition Claude Code loads
.claude/skills/icc-patch/scripts/     create, list, remove. One script each.
tests/                                the minimal harness described above
```

Do not add directories without a reason that fits the scope above.
