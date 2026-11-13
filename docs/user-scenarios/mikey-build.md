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

### BUILD-018

**Risk:** If an ambiguous scenario is found only after the code is written, hours of agent work
go into one reading before the run stops for my ruling anyway.

> **Given** a chunk selected by BUILD-001
> **When** the run starts, before any code is written
> **Then** a fresh reviewer reads only the chunk's scenarios and the doc's Decided section
> **And** if a scenario can be read more than one way or contradicts the Decided section, nothing
>   is implemented and I'm shown the reviewer's notes verbatim

### BUILD-021

**Risk:** If a stopped run's uncommitted work blocks the next run, I have to commit half-finished
work or stash it by hand before I can finish the chunk.

> **Given** my working tree has uncommitted changes other than the scenario doc, such as a stopped
>   run's work
> **When** I run `/mikey:build` on a group
> **Then** I'm shown the changed paths and asked whether to continue from them or stop
> **And** if I stop, nothing runs and nothing changes
> **And** if I continue, tdd leaves alone each scenario that already has a passing covering test
> **And** review, comment cleanup and the commit cover all the changes, the earlier ones included
> **And** the final report lists the paths I approved

## Implementing

### BUILD-003

**Risk:** If the implementer pauses to ask me to confirm scenarios I already approved in the
scenario doc, every chunk costs a round trip that adds nothing, and I stop running the flow
unattended.

> **Given** a chunk selected by BUILD-001
> **When** implementation starts
> **Then** `/mikey:tdd` implements the chunk's scenarios through red-green-refactor without asking
>   me to confirm the list
> **And** I see one line per scenario, printed when tdd returns, plus one line per step of the
>   flow, nothing more

### BUILD-004

**Risk:** If the main session writes code itself, its context fills with diffs and test output,
and later review rounds are judged by a session already anchored on the implementer's reasoning.

> **Given** `/mikey:build` is running
> **When** any source, test or doc file changes
> **Then** a subagent made the change
> **And** the main session only coordinates: it reads the project's conventions and git state,
>   invokes the skills, briefs subagents, reads their reports, runs the final test, lint and
>   commit commands, and talks to me

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
> **And** a MEDIUM or LOW finding the fixer could not fix never blocks; it's listed in the final
>   report

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

### BUILD-019

**Risk:** If a reviewer who notices that a scenario is wrong either fixes the scenario or stays
quiet, I end up with an unapproved spec change or a commit that faithfully implements a mistake.

> **Given** a review round reports that a scenario in the chunk's own group can be read more than
>   one way, or contradicts another scenario or the Decided section
> **When** the chunk otherwise completes
> **Then** the scenario doc is unchanged
> **And** nothing is committed
> **And** I'm shown the reviewer's note and the flow stops until I rule on it
> **And** the same kind of concern about another group goes in the final report only

### BUILD-020

**Risk:** If a suggestion for a missing scenario stops the run, a chunk whose approved scenarios
all pass sits uncommitted until I write scenarios for a different problem.

> **Given** a review round suggests a scenario the doc is missing, or a gap no approved scenario
>   covers
> **When** the chunk otherwise completes
> **Then** the suggestion doesn't stop the flow or the commit
> **And** no fixer acts on it
> **And** the scenario doc is unchanged
> **And** the final report lists the suggestion for me to take to `/mikey:user-scenarios`

### BUILD-022

**Risk:** If a subagent picks a product value no scenario sets and only mentions it in passing,
the value ships as if I had chosen it.

> **Given** tdd or a fixer had to choose a product value that no scenario or Decided note sets,
>   such as a time limit, a default or a message
> **When** the chunk finishes, committed or stopped
> **Then** the final report lists each such value with its file and line and the reason it was
>   chosen
> **And** the value never stops the flow on its own

### BUILD-012

**Risk:** If every round's full findings land in the main session, its context fills with review
text and the final decisions get made by a session that has lost the start of the chunk.

> **Given** review rounds are running
> **When** a round finishes
> **Then** I see one line: the round number and the count of findings by severity
> **And** the full findings of every round, each with its outcome, appear only in the final report
>   or at a stop (BUILD-010, BUILD-019)

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

> **Given** comments are clean and no stop condition (BUILD-010, BUILD-019) applies
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
  analysis agent inherits the model of the subagent that invokes testify (see the round 2 decision
  below). The scenario read uses the adversarial reviewer, Opus at medium effort.
- Decided November 12, 2026: always a new commit, never an amend. Squashing onto a rebase-chain
  base is done by hand.
- Decided November 12, 2026: the flow runs the scenario read (BUILD-018) once, then `/mikey:tdd`
  once per chunk; review rounds re-run only the reviewer and the fixer. `/mikey:testify` runs
  once, after red-green and before the first review round. `/mikey:comment-review` runs once,
  after the review loop.
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
- Decided November 12, 2026, after review round 1: the tdd-agent protocol tightening is
  authorized (outside-in interface tests preferred; RED shown as real failing output, where a
  missing symbol or import counts as a valid first failure for new code; real output on every
  run; a scenario-to-test list at the end; fakes only for network, clock and third-party
  services; never edits specs or git state). `/mikey:testify` gains `--files` (exact file list,
  no related-file discovery) and `--auto` (no report display, no plan prompt); build passes both.
  The moved skills keep the extra guidance the writer added (flow order, worked example, group
  sizing, argument hint) and the em-dash rewrites. The user-level copies of `user-scenarios` and
  `comment-review` were deleted the same day.
- Decided November 12, 2026: two pre-flight stops need no scenario. `/mikey:build` stops before
  doing anything when no test command can be found, or when the directory isn't a git
  repository. A tree with uncommitted changes asks first instead (BUILD-021).
- Decided November 12, 2026, after review round 2: three mid-flow stops need no scenario and
  also gate the commit in BUILD-015. The flow stops before the commit, showing me the output
  tail, when a subagent leaves the test suite red, when `/mikey:tdd` leaves a scenario
  unfinished, or when a commit hook fails.
- Decided November 12, 2026: `/mikey:testify` runs inside the fixer subagent of BUILD-005 (one
  Sonnet low subagent invokes it with `--with-design --auto --files`, then applies the findings),
  because an inline skill has no way to return a report without printing it into the main
  session. Testify's own analysis agent therefore inherits that subagent's model.
- Decided November 12, 2026, after the first Florence run: further skill changes authorized.
  `/mikey:tdd` gains `--existing-work` and the tdd-agent an Existing work section (BUILD-021).
  The adversarial reviewer gains a scenario-read mode (BUILD-018) and labels each concern as an
  ambiguity or contradiction, or as a missing scenario or gap (BUILD-019, BUILD-020). The fixer
  and the tdd-agent report the product values they chose (BUILD-022).

## Parked

- The tdd-agent as written is unproven ("just a hunch", November 12, 2026). Review its protocol
  against this flow while building; no specific failure has been observed.
