---
name: mikey:build
description: "Implement one approved chunk of Given/When/Then scenarios end to end: TDD, up to three rounds of parallel review (adversarial and test-design) and fixes, comment cleanup, and a commit. Use when the user says 'build the chunk', 'implement this group', 'run the build loop', 'build this scenario group', or gives a user-scenarios doc and a group heading to implement. The main session only coordinates; subagents write every change."
argument-hint: <doc path> "<group heading>"
user-invocable: true
---

# Build

Implements one `##` group of an approved user-scenarios doc. The scenarios are written and approved beforehand with `/mikey:user-scenarios`, whose scenario review is the only check before code. This skill trusts the doc: there is no scenario-read review before tdd, and it never proposes, edits or reorders them.

Specification: `docs/user-scenarios/mikey-build.md` (the `BUILD-nnn` entries; ids are not continuous, because retired ids are never reused). Design record: `docs/adr/adr-011-build-orchestrator.md`. Both are paths in the plugin's source repository, not in an installed copy.

| Parameter | Description |
|-----------|-------------|
| `doc path` | The user-scenarios doc |
| `group heading` | The text of one `##` heading in that doc. One invocation is one chunk |

## How the flow runs

1. Locate the group and prepare (Phase 0).
2. Implement with `/mikey:tdd` (Phase 1).
3. Review rounds: every roster reviewer in parallel, then one fixer, up to three rounds (Phase 2).
4. Clean comments (Phase 3).
5. Check tests and lint, then commit (Phase 4).
6. Print the final report (Phase 5), whether the flow committed or stopped.

## Roles

Pass `model` and `effort` on every spawn exactly as the tables say. Name agents with the plugin prefix (`mikey:fixer`); if the qualified form doesn't resolve, use the bare name.

| Role | Agent | Model | Effort |
|------|-------|-------|--------|
| Implementer | `tdd-agent`, spawned by `/mikey:tdd` | `sonnet` | `high` |
| Fixer | `fixer` | `sonnet` | `low` |
| Comment reviewer | `general-purpose` | `sonnet` | `low` |
| Report assembler | `general-purpose` | `sonnet` | `low` |

**Review roster.** Every review round spawns every agent in this table (BUILD-035). To add a reviewer, add its agent file and one row here; the agent must take the review brief in Phase 2 and write the findings file format the adversarial reviewer writes.

| Reviewer | Agent | Model | Effort |
|----------|-------|-------|--------|
| Adversarial | `adversarial-reviewer` | `opus` | `medium` |
| Test design | `test-design-reviewer` | `sonnet` | `medium` |

Every reviewer, fixer and assembler is a new spawn. Never continue an earlier one with SendMessage, and never tell one about another.

## Rules for the main session

- **Never edit a project file yourself**, not even a one-line fix. The main session only coordinates: it reads the project's conventions and git state, invokes the skills, briefs subagents, reads their short replies, runs the final test, lint and commit commands, and talks to the user (BUILD-025).
- **Brief by reference.** Every spawn that concerns scenarios passes the scenario doc's absolute path and the group heading, and the agent reads the group itself. Never copy or paraphrase scenario text into a brief (BUILD-001). The protocols live in the agent files and skills (ADR-005): a brief to an agent that has a protocol file (tdd-agent, the reviewers, the fixer) carries only paths, the base commit, commands and, for a fixer, the findings files. The comment reviewer and the report assembler are general-purpose agents, so their briefs carry their instructions. Never add your opinion of the code.
- **Findings stay out of this session.** At the start of a run, make a scratch directory outside the project tree with `mktemp -d` and record its path in the ledger. Each reviewer writes its full findings to a file there and replies with only the counts and the file's path. The fixer reads those files. You never open a findings file; you read counts and the fixers' one-line outcomes (BUILD-037).
- **Copy, don't retype** file paths, test names and counts. Take them from the subagents' replies and command output (BUILD-017).
- **Never push. Never amend.** Always a new commit.
- **Favor the simplest** when you choose options to offer the user, or when a subagent proposes adding machinery.
- **Never change the scenario doc.** No subagent changes it either. A scenario concern a reviewer raises is reported, never acted on (BUILD-036).
- **Output is one line per step**: start, the scenario doc commit if any, one line per scenario when tdd returns, each review round, the comment pass, the gate, the commit subject. Nothing else until a stop or the final report (BUILD-003).
- **A stop is a stop.** When a rule says the flow stops, print what it says and the output tail where it names one, then the final report (Phase 5), and end your turn until the user says what to do.
- **Keep a ledger** in your context: the scratch directory path; each scenario with its covering test; each round's counts per reviewer and the fixer's outcome lines; `Owner decision:` lines (BUILD-032); unverified comment claims; command results; whether the run continued from existing changes, with the approved paths.

