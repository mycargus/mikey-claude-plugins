# /mikey:build user scenarios

`/mikey:build` implements one chunk of approved Given/When/Then scenarios on any project: it runs
`/mikey:tdd`, puts the result through rounds of review by a roster of reviewers and fixes, cleans
the comments with `/mikey:comment-review`, and commits. The main session coordinates; subagents do
the work.

Scenarios are only changed, removed, or added with explicit approval. Each scenario carries an id
(`BUILD-nnn`); a meaningful change to a scenario retires its id and gets a new one, a wording-only
change keeps it.

## Starting a chunk

### BUILD-001

**Risk:** If the chunk's scenarios aren't taken verbatim from the approved doc, the implementer
works from a paraphrase and I ship behavior you never approved.

> **Given** a user-scenarios doc with a `##` group whose scenarios I approved
> **When** I run `/mikey:build <doc path> "<group heading>"`
> **Then** the chunk is exactly the scenarios under that heading, which every subagent reads from
>   the doc itself, never from a copy or a paraphrase
> **And** nothing from any other group is implemented

### BUILD-002

**Risk:** If a mistyped heading silently falls through to "implement the whole doc" or to a
guessed subset, hours of agent work land on the wrong scenarios.

> **Given** a user-scenarios doc
> **When** I run `/mikey:build` with a heading that doesn't match a `##` group in that doc
>   exactly, once surrounding whitespace and a leading `## ` are ignored
> **Then** nothing is implemented
> **And** I'm shown the group headings the doc does have and told to pick one or write the missing
>   group with `/mikey:user-scenarios`

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

### BUILD-025

**Risk:** If the main session writes code itself, its context fills with diffs and test output,
and I get a final report from a session that has lost the start of the chunk.

> **Given** `/mikey:build` is running
> **When** any source, test or doc file changes
> **Then** a subagent made the change
> **And** the main session only coordinates: it reads the project's conventions and git state,
>   invokes the skills, briefs subagents, reads their reports, runs the final test, lint and
>   commit commands, and talks to me

## Review rounds

### BUILD-035

**Risk:** If only one reviewer reads each round, test-design problems (I/O mixed with logic,
mocked pure functions, missing negative tests) reach the commit unchecked, and I merge tests that
pass while protecting nothing.

> **Given** the implementing step is done
> **When** a review round starts
> **Then** every reviewer in the roster runs, fresh and in parallel: today the adversarial
>   reviewer and the test-design reviewer
> **And** each returns findings in the same format, ranked HIGH, MEDIUM or LOW
> **And** one fixer applies the round's merged findings

### BUILD-007

**Risk:** If the reviewer is briefed with the implementer's reasoning or with earlier rounds'
verdicts, it inherits their blind spots and passes the same bug the implementer missed.

> **Given** the implementing step is done
> **When** a review round starts
> **Then** each roster reviewer is fresh, with no memory of earlier rounds, and reads the whole
>   scenario doc, judging only the chunk's group with the rest as context, plus the current diff
>   and the project's own conventions (its CLAUDE.md)
> **And** the adversarial reviewer returns ranked findings: HIGH for a correctness bug, a scenario
>   not implemented or implemented differently, a scenario with no test that would fail if it
>   broke, or drift from docs and conventions the project says must stay in sync; MEDIUM or LOW
>   for everything else
> **And** the test-design reviewer ranks with testify's severities: a design violation or a test
>   of implementation detail is HIGH

### BUILD-008

**Risk:** If a fix for a behavioral finding lands without a failing test first, the next round
can't tell whether the fix worked, and the bug can return unnoticed later.

> **Given** a review round returned findings
> **When** the fixer runs
> **Then** a fresh fixer addresses every finding about the code, HIGH or not
> **And** for a finding about behavior it writes the failing test before the fix
> **And** the suite is green when it finishes

### BUILD-009

**Risk:** If every nit forces another full review round, three rounds get spent on wording while
a real bug found in round three has no round left to be fixed and re-checked.

> **Given** the fixer has finished a review round's findings
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
> **When** the third round reports any HIGH finding, new or carried over
> **Then** nothing is committed
> **And** I'm shown the open HIGH findings and what each round tried, and the flow stops until I
>   say what to do
> **And** the third round's findings are left unfixed, exactly as the reviewer wrote them

### BUILD-036

**Risk:** If a review round's doubt about a scenario stops the run, I'm interrupted to rule on
wording I'd have accepted either way, and I stop running build unattended.

