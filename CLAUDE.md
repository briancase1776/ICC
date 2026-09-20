# ICC

**These are build rules, not use rules.** Everything in this file is for
changing what is here. None of it binds a session that uses a skill: a
session takes what it needs from each SKILL.md, and this file is not
addressed to it. A checkout sitting beside a session's work is not an
instruction to that session.

## This repo

Six skills under one `.claude/`, one harness apiece under `tests/`, and
this file.

    ./tests/run.sh    every piece's harness, bottom up

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
- **Small.** If a file is getting long, you are adding scope, not
  features.
- **No speculative work.** Build what is asked, not what might be asked
  later.
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
