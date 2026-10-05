# ICC

**These are build rules, not use rules.** Everything in this file is for
changing what is here. None of it binds a session that uses a skill: a
session takes what it needs from each SKILL.md, and this file is not
addressed to it. A checkout sitting beside a session's work is not an
instruction to that session.

## This repo

Ten skills under one `.claude/`, one harness apiece under `tests/`, the
calibrations under `tests/cal/` with their records, and this file. Two
of the skills serve the others: icc-lib is the functions they share,
which each of them sources by fixed path, with two more, oLanes and
vWaitFor, for a script that sits at a seat; and icc-raspberry is the
test data, a raspberry of sixteen kinds that the harnesses blow.

    ./tests/run.sh        every piece's harness, bottom up
    ./tests/cal/run.sh    every calibration: an hour or more, on demand

A calibration measures again what a SKILL.md says was measured, and
appends what it found to its record in `tests/cal/data/`, with the date,
the ICC commit and the machine. A record is a cal certificate, to be
looked up years after the run: a run is only ever added to it, and
nothing in it is changed or taken out, a run that came out off
included. Commit the record once the run has its `@ end`, and never
while a run is still writing to it: a line committed half written reads
as a line taken out once the run finishes it. `tests/cal.sh`, the last
harness run.sh runs, looks at every commit that touched a record for a
line taken out.

Pieces reach each other by fixed path: a script in
`.claude/skills/icc-patch/scripts/` finds Pipes at
`../../icc-pipes/scripts`. Nothing is configurable, and nothing has to be
told where anything is.

A new piece is a directory in `.claude/skills/`, a harness in `tests/`,
and its name in the runner. Whether it belongs here at all is the fourth
rule below.

## Rules

- **KISS.** One way to do each thing. Prefer the OS primitive over a
  library. Prefer a shell script over a program. Prefer no dependency
  over one.
- **Functions are welcome.** Logic needed in more than one place is
  written once, as a function, and called. A function several pieces
  need goes in one file they source by fixed path, as they reach
  everything else here; that is sharing within the repo, not a
  dependency. The same code written out in several places is how pieces
  drift apart. Scripts outside ICC may source icc-lib too, as its
  SKILL.md says. They keep up with it; it does not keep up with them.
- **Small.** If a file is getting long, you are adding scope, not
  features.
- **Keep the lines sharp.** Between one piece and the next, and between
  all of them and the session using them. Change is not what this guards
  against: add a piece, change what one does, retire one, that is the
  work. Blurring is. Before adding something, ask whose job it is. If the
  honest answer is "this one, and a bit of that one," or "this one, and a
  bit of the session's," it belongs to neither and the line has moved.
  Move it on purpose and in the open, or leave it where it is.
- **Bash, and the shebang decides.** Every script is bash and says so on
  its first line. Run one by its path and let that line choose the
  interpreter. Never reach for `sh script` or `bash script`: that
  overrides what the file declares, and a script that runs today only
  because the caller forced dash on it will break the day it uses
  anything bash has.