## Phase 0: Locate the group and prepare

1. Read the doc. List its `##` headings that contain at least one `###` scenario. Headings with none (Decided, Parked, intro) aren't groups.
2. Match the given heading against that list exactly, ignoring only surrounding whitespace and a leading `## `. If the doc is missing, or no group matches, or no heading was given: implement nothing, print the group headings the doc does have, and tell the user to pick one or to write the missing group with `/mikey:user-scenarios`. Stop; there is no final report for this stop (BUILD-002). Use the doc's own heading text from here on, exactly as it appears in the doc, quoted as the shell requires when it is passed to `/mikey:tdd`.
3. Run `git rev-parse HEAD` and keep the result as the **base**. If the directory isn't a usable git repository (a repository with no commits has no base), stop. Run `git status --porcelain --untracked-files=all`. If anything is uncommitted other than the scenario doc, list those paths and ask the user one question with AskUserQuestion: continue from these changes, which then count as this chunk's work in progress, or stop. If the user stops, end the run with no final report and no change. If the user continues, record it in the ledger with the paths (BUILD-021).
4. Find the **test command** and the **lint command**. Read the project's CLAUDE.md first (it wins), then the Makefile, then package manifests. For lint, accept only check-only commands: lint, static checks, type checks or format checks run in a mode that reports and never rewrites files. A formatter or fixer that writes counts as no lint command. If you find no test command, stop and tell the user. If you find no lint command, carry on with tests only and say so in the report (BUILD-016).
5. Make the scratch directory (see the rules above).
6. Print one start line: the group heading, the number of scenarios, whether the run continued from existing changes, the test command, and the lint command or that there is none.

## Phase 1: Implement

First, run `git status --porcelain --untracked-files=all`. If the scenario doc has uncommitted changes, commit it on its own: run `git add -- <doc path>` (so an untracked doc is known to git), then `git commit --only -- <doc path>` with the message on stdin, with no test or lint gate, since no code changed. The message follows Phase 4's format (subject, Test plan, trailer, 72-column lines, CLAUDE.md wins) except the body: it says the changes are approved scenario edits from a `/mikey:user-scenarios` session and names the `##` groups the diff touches. `--only` commits just that path, so anything already staged stays out of the commit. If a commit hook fails here, stop. Its Test plan has one step: show the commit's file list with `git show --stat --format= HEAD`, expecting only the doc. After the commit, run that command and compare the file list to the doc path; if they differ, stop. Print one line with the short hash (BUILD-038), the scenario doc commit's step line. Then run `git rev-parse HEAD` again and keep the result as the new **base**, so the reviewers' diffs don't include the doc edits.

Invoke `/mikey:tdd` with the Skill tool, `skill: "mikey:tdd"`, with arguments: the doc path, `--group "<group heading>"`, `--auto`, `--test-command "<test command>"`, `--lint-command "<lint command>"` when there is one, `--model sonnet`, `--effort high`, and `--existing-work` when the run continued from existing changes. `/mikey:tdd` doesn't ask the user to confirm the scenarios, and prints nothing under `--auto` (BUILD-003).

When it returns, print one line per scenario: its id and its covering test, copied from the report. This is the tdd step line. Record the map and copy every `Owner decision:` line into the ledger. If a scenario is unfinished or the suite isn't green, stop.

## Phase 2: Review rounds

Run up to three rounds. The diff is always the full working tree against the base; when the run continued from existing changes it includes the earlier work.