> **Given** a review round reports a concern about a scenario rather than the code: a
>   contradiction with another scenario or the Decided section, wording that can be read more
>   than one way, or a gap no approved scenario covers
> **When** the chunk otherwise completes
> **Then** the concern doesn't stop the flow or the commit
> **And** no fixer acts on it, and the scenario doc is unchanged
> **And** a reading tdd or a fixer already built and reported (BUILD-032) stands: a reviewer who
>   prefers another reading reports it as a concern, never as a finding to fix
> **And** the final report lists each concern, with the readings the reviewer saw where there are
>   two, for me to take to `/mikey:user-scenarios`

### BUILD-032

**Risk:** If a subagent picks a product value no scenario sets and only mentions it in passing,
the value ships as if I had chosen it.

> **Given** tdd or a fixer had to choose a product value that no scenario or Decided note sets,
>   such as a time limit, a default or a message, or had to pick one reading of wording that can
>   be read more than one way
> **When** the chunk finishes, committed or stopped
> **Then** the final report lists each such value or reading with its file and line and the
>   reason it was chosen
> **And** the value never stops the flow on its own

### BUILD-037

**Risk:** If every round's full findings land in the main session, its context fills with review
text and the final decisions get made by a session that has lost the start of the chunk.

> **Given** review rounds are running
> **When** a round finishes
> **Then** I see one line: the round number and the count of findings by severity
> **And** the full findings travel from the reviewers to the round's fixer and into the final
>   report without the main session reading them in full; it reads only counts and each
>   finding's outcome
> **And** the full findings of every round, each with its outcome, appear only in the final report
>   or at a stop (BUILD-010)

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

> **Given** comments are clean and no stop condition (BUILD-010) applies
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

### BUILD-038

**Risk:** If the scenario doc is never committed, approved scenarios live only as uncommitted
edits, and a stopped run or a stash can lose a day of scenario work.

> **Given** the scenario doc has uncommitted changes from an earlier session
> **When** tdd is about to start
> **Then** build commits the scenario doc on its own, with nothing else in that commit
> **And** that commit follows BUILD-015's message rules but isn't gated by tests or lint, since no
>   code changed
> **And** the chunk's code is committed separately at the end

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
- Decided November 12, 2026: the flow runs the scenario read (BUILD-023, now BUILD-027) before tdd,
  and again after each set of rulings (BUILD-024, now BUILD-028), then `/mikey:tdd` once per
  chunk; review rounds re-run only the reviewer and the fixer. `/mikey:testify` runs once, after
  red-green and before the first review round. `/mikey:comment-review` runs once, after the
  review loop.
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
- Decided November 12, 2026, after the first live run: further skill changes authorized.
  `/mikey:tdd` gains `--existing-work` and the tdd-agent an Existing work section (BUILD-021). The
  adversarial reviewer gains a scenario-read mode (BUILD-023, now BUILD-027) and labels each concern
  by kind (BUILD-019, now BUILD-029; BUILD-020). The fixer and the tdd-agent report the product
  values they chose (BUILD-022, now BUILD-032). `/mikey:build` invokes `/mikey:user-scenarios` with
  the scenario read's concerns when I choose to rule on them, and `/mikey:user-scenarios` takes such
  a list one concern at a time (BUILD-024, now BUILD-028).
- Decided November 13, 2026: only a contradiction stops the run. BUILD-019, BUILD-023 and BUILD-024
  stopped on "can be read more than one way" as well; they are deleted and replaced by BUILD-029,
  BUILD-027 and BUILD-028, and BUILD-030 (now BUILD-031) adds the ambiguity rule: the reviewer names
  the readings and picks the simplest, the implementer builds it, and the final report records it
  beside the product values of BUILD-022 (now BUILD-032). The retired ids are never reused. Concern
  kinds are now `contradiction` (stops), `ambiguity` (simplest reading, reported) and `missing-or-
  gap` (reported). An unlabelled concern still counts as the stopping kind.
- Decided November 13, 2026, after review of the contradiction-only change: the first reading
  built for an ambiguous scenario stands. A later reviewer who picks a different reading has it
  reported under that scenario in the final report, never rebuilt; review-round ambiguity
  concerns reach the fixer only for scenarios with no reading built yet. A reading found by the
  round that stops the run (BUILD-010) is reported, not built. A reading a fixer builds in a round
  with no HIGH finding needs no extra review round: the fixer wrote the failing test first
  (BUILD-008) and the report lists the reading.
- Decided November 13, 2026, after review round 2 of the same change: BUILD-030 and BUILD-022
  are retired and replaced by BUILD-031 (the reading rule with its two exceptions) and BUILD-032
  (owner decisions include interpretations of unclear wording). When the reviewer can't tell
  whether a scenario contradicts another or merely has two readings, the kind is `ambiguity`,
  built as its simplest reading; only a concern with no label at all counts as a contradiction.
  The readings file build hands to tdd lives outside the project tree.
