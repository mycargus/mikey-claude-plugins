# /mikey:build user scenarios

`/mikey:build` implements one chunk of approved Given/When/Then scenarios on any project: it runs
`/mikey:tdd`, checks the tests with `/mikey:testify`, puts the result through rounds of adversarial
review and fixes, cleans the comments with `/mikey:comment-review`, and commits. The main session
coordinates; subagents do the work.

Scenarios are only changed, removed, or added with explicit approval. Each scenario carries an id
(`BUILD-nnn`); a meaningful change to a scenario retires its id and gets a new one, a wording-only
change keeps it.

## Starting a chunk

### BUILD-001

**Risk:** If the chunk's scenarios aren't taken verbatim from the approved doc, the implementer
works from a paraphrase and I ship behavior you never approved.

> **Given** a user-scenarios doc with a `##` group whose scenarios I approved
> **When** I run `/mikey:build <doc path> "<group heading>"`
> **Then** the chunk is exactly the scenarios under that heading, quoted verbatim
> **And** nothing from any other group is implemented

### BUILD-002

**Risk:** If a mistyped heading silently falls through to "implement the whole doc" or to a
guessed subset, hours of agent work land on the wrong scenarios.

> **Given** a user-scenarios doc
> **When** I run `/mikey:build` with a heading that isn't a `##` group in that doc
> **Then** nothing is implemented
> **And** I'm shown the group headings the doc does have and told to pick one or write the missing
>   group with `/mikey:user-scenarios`

## Implementing

### BUILD-003

**Risk:** If the implementer pauses to ask me to confirm scenarios I already approved in the
scenario doc, every chunk costs a round trip that adds nothing, and I stop running the flow
unattended.

> **Given** a chunk selected by BUILD-001
> **When** implementation starts
> **Then** `/mikey:tdd` implements the chunk's scenarios through red-green-refactor without asking
>   me to confirm the list
> **And** I see one progress line per scenario, nothing more

### BUILD-004

**Risk:** If the main session writes code itself, its context fills with diffs and test output,
and later review rounds are judged by a session already anchored on the implementer's reasoning.

> **Given** `/mikey:build` is running
> **When** any source, test or doc file changes
> **Then** a subagent made the change
> **And** the main session only briefs subagents, reads their reports, and talks to me

### BUILD-005

**Risk:** If test-design problems (I/O mixed with logic, mocked pure functions, missing negative
tests) reach the adversarial reviewer, its rounds get spent on test hygiene instead of on whether
the code does what the scenarios say.

> **Given** `/mikey:tdd` has finished the chunk with a green suite
> **When** the implementing step continues
> **Then** `/mikey:testify` reviews only the files the chunk touched, with code-design analysis on
> **And** a fixer applies every finding it reports before any adversarial review begins

### BUILD-006

**Risk:** If a testify fix changes behavior without a test, the chunk leaves the implementing step
with code no scenario and no test protects.

> **Given** testify reported a finding whose fix changes source code
> **When** the fixer applies it
> **Then** the suite is green afterwards
> **And** any new or moved source logic has a test that fails without it

## Review rounds

### BUILD-007

**Risk:** If the reviewer is briefed with the implementer's reasoning or with earlier rounds'
verdicts, it inherits their blind spots and passes the same bug the implementer missed.

> **Given** the implementing step is done
> **When** a review round starts
> **Then** a fresh reviewer, with no memory of earlier rounds, receives the chunk's scenarios, the
>   current diff, and the project's own conventions (its CLAUDE.md)
> **And** it returns ranked findings: HIGH for a correctness bug, a scenario not implemented or
>   implemented differently, a scenario with no test that would fail if it broke, or drift from
>   docs and conventions the project says must stay in sync; MEDIUM or LOW for everything else

### BUILD-008

**Risk:** If a fix for a behavioral finding lands without a failing test first, the next round
can't tell whether the fix worked, and the bug can return unnoticed later.

> **Given** a review round returned findings
> **When** the fixer runs
> **Then** a fresh fixer addresses every finding, HIGH or not
> **And** for a finding about behavior it writes the failing test before the fix
> **And** the suite is green when it finishes

### BUILD-009

**Risk:** If every nit forces another full review round, three rounds get spent on wording while
a real bug found in round three has no round left to be fixed and re-checked.

> **Given** a review round's findings have all been fixed
> **When** that round reported no HIGH finding
> **Then** the review loop ends
> **And** the flow moves on to cleaning comments

### BUILD-010

**Risk:** If the loop keeps going or commits after three rounds still show HIGH findings, the
chunk is either burning tokens on a problem the agents can't solve or landing code known to be
wrong.

> **Given** three review rounds have run
> **When** the third round still reports a HIGH finding
> **Then** nothing is committed
> **And** I'm shown the open HIGH findings and what each round tried, and the flow stops until I
>   say what to do
> **And** the third round's findings are left unfixed, exactly as the reviewer wrote them

### BUILD-011

**Risk:** If a reviewer who notices that a scenario itself is wrong or missing either fixes the
scenario or stays quiet, I end up with either an unapproved spec change or a commit that
faithfully implements a mistake.