1. **Spawn the roster.** In one message, spawn every reviewer in the roster table in parallel, each fresh, with the model and effort the table gives. Every reviewer gets the same brief except its Findings file, with these labeled sections and nothing else: **Scenario doc** (the doc path and the group heading), **Diff** (the base), **CLAUDE.md** (its path, or `none` when the project has no CLAUDE.md, in which case the reviewer treats the README and the manifests as the conventions), **Test command**, and **Findings file** (`<scratch>/<bare agent name>-<round number>.md`, such as `adversarial-reviewer-1.md`). Don't tell a reviewer what earlier rounds found or what the implementer or a fixer did (BUILD-007).
2. **Read the replies.** Each reply is a line of the shape `Counts: HIGH n, MEDIUM n, LOW n` and a findings file path. Print one line: the round number and the counts by severity, summed over the reviewers (BUILD-037). Don't open the files. A reviewer whose reply doesn't have that shape or has no path is an error: stop.
3. **Decide.**
   - Any reviewer reported a HIGH finding and this is round three: stop (BUILD-010). Spawn no fixer, so the round's findings stay exactly as the reviewers wrote them. Commit nothing.
   - No reviewer reported any finding: the loop ends.
   - Otherwise spawn one fixer for the round with these sections: **Findings files** (the paths of the files whose counts are above zero), **Scenario doc** (path and group heading), **CLAUDE.md** (or `none`, as for the reviewers), **Test command**, **Lint command** if any, **Diff** (the base), and **Outcomes file** (`<scratch>/fixer-<round number>.md`). The fixer applies every finding of every severity, writes the failing test first for a behavior finding, and leaves the suite green (BUILD-008). Record its one-line outcomes and its `Owner decision:` lines, and update the scenario-to-test map in the ledger from the fixer's reply, which lists every test it added, renamed, moved or deleted as `scenario id: file::test name` (or `none: file::test name` for a test covering no scenario). Replace the map entry for that id; a deletion with no replacement leaves the id marked "no covering test", which the final report shows. If the suite isn't green afterwards, stop.
4. **Loop.** If the round reported no HIGH finding, the loop ends once the fixer has finished (BUILD-009). A MEDIUM or LOW finding the fixer could not fix never blocks the loop or the commit; it appears in the final report. If the round reported a HIGH finding, start the next round.

A scenario concern in a findings file never reaches a fixer and never stops the flow; the doc is unchanged. A reading tdd or a fixer reported as an owner decision stands: a reviewer who prefers another reading reports it as a concern (BUILD-036).

## Phase 3: Clean comments

Spawn a `general-purpose` subagent (`sonnet`, `low`) with the test command. Tell it to invoke the Skill tool with `skill: "mikey:comment-review"` and argument `--apply`, so comment-review uses its default scope (the working-tree diff against HEAD, including untracked files), to run the test command afterwards and never to change git state (BUILD-013). Tell it to reply with only the verdict counts, each proposed code deletion (comment-review reports these without applying them) quoted with `file:line`, each comment claim it could not verify quoted with `file:line`, and the test command's result line: no before/after pairs and no other detail. If the skill can't be invoked from the subagent, it reads `${CLAUDE_PLUGIN_ROOT}/skills/comment-review/SKILL.md` and follows it as written.

From its report, record the verdict counts, each proposed code deletion and each comment claim it could not verify, copied as written with `file:line`. Proposed deletions are report-only: apply none, and list them in the final report. Those comments stay as written (BUILD-014). Print one line with the verdict counts. If the suite isn't green afterwards, stop.

## Phase 4: Check and commit