- Decided November 13, 2026, after review round 3 of the same change: the first built reading
  stands across runs as well as within one. A passing covering test from an earlier run fixes the
  reading; a new scenario read that picks differently has its pick reported, and tdd leaves the
  tested behavior alone (BUILD-021). A built reading binds every fixer: a finding or an
  interpretation that conflicts with a built reading is reported as a differing pick and never
  applied, and an interpretation a subagent reports as an owner decision counts as a built reading.
  "The round that stops the run" in BUILD-031 means the third round's HIGH stop (BUILD-010). A
  contradiction involving any chunk scenario is a concern about the chunk, whichever group the
  other scenario sits in. Review rounds after this one were waived for the change itself: the
  round-3 fixes were committed without a fourth review, by decision.
- The November 14 entries below supersede the earlier entries where those describe the scenario
  read, readings, concern kinds, or testify running inside build.
- Decided November 14, 2026, after a simplicity review of the plugin: `/mikey:build` trusts the
  scenario doc. The pre-code gate is the scenario review in `/mikey:user-scenarios` (its step
  10); build reads no scenarios before tdd. BUILD-027 and BUILD-028 are deleted, and the readings
  file, the concern kinds, the continued-past list and the fixer-side reading rules go with them.
  Reasons: verifying intent before code belongs to the scenarios skill and finding drift after
  code to the review rounds; the one live run found every scenario concern from the words alone;
  and once the first built reading stands, no case was left in which a fixer could build a
  reading.
- Decided November 14, 2026: review rounds run a roster of reviewers (BUILD-035): the adversarial
  reviewer, Opus at medium effort, and a new `test-design-reviewer` agent, Sonnet at medium
  effort, built from testify's analysis prompt and the shared references. A test-design HIGH has
  equal standing; the loop ends only when no reviewer reports HIGH. BUILD-005 and BUILD-006 are
  deleted: a fixer subagent cannot spawn testify's analysis agent, and BUILD-008 already requires
  the failing test first. `/mikey:testify` is unchanged for standalone use and no longer runs
  inside build.
- Decided November 14, 2026: a scenario concern a review round raises is report-only (BUILD-033,
  now BUILD-036, replaces BUILD-020, BUILD-029 and BUILD-031). A contradiction found after the
  code exists still gets its local commit, flagged in the report; I unwind it by hand if the
  reviewer was right.
- Decided November 14, 2026: subagents are briefed by reference. Every spawn passes the doc path
  and the group heading and the agent reads the group itself; the main session copies no scenario
  text (BUILD-001). The tdd-agent's VALIDATE step, which named a `--validate` flag that no longer
  exists, is removed.
- Decided November 14, 2026, after the scenario review of these changes: BUILD-033, BUILD-012 and
  BUILD-026 are retired and replaced by BUILD-036 (a built reading stands against a reviewer's
  preference), BUILD-037 (findings bypass the main session's context) and BUILD-038 (the doc-only
  commit follows the message rules but isn't gated by tests or lint).
- Decided November 14, 2026: a lint or static check that fails immediately before the commit is a
  fourth mid-flow stop, like a red suite: nothing is committed, I'm shown the output tail, and the
  flow stops.
- Decided November 15, 2026: a test covers a scenario when its name begins with the scenario's id
  (`<id>: `, or `<id>, <id>: ` in doc order for several), and a test that covers no scenario
  carries no id. The owner reads coverage from those names: which scenario a test protects, which
  scenario a failure broke, and which scenarios no test names. This is how BUILD-021 finds an
  existing covering test and how the scenario-to-test list is checked (ADR-012).
- Decided November 15, 2026: a test that begins with an id its doc no longer defines is a retired
  id's leftover. At the start of tdd, the tdd-agent renames it to the scenario that replaced the
  retired one, or deletes it when no current scenario covers its behavior, and reports each as an
  `Owner decision:` line. Ids with another doc's prefix are left alone. A stale test never makes
  the implementation bend (ADR-012).

## Parked

- The tdd-agent as written is unproven ("just a hunch", November 12, 2026). Review its protocol
  against this flow while building; no specific failure has been observed.
- From the November 14 scenario review, each with the reviewer's point:
  - BUILD-021 holds two branches of my choice (stop, continue) inside And clauses; the one Given,
    one When, one Then rule would split it.
  - BUILD-021 can carry a different group's stopped work into this chunk's commit, against
    BUILD-001's "nothing from any other group is implemented".
  - BUILD-003's "one line per step of the flow, nothing more" doesn't define a step or say
    whether it covers the whole run.
  - BUILD-010 doesn't say what I can choose at the stop (another round, commit anyway, abandon)
    or what each choice does; rerunning through BUILD-021 may be the answer.
