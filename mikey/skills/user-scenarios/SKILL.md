---
name: mikey:user-scenarios
description: >-
  Collaboratively document high-level Given/When/Then user scenarios with the user before building
  a tool, CLI, or feature; the user is the authority on intended behavior and Claude proposes,
  questions, and records. Trigger on "user scenarios", "given when then", "GWT", "document
  scenarios", "acceptance scenarios", "user scenario doc", "scenarios before we build", or when the
  user asks to write or review scenarios for a tool, CLI, or feature. The resulting doc is what
  /mikey:build implements, one `##` group at a time.
argument-hint: "[doc path]"
user-invocable: true
---

# User scenarios

Write Given/When/Then scenarios with the user before any code exists. The user decides what the
tool should do. You propose, ask, and record. You never invent behavior.

Flow order: write and approve scenarios here, run the scenario review (workflow step 10), then run
`/mikey:build <doc> "<group heading>"` once per `##` group.

Worked examples this skill is distilled from:
- `docs/user-scenarios/mikey-build.md` in this plugin's repo (one file, `###` heading per scenario,
  ids, Decided and Parked sections).
- `tools/mutt/docs/user-scenarios/` in the Perf_test_tools repo (a README index plus one file per
  user journey).

## Workflow

1. **Read all existing source material first.** READMEs, schemas, existing tool docs, and
   scratchpads. Ground every proposal in them, and cite the source when a decision came from one.
2. **Propose one scenario at a time, through the AskUserQuestion tool.** Every proposal and every
   approval is an AskUserQuestion call, never a question typed at the end of a message: the user
   answers by selecting, and free text stays available through the tool's own "Other" option.
   Put the full scenario (id, Risk, Given/When/Then) in the `preview` of each option so the user
   reads it in the same place they answer; text printed before a tool call is easy to miss. Offer
   approve, change this line (the user types the change), and reject. You may propose two
   scenarios together only when they're an obvious pair (a rule and its mirror); then the options
   are approve both, approve one and change the other, change both.
3. **Never guess intended behavior.** When a Given/When/Then has more than one plausible reading,
   put the readings as the options of one AskUserQuestion (2-3, each stated concretely) and ask
   which one the user means before writing. Group questions when they're independent, up to four
   per call, so the user answers a round at a time.
4. **Never change, remove, or add a scenario without explicit approval.** Wording tweaks count.
   When the user flags a confusing line, propose the replacement text and ask before editing.
   A design decision that changes one phrase in many scenarios (e.g. renaming the tracking file)
   is one batch: list each substitution once, get one approval, apply it everywhere, then grep
   for leftovers and long lines.
5. **Scrutinize non-obvious decisions before recording them.** When the user makes a design call
   with real tradeoffs, lay out why it's right, what it costs, and a conclusion, in plain language.
   Ask for agreement. Then record.
6. **Make implied tool changes only when told to.** If a scenario implies a change to a skill or
   CLI that already exists, point it out. Change it only when the user says to.
7. **Explain before offering a choice.** Lead with the plain-language problem and a concrete
   example. Options phrased in tool vocabulary get answered with "I don't understand".
8. **Refer by id, and quote.** Name a scenario by its id (`BUILD-004`), and when proposing a tweak
   to an existing scenario, print it in full first. An id alone still means nothing to a user who
   hasn't memorized the doc.
9. **When a proposal needs a new state or special case, stop.** Restate the tool's purpose in
   two sentences, then ask what the simplest solution is. Usually an existing state already
   covers it, and the special case was the mistake. Check whether the new rule makes some
   existing scenario contradict itself (e.g. "untested code cheaper to change than tested").
10. **Review the scenarios before they go to build.** This is the last step of a session: run it
    when the user says the session's scenarios are done, and before you suggest `/mikey:build`.
    Also run it whenever the user asks for a review of the doc or of one group. See Scenario
    review below.

## Scenario ids

Every scenario has an id of the form `PREFIX-nnn`: a short uppercase topical prefix chosen with
the user (one word naming the tool, feature or area the scenarios cover), then a three-digit
number that counts up through the doc. The id is the scenario's `###` heading, and the test that
covers the scenario can carry the same id.

- A **meaningful change** (different Given, When, or Then, or a different intent) retires the id.
  The new scenario gets the next unused number, and the old scenario is deleted.
- A **wording-only change** keeps the id.
- An id is never reused, even after its scenario is deleted. Gaps in the numbering are fine.
- Use one prefix per doc. A split doc keeps one prefix per file.

Say which kind of change you're proposing when you ask for approval, so the user decides whether
the id is retired.

## Document format

