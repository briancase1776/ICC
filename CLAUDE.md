# ICC

Inter-Claude communication: five Claude Code skills, each its own repo,
pinned here side by side as submodules. This repo holds the pins and one
harness that runs all five. That is the whole project.

    what the bytes mean        someone else's, above all this
    ICC-Patch    the bay       shapes over N seats, and a map
    ICC-Frames   the payload   slice, carry, reassemble
    ICC-Tee      the fitting   copy one pipe onto many
    ICC-Merge    the fitting   copy many pipes onto one
    ICC-Pipes    the lane      a bidirectional channel at a path

Each piece finds its siblings beside it, `../ICC-Pipes` and so on. That
is the layout this repo makes, so nothing in any piece needs telling
where the others are.

## What this is not

- **Code.** No script lives here. A change to a piece is a change in its
  repo, then a new pin here.
- **A sixth skill.** Nothing above the bay belongs here either. Who sits
  where, whose turn it is, what the bytes mean: someone else's, in their
  own repo.

## Working in it

    git clone --recurse-submodules https://github.com/briancase1776/ICC
    sh tests/run.sh                          every piece's harness, in order
    git submodule update --remote            move every pin to its main
    git commit -am 'Pin ...'

## Rules

The rules in each piece's CLAUDE.md apply in that piece. Here there is
one: this repo holds pins, a license, and the harness. If a file wants to
be added, it belongs in a piece, or above the stack.
