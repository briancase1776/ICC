# ICC-Pipes

**These are build rules, not use rules.** Everything in this file is for
changing what is in this repo. None of it binds a session that uses the
skill: a session takes what it needs from SKILL.md, and this file is not
addressed to it. A checkout sitting beside a session's work is not an
instruction to that session.

A Claude Code skill that creates pipes between whoever holds their ends.
That is the whole project.

Think of a cat-5 cable. It carries bytes between two ends and has no idea
what is plugged into either one. This skill is the cable. Nothing more.

## What this is

- A **pipe**: a bidirectional channel at a path. Whoever has the path can
  attach to either end. Whoever created it need not hold an end.
- The skill covers creating, listing, and removing pipes. Attaching is
  opening the path. Nothing else.

## What this is not

Out of scope. Do not build, stub, or "leave room for" any of these:

- Message formats, protocols, schemas, framing, or envelopes for what goes
  through a pipe. Not even a line convention or a timestamp.
- How a writer decides what to write, or how a reader takes what it reads.
- Routing, brokers, discovery services, registries, hubs, or topology.
- Persistence, replay, history, ledgers, or logging of pipe contents.
- Liveness, heartbeats, peer-death detection, or EOF markers.
- Auth, encryption, permissions, or multi-user anything.
- Retries, backpressure, queues, or delivery guarantees beyond what the
  underlying OS primitive already gives.
- Other transports (git, maildirs, platform messaging) or bridges to them.
- Anything a sibling already does. Use it where it is; never copy,
  wrap, or reimplement it here. A sibling written after this file is
  still a sibling.
- Config files, plugins, options, or extension points.

If a request touches any of the above, stop and say it is out of scope. Do
not add it. Before adding anything, ask: is this the cable, or something
that plugs into the cable? Only the cable belongs here.

This list says what does not belong in a cable. It is not the
project's list, and no other piece inherits it. A sibling that keeps
what it carries, or carries it some other way, is not forbidden by
anything here. It is simply not Pipes.

## Testing

A test harness is allowed **only to prove the pipe works**: create it, push
bytes one way, see them arrive the other way, both directions, remove it.
The harness must not grow into a client, protocol, or example app. If a
test needs more than a few lines of setup, the pipe is too complicated,
not the test.

The harness is bash. Run it as `./tests/run.sh`. `sh tests/run.sh`
overrides the shebang and dies on the first bashism, which is the caller
overriding the interpreter, not the harness being broken.

## Rules

- **KISS.** One way to do each thing. Prefer the OS primitive over a library.
  Prefer a shell script over a program. Prefer no dependency over one.
- **Small.** If a file is getting long, you are adding scope, not features.
- **No speculative work.** Build what is asked, not what might be asked later.
- **Do not generalize what you have one of.** One shape needs no shape
  language, one transport no transport interface, one caller no options.
  This is about factoring what is here, not about what may be built. A
  piece that does not exist yet has no callers, and neither did this one.
- **Facts, not recipes.** SKILL.md states what the OS primitive does. It does
  not tell the caller how to wait, poll, frame, or spread a payload over
  lanes. The read-and-write section grows when something is measured and
  never when something is advised. It said "two commands and never grows"
  until the measurements arrived; the count was standing in for the rule,
  and enforcing the count would have deleted what the rule was for.
- **The session defines the skill. The skill does not define the session.**
  How many pipes, how wide, how deep, who holds which end, what goes down
  one — all the session's. This file says what the primitive does and stops
  there. The moment it starts telling a session how to be arranged, it has
  stopped being the cable and become something plugged into it.
- **Bash, and the shebang decides.** Every script here is bash and says so on
  its first line. Run one by its path and let that line choose the
  interpreter. Never reach for `sh script` or `bash script`: that overrides
  what the file declares, and a script that runs today only because the
  caller forced dash on it will break the day it uses anything bash has.
  ICC's runner called every piece with `sh` and failed the moment this
  harness stopped being POSIX.

## Layout

```
.claude/skills/icc-pipes/SKILL.md     the skill definition Claude Code loads
.claude/skills/icc-pipes/scripts/     create, list, remove. One script each.
tests/                                the minimal harness described above
```

Do not add directories without a reason that fits the scope above.
