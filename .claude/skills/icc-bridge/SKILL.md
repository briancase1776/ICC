---
name: icc-bridge
description: >-
  Currently unavailable: out and in are shelved with icc-frames. What it
  says of the carriers across the session line, SendMessage, send_message
  and a Routine, holds, and sent gives back a send_message's text as it
  was sent. out and in take an icc-frames payload off an icc-pipes pipe
  as text a message can carry, and put such text back on a pipe as the
  payload it spells. The same bytes on the far wire as on the near one.
  Who sends the message, how, to whom, and what the bytes mean, is the
  caller's business.
---

# icc-bridge

A bridge is a payload carried across the session line: off a pipe as
text, in a message, onto a pipe. Pipes says what a lane is and Frames
what a payload is; see their SKILL.md. Bridge says what the text is.
The Claude holding the end sends the text, and hands what arrives to
in. Three things in Claude Code carry a message: SendMessage,
send_message, and a Routine bound to the other session. The facts about
each are below.

Shelved: out and in carry only Frames payloads, and Frames is shelved.
They come back with it. The facts about the message and its carriers,
and sent, do not depend on them, and hold.

## Operations

    scripts/out DIR SIDE > text    take one payload off the lanes SIDE
                                   reads, print it as text
    scripts/in  DIR SIDE < text    take text, put the payload it spells
                                   on the lanes SIDE writes
    scripts/sent < text > text     take a send_message's text as it
                                   arrived, print it as it was sent

DIR is what Pipes' create printed, or an end in a Patch map. SIDE is 0
or 1, as Pipes says. Which side you are, and where the text goes, is
agreed outside this skill. Both scripts run Frames' read and write from
beside this skill, `../../icc-frames/scripts` in the same skills
directory. There is nothing to configure and nothing to set.

    timeout 5 scripts/out "$pDir" 1 > text  # off the wire, one tool call
    SendMessage to=ADDRESS message=text     # the Claude, not a script,
                                            # or send_message or a
                                            # Routine, below
                                            # ... over there, a message arrives
    scripts/in "$pDir" 0 < text             # onto the wire, one tool call

The scripts source icc-lib's shared functions from beside this skill,
`../../icc-lib/scripts/lib` in the same skills directory, so icc-lib has
to be installed with it.

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

These hold whichever carries it. The skill adds nothing to them.

- A message is plain text, and a payload is bytes. That is what the
  alphabet is for.
- A message crosses the session line; a pipe does not, as Pipes says.
  Where a message can reach is the tool's business.
- Between out and the message, and between the message and in, the
  text is in a Claude's hands, typed into a tool call. Nothing checks
  it. A character swapped for another in the alphabet spells other
  bytes, and base64 cannot tell; one outside it, in refuses.
- One message is one payload. Nothing here says what order two
  messages arrive in, or that one arrived at all.

## SendMessage

- The address is a name. ListAgents lists them. Which name is the
  caller's, given with the seat.
- It reaches the other Claude wrapped, `<cross-session-message
  from="NAME">` around the text. from is the name that sent it, and
  the name a reply goes to. in takes the text, not the wrapper.
- The recipient's human sees the first line as a preview until they
  open it. out's first line is the payload's first 57 bytes, spelled.
- A subagent's message goes out under its parent session's name, and a
  reply lands in the parent's conversation, not the subagent's.
- In a cloud session ListAgents lists nothing, so a cloud session has
  no name to send to. Between two cloud sessions, send_message or a
  Routine carries it.

## send_message

The claude-code-remote server's tool. These are what it did between
cloud sessions of one account.

- The address is the other session's id, session_..., and list_sessions
  lists them. It reaches sessions of the same account.
- It arrives as a turn of its own, wrapped in `<cross-session-message
  from-session="session_...">`, with two lines of the harness's in front
  of the text. from-session is the session that sent it, and the address
  a reply goes to. A session in the middle of a turn is told
  notifications are pending, and ReadNotifications returns it. in takes
  the text, not the wrapper.
- The text does not arrive as it was sent. Every line comes indented
  four spaces, an empty one too, and &, < and > come as &amp;, &lt; and
  &gt;, so text that was already escaped arrives escaped again. Tabs,
  quotes, backslashes, $ and trailing spaces come as they were sent. A
  text that ended in a newline arrives with one more line, empty but for
  the indent. Those are the changes seen, not a promise there are no
  others.
- sent undoes them. Hand it the lines inside the wrapper, after the
  harness's two and the blank one, as they arrived: it takes the four
  spaces off each and the three entities back, once, and prints the text
  as it was sent, its last newline or none included. A line without the
  four spaces refuses the whole text. in refuses the indent, so text
  for in goes through sent first.
- The sender's tool result echoes the message as it was delivered,
  indent and escapes included. That says it arrived, not that it was
  read.
- Any session on the account can read another's transcript, the
  messages in it included, with list_events. A message is not between
  two sessions only.
- The tool says a message is bounded to 64 KiB.

## A Routine

Routines are a research preview in Claude Code; these are what they
did, and they may change.

- create_trigger with persistent_session_id set to the other session,
  run_once_at a minute or two ahead, and the text in the prompt. When
  it fires, the text is in that session. The address is the session's
  id, session_..., and list_sessions lists them. It reaches sessions of
  the same account only.
- It lands whether or not the other session is running: the firing
  starts it. It lands within about a minute after its minute. Scheduled
  runs are at most 100 an hour on an account; past that, a run waits.
- Do not fire it with fire_trigger, which is Run now. That has landed
  in the other session some times, and other times started a fresh
  session that took the prompt as its task, on the default model, with
  no repository. What decides it is not known, nothing on the Routine
  says which it did, and nothing tells the sender. The scheduled firing
  is the one that lands.
- get_trigger, after it fires, is the receipt: last_run SUCCEEDED, with
  session_id the other session's id with cse_ in place of session_. That
  says it arrived, not that it was read. No last_run, and it did not.
- It arrives as a notification that a scheduled trigger fired, with the
  prompt as it was written; ReadNotifications returns any the session
  has not been shown. The session takes the prompt as a task stored on
  the account, so what the text is for is said around it, by the Claude
  that made it. in takes the text, not what is around it.
- Nothing in it names the session that made it. Where a reply goes is
  agreed outside this skill, as the address is.
- It fires once and turns itself off: one Routine is one message. Its
  prompt stays on the account, read by list_triggers, until the Routine
  is deleted. How long a prompt may be is not documented.

## In Claude Code

Every Bash call is a fresh shell. out and in are one call each. Each
keeps the payload in a temp file while it runs and removes it when it
ends; the pipe holds itself, as Pipes says. A read on an empty
wire waits, as Frames says: bound out with timeout. A message is a tool
call of its own, between the two.
