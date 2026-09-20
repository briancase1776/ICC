# ICC-Bridge

A Claude Code skill that carries an ICC payload across the session line
as a SendMessage, and back. That is the whole project.

Think of a telegraph clerk at the end of a wire. Something comes off
the wire; the clerk spells it in the alphabet the telegraph can carry
and hands it in, with an address someone else wrote on it. Something
comes back addressed to the clerk; the clerk reads the spelling and
puts it on the wire. The clerk cannot read the message and does not
know who wrote it. This skill is the spelling. Nothing more. The clerk
is a Claude, and the telegraph is SendMessage.

## Where this sits

    what the bytes mean                someone else's, above this
    a payload as a message, and back   this project
    slice, carry, reassemble           ICC-Frames, below this
    the lane itself                    ICC-Pipes, below Frames

Pipes does not know what is plugged into it. Frames does not know what
the bytes are. Bridge knows neither: it changes the alphabet. A pipe
stops at the container, as Pipes says; a message does not. The bridge
is where a payload gets off one and onto the other. Which end it holds,
a pipe's or one in a Patch map, it does not care.

## What this is

- **out**: given a pipe and a side, take one Frames payload off the
  lanes that side reads and print it as text a message can carry.
- **in**: given a pipe, a side and that text, put the payload it spells
  on the lanes that side writes.
- The text is the payload in base64, as base64(1) prints it, and
  nothing else. Nothing in front, nothing behind. What comes off the
  far wire is what went on the near one, the same bytes in the same
  order.
- The Claude holding the end does the sending: it calls SendMessage
  with the text as the message and an address it was given. And the
  receiving: a message that arrives is text it hands to in. No script
  here sends or receives anything; a script cannot. The skill is the
  two transcriptions.

## What this is not

Out of scope. Do not build, stub, or "leave room for" any of these:

- **The wire, the payload.** Pipes and Frames. Bridge runs Frames' read
  and write; it never copies them.
- **The courier.** Calling SendMessage, or anything that finds, holds,
  waits on, or retries one. That is the Claude at the end, and the
  tool.
- **The address.** Who a message goes to, how a name is found, who is
  at the other end. ListAgents, registries, discovery. The address
  comes with the seat, from outside, like which side you are.
- **The content.** What the bytes mean. No envelope, header, mark of
  who sent it, tag saying it is a bridge message, sequence number,
  count, or checksum. out prints the payload in another alphabet and
  nothing else.
- **Deciding.** What to carry, when, which way, to whom. Every payload
  off the wire is one text; every text is one payload on the wire.
  Filtering, routing, splitting a payload over messages, joining
  messages into a payload.
- **Delivery.** Acknowledgements, retries, order between messages,
  duplicates, liveness, a reply.
- Other alphabets, compression, options. One alphabet.
- Config files, plugins, or extension points.

If a request touches any of the above, stop and say it is out of scope.
Before adding anything, ask: is this the wire, what goes through it,
who carries the message, or the spelling that lets a message carry a
payload? Only the last one belongs here.

## Depends on ICC-Frames

out and in run Frames' read and write from a sibling checkout,
`$ICC_FRAMES`, by default `../ICC-Frames` beside this repo. Tests get
pipes from Pipes in `$ICC_PIPES`, by default `../ICC-Pipes`. Do not
vendor either into this repo.

Do not duplicate their documentation. A fact about a lane is Pipes'; a
payload, Frames'. If one of them is missing a fact, that is a change
there, not a paragraph here.

## Testing

A test harness is allowed **only to prove the transcription**: get two
pipes from Pipes, put a Frames payload bigger than one lane holds on
one, take it off as text, see the text is the alphabet and nothing
else, put it on the other, read it back whole, compare bytes, both
directions; an empty payload; text that is not the alphabet puts
nothing on the wire, and a wire with nothing on it prints nothing;
remove the pipes. The harness must not send a message, spawn an agent,
or grow into a client. If a test needs more than a few lines of setup,
the transcription is too complicated, not the test.

## Rules

- **KISS.** One way to do each thing. Prefer the OS primitive over a
  library. Prefer a shell script over a program. Prefer no dependency
  over one.
- **Small.** If a file is getting long, you are adding scope, not
  features.
- **No speculative work.** Build what is asked, not what might be asked
  later.
- **No abstraction until there are two real callers.**
- **Two operations.** out and in. Not a third. If something looks like
  it needs a third, it belongs above or below this layer.
- **One alphabet.** base64, as base64(1) prints it and reads it.
  Nothing is added to it, in front or behind.
- **Whole or nothing.** out prints nothing unless the whole payload
  came off the wire. in puts nothing on the wire unless every character
  was the alphabet.
- **Never read what is carried.** No option, header, or check in this
  repo may depend on what is in a payload.
- **Facts, not recipes.** SKILL.md says what the text is and what
  SendMessage does with text. It does not say when to send, whom to
  send to, or what to do with what comes back.

## Layout

```
.claude/skills/icc-bridge/SKILL.md     the skill definition Claude Code loads
.claude/skills/icc-bridge/scripts/     out, in. One script each.
tests/                                 the minimal harness described above
```

Do not add directories without a reason that fits the scope above.