- Start as one markdown file, flat, in `docs/user-scenarios/` (or wherever the user says). Once it
  passes roughly 30 scenarios, or a group passes about 10, offer to split. Split by what the
  developer is doing at the time (getting started, pushing a change, running the tool), not by which
  component acts; the user's experience is the grouping that reads well. The README then holds the
  intro, an index, and the Decided and Parked sections. No scenario counts in the index: they drift
  and say nothing. Split by script and assert every scenario block lands verbatim exactly once;
  never retype scenarios.
- Title, then a short intro that states the approval rule ("Scenarios are only changed, removed,
  or added with explicit approval.") and the id rule, then `##` groups.
- Groups are logical: "CI gate", "Staleness detection", "Tracking file lifecycle". Suggest
  splitting a group into its own file when it passes about 10 scenarios or gets a distinct owner.
  Keep everything flat until then. `/mikey:build` implements one `##` group per run, so size a
  group for one run: one theme, about 10 scenarios or fewer.
- Each scenario is a `###` heading holding its id, then a **Risk:** paragraph, then the scenario in
  a `>` blockquote with bold **Given** / **And** / **When** / **Then** / **And** keywords, one
  clause per line.
- High-level only. Technical details (hashes, commands, file formats) appear only when the
  scenario is about them. Write "my change modifies a source file", not "the git blob SHA
  differs from source_sha".
- As concise as possible. No explanatory prose inside the blockquote.
- Wrap at about 100 characters.
- Two holding sections at the end, so decisions never get lost between sessions:
  - `## Decided, no scenario needed` for rules the user settled that don't need a scenario
    (e.g. "no score thresholds").
  - `## Parked` for features or constraints the user deferred ("let's come back to this later"),
    each with the decisions already made about it.
  Record in these the moment the user decides. Never turn a parked item into a scenario without
  asking.

Template:

```markdown
## Group heading

### PREFIX-001

**Risk:** If [the Then fails], [concrete harm to a person].

> **Given** [starting state]
> **And** [more state]
> **When** I [do the thing]
> **Then** [observable outcome]
> **And** [more outcome]
```

## Risk rules

These matter most. Three Risk lines were rejected as confusing before these rules existed. The
failure pattern: opening with the failure stated as a bare fact ("Completed modules get re-tested
every run.") so it reads like current behavior, then chaining two or three consequences with vague
referents ("it", "this", "the slowest part").

1. **Open with the condition.** Start with "If [the Then fails]" or "Without this," so the reader
   knows it's hypothetical.
2. **One causal hop.** Condition, then the harm. Never a chain of three.
3. **Name a concrete harm to a person.** A bug ships, a build fails for no reason, a developer
   re-runs an hour-long job. No abstract nouns like "adoption" or "no gain".
4. **No dangling referents.** Never "it", "this", or "the slowest part". Name the thing.
5. **Two sentences at most.**
6. **Read-back check.** Could a reader mistake the Risk for a description of current behavior?
   If yes, rewrite.

Bad:

> Completed modules get re-tested every run. The slowest part of the workflow repeats for no
> gain, and the skill can't finish a large codebase.

Good:

> If completed modules are re-tested on every run, each run repeats hours of finished work before
> reaching anything new. Developers stop running the skill on large codebases.

## Scenario review

`/mikey:build` reads a group's scenarios before writing code, and its review rounds read them again
once the code exists. Anything they find wrong with a scenario stops the run or lands in its
report, often after hours of agent work. This review finds those problems while the user is still
here to rule on them.

**Scope.** At the end of a session, review every group where a scenario was added, changed or
removed this session. When the user names a group, review that group. When the user asks for a
review of the doc, review every group.

**Reviewer.** Spawn one fresh `general-purpose` subagent with model `opus` and effort `medium`, the
same model and effort `/mikey:build` uses for its scenario read. A reviewer that didn't write the
scenarios isn't anchored on the reasoning behind them. The brief carries only the doc's path, the
group headings to review, and the path of this file
(`${CLAUDE_PLUGIN_ROOT}/skills/user-scenarios/SKILL.md`) with an instruction to follow its Review
checklist section. Never add your own view of the scenarios, the session's discussion, or a
summary of what changed. Spawn a new one for every review; never continue an earlier one.

The plugin's `adversarial-reviewer` in scenario-read mode is not used here: it takes one group per
spawn, and it has no checks for the doc's format rules or for the specific missing scenarios
below. Checks 1 and 2 are the only two concerns build's scenario read stops a run on, so this
review looks for the same things.

**Applying findings.** Never apply a finding yourself. Print one line with the number of findings,
then take them one scenario at a time as proposals under the workflow rules: explain the problem in
plain language (rule 7), quote the scenario in full (rule 8), and ask through AskUserQuestion with
the full scenario text in each option's preview (rule 2). A finding about two readings offers the
readings as options (rule 3). Every proposal says whether it's a meaningful change, which retires
the id, or a wording-only change. Offer approve, change, reject and park. A finding the user parks
goes in Parked with what was decided about it. A ruling that needs no scenario goes in Decided. A
rejected finding is dropped.

**Concerns from `/mikey:build`.** When invoked with the doc path and a list of concerns to rule on,
skip the reviewer and take each concern as a finding under Applying findings, then report each
ruling in one line and return.

### Review checklist

This section is the reviewer's protocol. Read the whole doc, then for each scenario in the groups
named in your brief, check:

1. **Two readings.** Could two readers build or test different behavior from the same words? Look
   hardest at a time, count or limit with no stated anchor or boundary: when a period starts, what
   it is counted from, and whether the boundary value itself is in or out.
2. **Contradiction.** Does the scenario contradict another scenario in the doc, in any group, or
   the Decided section?
3. **Risk mismatch.** Does the Risk paragraph name a harm the Then wouldn't catch if it failed?
4. **Missing scenarios.** What do the approved scenarios imply that nobody wrote down? Check each
   of these and report only the ones no scenario or Decided note covers: what the user sees when
   each step fails; boundary values; repeating or restarting the same action; blank or malformed
   input; and a state left by one scenario meeting another scenario's action. Skip anything already
   in Parked.
5. **Format.** Does the scenario break this file's Document format or Risk rules? Check that it has
   one Given, one When and one Then, with only And clauses repeated; that its Risk follows the Risk
   rules; and that its group still fits one build run (one theme, about 10 scenarios or fewer).

For each finding, report the scenario id (or the id of its nearest neighbor for a missing
scenario), the group heading, the check number, the words that cause it quoted from the doc, and
why it matters to the person using the tool. Don't write replacement scenarios. Don't rank
findings. Write "none" when there are none. Never edit, create or delete files.

## Lessons

This skill is updated as the user and Claude learn what works.

- 2026-09-18: Risk rules derived after three Risk lines were rejected as confusing; the shared
  cause was stating the failure as a bare fact and chaining consequences.
- 2026-09-21: Added the "Decided" and "Parked" holding sections. The user deferred a feature
  mid-session and settled a rule with no scenario; both needed a home in the document.
- 2026-09-21: When one scenario ends with a pass and a warning, ask whether the user wants a
  later "strict" setting. Two scenarios in a row (excluded file, partly tested file) went that
  way.
- 2026-09-21: Referred to "scenario 4" and the user had to ask for it to be printed. Added
  rule 8 (since extended to ids).
- 2026-09-21: Invented a "zero score placeholder" state and a threshold note to go with it. The
  user asked to restate the purpose and find the simplest solution; the existing "pending" state
  covered it, and one approved scenario became redundant. Added rule 9.
- 2026-09-21: Split the 32-scenario file into five journey files. First grouping proposal was
  by component (CI gate, staleness, tracking data, skill run); the user asked for grouping by
  the user's experience instead. Also: an `rm` after a failing split script deleted the source
  because it wasn't chained with `&&`; the commit saved it. Chain destructive steps to success.
- 2026-09-21: A layout decision touched 13 Givens. One batch proposal with four substitutions
  got one approval; mechanical sed then a grep for leftovers and >100-char lines caught five
  misses. Added the batch note to rule 4.
- 2026-10-30: Proposed a scenario with three When/Then pairs chained by "When ... Then ... When
  ...". The user's rule: one Given, one When, one Then per scenario; only And clauses repeat.
  Split such a proposal into separate scenarios before presenting it.
- 2026-11-12: Added ids and the heading-per-scenario layout so `/mikey:build` and the tdd parser
  can take one group and tests can name the scenario they cover.
- 2026-11-12: First run of the plugin version proposed a scenario in prose and asked "do you
  approve?" at the end of the message. The user wants every proposal and decision to go through
  AskUserQuestion with the scenario text in the option preview; earlier the same day a scenario
  printed before a tool call was never seen at all. Rules 2 and 3 now require the tool.
- 2026-11-12: The first Florence build run stopped after all the code was written, on four
  scenario concerns: an unstated time anchor in AUTH-001, no scenario for setup failure messages,
  several live codes after a restart, and a blank name. All four were visible from the scenarios
  alone. Added rule 10 and the Scenario review so a fresh reviewer catches these before build.
