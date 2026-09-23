---
name: icc-raspberry
description: >-
  Blow a raspberry: print one of sixteen kinds, PTTTT~~~ to BRRRR~~~,
  picked fresh from /dev/urandom, moot-sized or exactly BYTES long.
  Test data that makes itself and checks itself, for anything that
  carries bytes over icc-pipes. The ~'s are spittle; counting them is
  the caller's business.
---

# icc-raspberry

ICC's easter egg, and its test data. It was born in a moot where three
Claudes did nothing but blow raspberries at each other over a patch and
count the spittle, and that moot found a real bug in Frames. It is now
the harnesses' way of making something to send.

A raspberry is a lead, a run of its body letter, and a run of ~, the
spittle:

    P  T    PTTTT~~~       PS S    PSSSS~~~
    PF F    PFFFF~~~       PR R    PRRRR~~~
    PB B    PBBBB~~~       PT H    PTHHH~~~
    TH P    THPPP~~~       BF F    BFFFF~~~
    B  R    BRRRR~~~       TP P    TPPPP~~~
    BL L    BLLLL~~~       PW W    PWWWW~~~
    BZ Z    BZZZZ~~~       PH T    PHTTT~~~
    FF T    FFTTT~~~       TH B    THBBB~~~

## Operations

    scripts/raspberry [BYTES]    print one raspberry, no newline

The kind is the low four bits of a byte from /dev/urandom, so each of
the sixteen is as likely as the next. With no BYTES it is moot-sized: 5
to 40 of body and 1 to 15 of spittle. With BYTES it is exactly that
long, 4 at least, the body and the spittle each cut as one dd block and
their split drawn at random, so a test can size one to sit inside a
Frames frame, fill it, or spill over.

    osRaspberry=$(scripts/raspberry)
    printf '%s' "$osRaspberry" | .../icc-frames/scripts/write "$pDir" 0
    timeout 5 .../icc-frames/scripts/read "$pDir" 1   # the same raspberry

The scripts source icc-lib's shared functions from beside this skill,
`../../icc-lib/scripts/lib` in the same skills directory, so icc-lib has
to be installed with it.

## Why a raspberry

- It checks itself. Drawn fresh every time, with its lengths at random, a
  raspberry that arrives short, long, or mixed with another is not the
  one that was blown, and the difference shows to the eye as well as to
  cmp.
- It makes itself. Nothing is kept in the repo to test with: every run
  blows new ones.
- The spittle is a count anyone can take, and the moot in the Patch
  harness takes it: three seats and a chair on ring-p 3, every seat's
  spittle count checked against every ~ blown at it.