> **Given** a review round reports that a scenario looks wrong, contradicts another, or that a
>   needed scenario is missing
> **When** the chunk otherwise completes
> **Then** the scenario doc is unchanged
> **And** nothing is committed
> **And** I'm shown the reviewer's note on the scenario and the flow stops until I rule on it

### BUILD-012

**Risk:** If every round's full findings land in the main session, its context fills with review
text and the final decisions get made by a session that has lost the start of the chunk.

> **Given** review rounds are running
> **When** a round finishes
> **Then** I see one line: the round number and the count of findings by severity
> **And** the full findings of every round, each with its outcome, appear only in the final report

## Cleaning comments

### BUILD-013

**Risk:** If comment cleanup pauses for my approval, each chunk waits on a round trip for edits to
comments a subagent wrote minutes ago and I have never once rejected.

> **Given** the review loop has ended
> **When** comments are cleaned
> **Then** a subagent runs `/mikey:comment-review` on the chunk's diff only and applies its trims,
>   history drops, what-drops and deletes without asking me
> **And** comments in code the chunk didn't touch are left alone
> **And** the suite is still green afterwards

### BUILD-014

**Risk:** If a comment claims how a tool, flag or API behaves and the claim is softened or deleted
instead of checked, the next maintainer reads a hedge as a verified fact.

> **Given** comment cleanup finds a comment asserting how a tool, flag or API behaves
> **When** the subagent cannot verify the claim
> **Then** the comment is left as written
> **And** the claim appears in the final report for me to rule on

## Committing

### BUILD-015

**Risk:** If the chunk is committed on a red suite or a failing lint, or with a message that
narrates the diff, the next reader gets a broken commit with no record of why the change was made.

> **Given** comments are clean and no stop condition (BUILD-010, BUILD-011) applies
> **When** the chunk is committed
> **Then** the project's test suite and its lint or static check both pass immediately before the
>   commit
> **And** the commit message has an imperative subject, a body that says only why, lines of 72
>   characters or fewer, a `Test plan:` section with an `Expect:` for each step, and the
>   attribution trailer, with the project's own CLAUDE.md overriding on specifics
> **And** nothing is pushed

### BUILD-016

**Risk:** If a missing lint command blocks the commit, a project without one can never finish a
chunk; if the absence is silent, I assume a check ran that didn't.

> **Given** the project has no lint or static-check command that `/mikey:build` can find
> **When** the chunk is committed
> **Then** only the test suite gates the commit
> **And** the final report says no lint step ran

## Finishing

### BUILD-017

**Risk:** If the final report omits what the rounds found and what was left open, I either
re-review the whole diff by hand or trust a commit whose known gaps nobody wrote down.

> **Given** a chunk has finished, committed or stopped
> **When** I read the final report
> **Then** it lists each scenario in the chunk and the test that covers it, every round's findings
>   with each one's outcome, the comment claims left for me, the test and lint results, and the
>   commit subject or the reason for the stop
> **And** nothing in the report is retyped: file paths, test names and counts come from the
>   subagents' reports and command output

## Decided, no scenario needed

- Decided November 12, 2026: the scenario gate is not part of `/mikey:build`. Scenarios are
  written and approved beforehand with `/mikey:user-scenarios`; build refuses a group it can't find
  (BUILD-002) and never proposes scenarios.
- Decided November 12, 2026: one invocation is one chunk, and a chunk is one `##` group of the
  scenario doc. Chunking happens when the doc is written, not at build time.
- Decided November 12, 2026: models per role. Implementer Sonnet at high effort, adversarial
  reviewer Opus at medium effort, fixer and comment reviewer Sonnet at low effort. Testify's
  analysis agent inherits the main session's model.
- Decided November 12, 2026: always a new commit, never an amend. Squashing onto a rebase-chain
  base is done by hand.
- Decided November 12, 2026: the flow runs `/mikey:tdd` once per chunk; review rounds re-run only
  the reviewer and the fixer. `/mikey:testify` runs once, after red-green and before the first
  review round. `/mikey:comment-review` runs once, after the review loop.
- Decided November 12, 2026: changes to existing skills authorized for this flow:
  - `/mikey:tdd` gains `--auto` (no confirmation prompt) and its spec parser accepts the
    user-scenarios format: `> **Given**` blockquote lines, a `### BUILD-nnn`-style heading per
    scenario, and the Risk paragraph, which is kept with its scenario and passed to the tdd-agent
    as the reason the scenario matters, never dropped. The tdd-agent is spawned with the model and
    effort the caller passes.
  - `/mikey:comment-review` gains `--apply`: classify and apply without the propose-and-wait step;
    unverifiable factual claims are reported, not touched. Default behavior unchanged.
  - `user-scenarios` and `comment-review` move from `~/.claude/skills` into the plugin as
    `/mikey:user-scenarios` and `/mikey:comment-review`; the user-level copies are deleted.
    `user-scenarios` gains the id rule and the heading-per-scenario layout this document uses.
  - Two new agents, `adversarial-reviewer` and `fixer`, with their protocols in `agents/*.md`
    system prompts (ADR-005); `/mikey:build` passes only dynamic context.

## Parked

- The tdd-agent as written is unproven ("just a hunch", November 12, 2026). Review its protocol
  against this flow while building; no specific failure has been observed.
