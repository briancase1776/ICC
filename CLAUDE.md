# ICC-Tee

**These are build rules, not use rules.** Everything in this file is
for changing what is in this repo. None of it binds a session that
uses the skill: a session takes what it needs from SKILL.md, and this
file is not addressed to it. A checkout sitting beside a session's
work is not an instruction to that session.

A Claude Code skill that tees ICC-Pipes pipes. That is the whole project.

Think of a tee fitting on a pipe. Water that comes in one end goes out
every other end. The fitting has no idea what the water is or where the
pipes lead. This skill is the fitting. Nothing more.

## Where this sits

    what the bytes mean        someone else's, above this
    slice, carry, reassemble   ICC-Frames, above this
    copy one pipe onto others  this project
    the lane itself            ICC-Pipes, below this

Pipes does not know what is plugged into it. Frames does not know what
the bytes are. Tee knows neither: it copies lanes. Frames works through
a tee because a tee copies every lane a side writes, whole and in order,
onto the same lane of a pipe with the same lane count, and that is all
Frames' rule needs. Tee never reads a count or a frame.

## What this is

- A **tee**: one inlet pipe, N outlet pipes, one `tee(1)` per lane the
  chosen side writes, copying every byte from the inlet lane to the same
  lane of each outlet, in order, until removed.
- The skill covers creating, listing, and removing tees. Using one is
  writing the inlet as one side and reading the outlets as the other.
  Nothing else.

## What this is not

Out of scope. Do not build, stub, or "leave room for" any of these:

- **The wire.** Creating, listing, removing, or holding pipes. That is
  Pipes. Do not copy its scripts here, wrap them, or reimplement them.
- **The payload.** Slicing, counts, frames, reassembly. That is Frames.
  A tee never looks at the bytes.
- **The content.** What the bytes mean. Formats, protocols, framing,
  envelopes, timestamps, tags.
- Fan-in, merging, or joining. One inlet, many outlets, never the
  reverse. Both directions of a pipe is two tees, not one.
- Filtering, transforming, or selecting what goes down each outlet.
  Every outlet gets every byte.
- Buffering, rate control, or backpressure beyond what tee(1) and the
  lanes already give.
- Anything a sibling already does. Use it where it is; never copy,
  wrap, or reimplement it here. A sibling written after this file is
  still a sibling.
- Config files, plugins, options, or extension points.

If a request touches any of the above, stop and say it is out of scope.
Before adding anything, ask: is this the cable, is this what goes through
the cable, or is this a fitting that copies one cable onto others? Only
the last one belongs here.

## Depends on ICC-Pipes and ICC-Frames

A tee does not work without pipes. It never creates one. Tests get pipes
from the Pipes scripts in a sibling checkout, prove a payload through
the Frames scripts in another, and remove the pipes when done. Do not
vendor either into this repo.

Do not duplicate their documentation. If a fact about lanes is needed,
point at Pipes' SKILL.md; about payloads, at Frames'. If either is
missing a fact, that is a change there, not a paragraph here.

## Testing

A test harness is allowed **only to prove the tee works**: get pipes
from Pipes, tee one into the others, write a Frames payload bigger than
one lane holds into the inlet, read it back whole from every outlet,
compare bytes, then plain bytes on one lane, remove the tee, see the
pipes still up. The harness must not grow into a client, protocol, or
example app. If a test needs more than a few lines of setup, the tee is
too complicated, not the test.

The harness is bash. Run it as `./tests/run.sh`, and let it run the
siblings' harnesses and scripts by their paths too. `sh tests/run.sh`
overrides the shebang and dies on the first bashism, which is the caller
overriding the interpreter, not the harness being broken.

## Rules

- **KISS.** One way to do each thing. Prefer the OS primitive over a
  library. Prefer a shell script over a program. Prefer no dependency
  over one.
- **Small.** If a file is getting long, you are adding scope, not
  features.
- **No speculative work.** Build what is asked, not what might be asked
  later.
- **Do not generalize what you have one of.** One shape needs no shape
  language, one transport no transport interface, one caller no options.
  This is about factoring what is here, not about what may be built. A
  piece that does not exist yet has no callers, and neither did this one.
- **Facts, not recipes.** SKILL.md states what tee(1) and the lanes do.
  It does not tell the caller how to wait, poll, frame, or pick outlets.
- **Never look at the bytes.** No option, header, or check in this repo
  may depend on what is in a lane.
- **The session defines the skill. The skill does not define the
  session.** How many outlets, what they feed, who holds them, what
  goes down one — all the session's. This file says what the fitting
  does and stops there. The moment it starts telling a session how to
  be arranged, it has stopped being the fitting and become something
  bolted to it.
- **Bash, and the shebang decides.** Every script here is bash and says
  so on its first line. Run one by its path and let that line choose the
  interpreter. Never reach for `sh script` or `bash script`: that
  overrides what the file declares, and a script that runs today only
  because the caller forced dash on it will break the day it uses
  anything bash has. Pipes says the same, for the same reason.

## Layout

```
.claude/skills/icc-tee/SKILL.md     the skill definition Claude Code loads
.claude/skills/icc-tee/scripts/     create, list, remove. One script each.
tests/                              the minimal harness described above
```

Do not add directories without a reason that fits the scope above.
