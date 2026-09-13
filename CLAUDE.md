# ICC-Merge

A Claude Code skill that merges ICC-Pipes pipes. That is the whole project.

Think of a wye fitting on a pipe. Water that comes in any of the inlets
goes out the one outlet. The fitting has no idea what the water is or
which inlet it came from. This skill is the fitting. Nothing more.

## Where this sits

    what the bytes mean        someone else's, above this
    slice, carry, reassemble   ICC-Frames, above this
    copy one pipe onto many    ICC-Tee, beside this
    copy many pipes onto one   this project
    the lane itself            ICC-Pipes, below this

Pipes does not know what is plugged into it. Frames does not know what
the bytes are. Merge knows neither: it copies lanes. Frames works through
a merge, one inlet at a time, because a merge copies every lane a side
writes, whole and in order, onto the same lane of a pipe with the same
lane count, and that is all Frames' rule needs. Two inlets writing at
once is two writers on one lane, which Pipes says interleave; whose turn
it is, is agreed above this, like which side you are. Merge never reads a
count or a frame.

## What this is

- A **merge**: N inlet pipes, one outlet pipe, one `cat(1)` per inlet per
  lane the chosen side writes, copying every byte from that inlet lane to
  the same lane of the outlet, in order, until removed.
- The skill covers creating, listing, and removing merges. Using one is
  writing an inlet as one side and reading the outlet as the other.
  Nothing else.

## What this is not

Out of scope. Do not build, stub, or "leave room for" any of these:

- **The wire.** Creating, listing, removing, or holding pipes. That is
  Pipes. Do not copy its scripts here, wrap them, or reimplement them.
- **The payload.** Slicing, counts, frames, reassembly. That is Frames.
  A merge never looks at the bytes.
- **The content.** What the bytes mean. Formats, protocols, framing,
  envelopes, timestamps, tags.
- **Fan-out.** Teeing, splitting, or copying one pipe onto many. That is
  Tee. Many inlets, one outlet, never the reverse. Do not copy Tee's
  scripts here, wrap them, or reimplement them. The way back from the
  outlet to the inlets is a tee, not a merge.
- Saying which inlet a byte came from. Tagging, labelling, ordering
  between inlets, or keeping one inlet's writes whole against another's.
  The outlet carries bytes. Who is talking is agreed outside.
- Filtering, transforming, or selecting what comes from each inlet.
  Every byte from every inlet reaches the outlet.
- Buffering, rate control, fairness, or backpressure beyond what cat(1)
  and the lanes already give.
- Anything Pipes already lists as out of scope for itself: routing,
  discovery, persistence, replay, liveness, auth, retries, queues, other
  transports, config, plugins, options.

If a request touches any of the above, stop and say it is out of scope.
Before adding anything, ask: is this the cable, is this what goes through
the cable, or is this a fitting that copies many cables onto one? Only
the last one belongs here.

## Depends on ICC-Pipes and ICC-Frames

A merge does not work without pipes. It never creates one. Tests get
pipes from the Pipes scripts in a sibling checkout, prove a payload
through the Frames scripts in another, and remove the pipes when done.
Do not vendor either into this repo. Tee is a sibling, not a dependency;
nothing here calls it.

Do not duplicate their documentation. If a fact about lanes is needed,
point at Pipes' SKILL.md; about payloads, at Frames'. If either is
missing a fact, that is a change there, not a paragraph here.

## Testing

A test harness is allowed **only to prove the merge works**: get pipes
from Pipes, merge two of them into the third, write a Frames payload
bigger than one lane holds into each inlet in turn, read it back whole
from the outlet each time, compare bytes, then plain bytes on one lane
from both inlets, remove the merge, see the pipes still up. The harness
must not grow into a client, protocol, or example app. If a test needs
more than a few lines of setup, the merge is too complicated, not the
test.

The harness is bash. Run it as `./tests/run.sh`. `sh tests/run.sh`
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
- **No abstraction until there are two real callers.**
- **Facts, not recipes.** SKILL.md states what cat(1) and the lanes do.
  It does not tell the caller how to wait, poll, frame, or take turns.
- **Never look at the bytes.** No option, header, or check in this repo
  may depend on what is in a lane.
- **Bash, and the shebang decides.** Every script here is bash and says so
  on its first line. Run one by its path and let that line choose the
  interpreter. Never reach for `sh script` or `bash script`: that overrides
  what the file declares, and a script that runs today only because the
  caller forced dash on it will break the day it uses anything bash has.

## Layout

```
.claude/skills/icc-merge/SKILL.md     the skill definition Claude Code loads
.claude/skills/icc-merge/scripts/     create, list, remove. One script each.
tests/                                the minimal harness described above
```

Do not add directories without a reason that fits the scope above.