1. Run the test command, then the lint command if there is one. Run each so that only its exit status and its last 20 or so lines reach this session (pipe through `tail -n 20` and read the command's own exit status, such as with `set -o pipefail`). Print one line with the gate result. If either fails, commit nothing, print the failing output's last lines, and stop (BUILD-015).
2. Stage the chunk's files by explicit path from `git status --porcelain --untracked-files=all`. The paths the user approved in Phase 0 count as the chunk's files. Never stage the scenario doc or generated artifacts, and never use `git add -A` or `git add .`. If nothing is staged, commit nothing, print "nothing to commit", skip steps 3 and 4, and say so in the final report.
3. Write the commit message:
   - An imperative subject describing the change.
   - A body that says only why: the problem the chunk's scenarios guard against, taken from their Risk paragraphs. Don't narrate the diff or list files.
   - A `Test plan:` section with one step for each check you ran. Each step names the exact command, and the line after it starts with `Expect:` and says the observable result, such as the passing count.
   - The attribution trailer the session's instructions require.
   - Every line 72 characters or fewer; check with `awk 'length > 72'`.
   - The project's CLAUDE.md wins on specifics (subject prefix, ticket reference, trailer, section names).
4. Commit with `git commit --only -- <the staged paths>`, passing the message on stdin, so nothing staged outside the chunk's files rides along. Add a Test plan step that shows the commit's file list with `git show --stat --format= HEAD` and expects exactly the chunk's files. After the commit, run that command and compare the file list to the paths you staged; if they differ, stop. Print one line: the commit subject. Never pass `--amend` or `--no-verify`, and never push. If a commit hook fails, stop.

## Phase 5: Final report

Print the report whether the flow committed or stopped (BUILD-017).

First spawn the report assembler (`general-purpose`, `sonnet`, `low`). Its brief: the scratch directory path, the stop reason and the stopping round number from the ledger (or "none" for both when the run committed), and the instruction to read every reviewer findings file and fixer outcomes file in it, edit nothing and change no git state, and reply with these sections only, copying text from the files and never retyping a `file:line`, name or count:
- **Findings by round**: for each round, for each reviewer, every finding with its severity, `file:line`, its full text copied from the file (what is wrong, the evidence, and what a correct result looks like) and its outcome. Take the outcome from the fixer's outcomes file for that round. For a round that stopped the run, the outcome is "left unfixed", and each earlier round's entries show what the fixer tried.
- **Scenario concerns**: each concern from the findings files, with the readings the reviewer saw where there are two, and which reviewer and round raised it, or none.
- **Unfixed MEDIUM and LOW findings**: each one the fixer could not fix, with its reason, or none.

Then print the report in this order, taking item 3 from the assembler's reply unchanged and the rest from the ledger:

1. **Outcome**: the commit subject and short hash, or the stop reason and the output tail. Add the scenario doc commit's subject and hash if there was one. Say whether the run continued from existing changes, and list the paths the user approved (BUILD-021).
2. **Scenarios**: each scenario id in the chunk with the test that covers it, or "no covering test".
3. **Findings by round**, **Scenario concerns** and **Unfixed MEDIUM and LOW findings**. A scenario concern is for the user to take to `/mikey:user-scenarios`; the doc is unchanged (BUILD-036).
4. **Owner decisions**: each `Owner decision:` line from tdd and the fixers, copied as written, or none (BUILD-032).
5. **Comment claims left for you**: each unverified claim and each proposed code deletion with `file:line`, or none (BUILD-014).
6. **Results**: the test command and its result, the lint command and its result, or that no lint step ran (BUILD-016).

Delete the scratch directory only after a commit. At a stop, leave it and print its path in the report, so the findings files can still be read.

## Stops at a glance

Pre-flight stops (Phase 0) print their message and end the run with no final report. Every later stop prints the final report. A stop after Phase 0 leaves the chunk's changes in the tree; the next run asks whether to continue from them (BUILD-021).

| Condition | Result |
|-----------|--------|
| Heading not a group in the doc | Nothing implemented, headings listed (BUILD-002) |
| Changes beyond the scenario doc, and the user chose to stop | Nothing runs, nothing changes (BUILD-021) |
| No test command found, or not a usable git repository | Pre-flight stop |
| A subagent leaves the suite red, or tdd leaves a scenario unfinished | Mid-flow stop before the commit, output tail shown |
| A reviewer returns no counts or no findings file path | Mid-flow stop before the commit |
| Tests or lint fail immediately before the commit | Mid-flow stop, nothing committed, output tail shown (BUILD-015) |
| A commit hook fails | Mid-flow stop, output tail shown |
| Round three reports any HIGH finding, new or carried over | No commit, round three's findings unfixed, the open HIGH findings and what each round tried shown (BUILD-010) |
| A scenario concern, an `Owner decision:`, an unfixed MEDIUM or LOW finding, or an unverified comment claim | No stop; listed in the final report (BUILD-036, BUILD-032, BUILD-009, BUILD-014) |
