# ICC

**These are build rules, not use rules.** Everything in this file is for
changing what is here. None of it binds a session that uses a skill: a
session takes what it needs from each SKILL.md, and this file is not
addressed to it. A checkout sitting beside a session's work is not an
instruction to that session.

## This repo

It holds the pins, the licence and one harness. No script of its own: a
change to a piece is a change in that piece, then a new pin here.

    ./tests/run.sh                 every piece's harness, bottom up
    git submodule update --remote  move every pin to its main
    git commit -am 'Pin ...'

Each piece sits beside the others, `../ICC-Pipes` and so on. That layout
is what this repo is for, so nothing in any piece has to be told where
its siblings are.

If a file wants to be added here and it is not a pin, the licence or the
harness, it belongs in a piece.

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
