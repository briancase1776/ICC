---
name: icc-bridge
description: >-
  Take an icc-frames payload off an icc-pipes pipe as text a SendMessage
  can carry, and put such text back on a pipe as the payload it spells.
  The same bytes on the far wire as on the near one. Who sends the
  message, to whom, and what the bytes mean, is the caller's business.
---

# icc-bridge

A bridge is a payload carried across the session line: off a pipe as
text, through a SendMessage, onto a pipe. Pipes says what a lane is and
Frames what a payload is; see their SKILL.md. Bridge says what the text
is. The Claude holding the end sends the text, and hands what arrives
to in.

## Operations

    scripts/out DIR SIDE > text    take one payload off the lanes SIDE
                                   reads, print it as text
    scripts/in  DIR SIDE < text    take text, put the payload it spells
                                   on the lanes SIDE writes

DIR is what Pipes' create printed, or an end in a Patch map. SIDE is 0
or 1, as Pipes says. Which side you are, and where the text goes, is
agreed outside this skill. Both scripts run Frames' read and write from
`$ICC_FRAMES`, by default `../ICC-Frames` beside this repo.

    timeout 5 scripts/out "$d" 1 > text     # off the wire, one tool call
    SendMessage to=ADDRESS message=text     # the Claude, not a script
                                            # ... over there, a message arrives
    scripts/in "$d" 0 < text                # onto the wire, one tool call

## The text

- The payload in base64, as base64(1) prints it: A to Z, a to z, 0 to
  9, +, / and =, in lines of 76, the last one shorter. Nothing in
  front, nothing behind.
- in reads what base64(1) reads: that alphabet, newlines ignored.
  Anything else and in refuses; the wire is untouched.
- Whole or nothing. out prints nothing unless the whole payload came
  off; Frames says what a cut read leaves on the wire. in puts nothing
  on the wire unless the whole text spelled bytes.
- Four characters carry three bytes. A payload of N bytes is about
  4N/3 of text, and the count line Frames puts in front of it on the
  wire is not in the text.

## Facts about the message

These are properties of SendMessage in Claude Code. The skill adds
nothing to them.

- A message is plain text, and a payload is bytes. That is what the
  alphabet is for.
- A message crosses the session line; a pipe does not, as Pipes says.
  Where a message can reach is the tool's business.
- The address is a name. ListAgents lists them. Which name is the
  caller's, given with the seat.
- It reaches the other Claude wrapped, `<cross-session-message
  from="NAME">` around the text. from is the name that sent it, and
  the name a reply goes to. in takes the text, not the wrapper.
- The recipient's human sees the first line as a preview until they
  open it. out's first line is the payload's first 57 bytes, spelled.
- A subagent's message goes out under its parent session's name, and a
  reply lands in the parent's conversation, not the subagent's.
- Between out and the message, and between the message and in, the
  text is in a Claude's hands, typed into a tool call. Nothing checks
  it. A character swapped for another in the alphabet spells other
  bytes, and base64 cannot tell; one outside it, in refuses.
- One message is one payload. Nothing here says what order two
  messages arrive in, or that one arrived at all.

## In Claude Code

Every Bash call is a fresh shell. out and in are one call each and
hold nothing; the pipe holds itself, as Pipes says. A read on an empty
wire waits, as Frames says: bound out with timeout. A message is a tool
call of its own, between the two.
