---
name: mikey:build
description: "Implement one approved chunk of Given/When/Then scenarios end to end: TDD, test-design review, up to three adversarial review and fix rounds, comment cleanup, and a commit. Use when the user says 'build the chunk', 'implement this group', 'run the build loop', 'build this scenario group', or gives a user-scenarios doc and a group heading to implement. The main session only coordinates; subagents write every change."
argument-hint: <doc path> "<group heading>"
user-invocable: true
---

# Build

Implements one `##` group of an approved user-scenarios doc. The scenarios are written and approved beforehand with `/mikey:user-scenarios`. This skill never proposes, edits, or reorders scenarios; when the user rules on scenario-read concerns, `/mikey:user-scenarios` does that under the user's approval (BUILD-028).

Specification: `docs/user-scenarios/mikey-build.md` (the `BUILD-nnn` entries in the doc; the ids are not continuous, because retired ids are never reused). Design record: `docs/adr/adr-011-build-orchestrator.md`.

| Parameter | Description |
|-----------|-------------|
| `doc path` | The user-scenarios doc |
| `group heading` | The text of one `##` heading in that doc. One invocation is one chunk |

## How the flow runs

1. Locate the group and prepare (Phase 0). If the tree already has changes, ask whether to continue from them.
2. A fresh reviewer reads the scenarios, with no code (Phase 1). On a contradiction, ask whether to rule on the contradictions now, stop, or continue anyway. A scenario with two or more readings never stops the run: tdd builds the reader's simplest reading.
3. Implement with `/mikey:tdd` (Phase 2).
4. A fixer subagent runs `/mikey:testify` on the touched files and applies its findings (Phase 3).
5. Review rounds: a fresh reviewer, then a fresh fixer, up to three rounds (Phase 4).
6. Clean comments (Phase 5).
7. Check tests and lint, then commit (Phase 6).
8. Print the final report (Phase 7), whether the flow committed or stopped.

## Roles

Pass `model` and `effort` on every spawn exactly as this table says.

| Role | Agent | Model | Effort |
|------|-------|-------|--------|
| Scenario reader | `adversarial-reviewer`, in scenario-read mode | `opus` | `medium` |
| Implementer | `tdd-agent`, spawned by `/mikey:tdd` | `sonnet` | `high` |
| Test-design fixer | `fixer`, which invokes `/mikey:testify` itself | `sonnet` | `low` |
| Test-design analysis | `analysis-agent`, spawned by `/mikey:testify` | inherits the invoking fixer | inherits |
| Review-round fixer | `fixer` | `sonnet` | `low` |
| Adversarial reviewer | `adversarial-reviewer` | `opus` | `medium` |
| Comment reviewer | `general-purpose` | `sonnet` | `low` |

Name the agents `mikey:adversarial-reviewer` and `mikey:fixer`. If the qualified form doesn't resolve, use the bare name.

Every reviewer and every fixer is a new spawn, and so is the scenario reader. Never continue an earlier one with SendMessage, and never tell one about another.

## Rules for the main session

- **Never edit a project file yourself**, not even a one-line fix. Source, test and doc changes come from subagents. The main session only coordinates: it reads the project's conventions and git state, invokes the skills, briefs subagents, reads their reports, runs the final test, lint and commit commands, and talks to the user. The scenario doc is covered by the rule on it below.
- **Brief with dynamic context only.** The protocols live in the agent files and in the skills you invoke (ADR-005). A brief carries the scenarios, paths, the base commit, commands and findings, and nothing else. Do not add instructions that restate a protocol, and never include your own opinion of the code.
- **Copy, don't retype.** Scenario text, findings, file paths, test names and counts are copied from the doc, the subagents' reports and command output. Never recompose them from memory.
- **Never push. Never amend.** Always a new commit.
- **Favor the simplest.** When you choose options to offer the user, or a subagent proposes adding machinery, favor the simplest option that works.
- **Never change the scenario doc.** A contradiction goes to the user, and an ambiguity goes in the final report with the reading that was built (BUILD-029, BUILD-031, BUILD-020). The one way the doc changes is `/mikey:user-scenarios` in Phase 1, when the user chooses to rule on the scenario read's contradictions, and every change there needs the user's approval (BUILD-028). Outside that skill the main session never edits the doc, and no subagent ever does.
- **Output is one line per step.** Print one line per step of the flow (start, scenario read, scenario doc commit, tdd, testify-and-fix, each review round, comment pass, gate, commit), plus the per-scenario lines when tdd returns, and nothing else except at a stop or in the final report.
- **A stop is a stop.** When a rule below says the flow stops, print what it says, print the final report (Phase 7), and end your turn. Don't continue until the user says what to do.
- **Unlabelled concerns.** A scenario concern or note with no kind label counts as `contradiction`, the safer choice: it can stop the flow, so a possible contradiction can't slip through. This holds at every intake: the scenario read (Phase 1), the testify fixer's notes (Phase 3 step 4), and the review rounds' concerns and the fixers' notes (Phase 4).
- **Group tag.** A reviewer concern carries the `##` group heading of the scenario it is about, and so does a fixer's scenario note. A concern or note with no heading counts as the chunk's own group, the stopping side. One that names another group's heading is handled like a reviewer concern about another group: final report only, never a stop, never passed to a fixer. A contradiction that involves any chunk scenario is about the chunk, whichever group the other scenario sits in; build may also route by whether either named scenario id is in the chunk. This holds at every intake.
- **Readings ledger.** Keep one entry per scenario that has more than one reading: the scenario id, the readings, the reading built, who built it (tdd or a fixer), and any later differing pick. Every built reading enters the ledger when the report that carries it comes back, whatever its source, before any round's ambiguity concerns are filtered against it: readings tdd reports as built, readings a fixer reports as implemented, readings tdd or a fixer reports as already implemented, interpretations tdd reports as `Owner decision:` lines for scenarios with no named reading, and interpretations a fixer reports the same way (BUILD-032). The first reading built for a scenario stands, across runs as well as within one. Build never replaces a ledger entry: a later pick goes in the differing-pick column, whether it comes from a reviewer, from tdd (an existing passing test fixed another reading) or from a fixer (a finding or interpretation that conflicts with the built reading), and it is reported in the final report and never rebuilt (BUILD-031). Every `ambiguity` concern enters the ledger at intake, whatever happens to it, with a status: built (by whom), already implemented, not built (the stopping round), could not implement (the reason), other group (report only), or a note that its `Simplest:` line was missing. A Phase 1 pick that tdd never reports is recorded as not reported by tdd, and section 8 of the final report says so.
- Keep a running ledger in your context: each scenario with its covering test, every finding with its outcome per pass, scenario concerns (each with its kind), the readings ledger above, the rulings made in Phase 1 and the Phase 1 contradictions the user chose to continue past, `Owner decision:` lines, whether the run continued from existing changes and the paths the user approved, unverified comment claims, and command results. The final report is built from it.

## Phase 0: Locate the group and prepare

1. Read the doc. List its `##` headings that contain at least one `###` scenario. Headings with none (Decided, Parked, intro) aren't groups.
2. Match the given heading against that list, ignoring surrounding whitespace and letter case. If the doc is missing, or no group matches, or no heading was given: implement nothing. Print the group headings the doc does have, and tell the user to pick one or to write the missing group with `/mikey:user-scenarios`. Stop (BUILD-002). There is no final report for this stop.
3. The chunk is the text under the matching heading up to the next `##` heading, copied character for character. It holds exactly that group's scenarios, and nothing from any other group is implemented (BUILD-001).
4. Run `git rev-parse HEAD` and keep the result as the **base**. If the directory isn't a usable git repository, stop; a repository with no commits has no base, so that is the same stop. Run `git status --porcelain --untracked-files=all`. If anything is uncommitted other than the scenario doc, list those paths and ask the user one question with the AskUserQuestion tool: continue from these changes, which are then treated as this chunk's work in progress (for example from a run that stopped), or stop. If the user stops, end the run there; there is no final report for this stop. If the user continues, record in the ledger that the run continued from existing changes, with the listed paths. Those paths count as the chunk's files from here on (BUILD-021).
5. Find the **test command** and the **lint command**. Read the project's CLAUDE.md first (it wins), then the Makefile, then package manifests (`package.json` scripts, `pyproject.toml`, `Cargo.toml`, `go.mod` conventions, and similar). For lint, accept only check-only commands: what the project calls lint, static checks, type checks or format checks, run in a mode that reports and never rewrites files. Never accept a formatter or fixer that writes (for example one run with a fix or write flag); if the project's only lint command writes, treat it as having no lint command. If you find no test command, stop and tell the user. If you find no lint command, carry on with tests only and remember to say so in the report (BUILD-016).
6. Print one start line (not a progress line): the group heading, the number of scenarios, whether the run continued from existing changes, the test command, and the lint command or that there is none.

## Phase 1: Read the scenarios

Before any code is written, spawn one fresh `adversarial-reviewer` (`opus`, `medium`) in scenario-read mode with these sections and nothing else: a line saying this is scenario-read mode and that it judges only the chunk's scenarios; the chunk's scenarios verbatim with their Risk paragraphs; the group heading; and the scenario doc's absolute path, so it can read the whole doc, including the other groups and the Decided and Parked sections, as context. Don't give it a diff, a path to the code, or anything from an earlier run. It reads no code (BUILD-027).

Add each concern in its reply to the scenario-concerns ledger with its kind, copied as written (an unlabelled one counts as `contradiction`, see Unlabelled concerns above). Print one line: how many concerns of each kind. Concerns of kind `ambiguity` never stop the flow: each names its readings and the simplest one, which tdd builds (Phase 2) and the final report records (BUILD-031). When an `ambiguity` concern has no `Simplest:` line, the reading to build is the first one the concern lists, and the final report notes that the line was missing. Concerns of kind `missing-or-gap` never stop the flow; they go in the final report (BUILD-020). When the run continued from existing changes, this phase still runs, against the current doc.

If it reports any `contradiction` concern for this group, no code is written yet. Print all of the reader's notes verbatim, the contradictions and the rest, then ask the user one question with the AskUserQuestion tool: rule on the contradictions now, stop, or continue anyway (BUILD-027, BUILD-028).

- **Rule now.** Invoke `/mikey:user-scenarios` with the Skill tool, `skill: "mikey:user-scenarios"`, with arguments: the scenario doc path, then the `contradiction` concerns verbatim as the things to rule on. That skill's own rules apply: one proposal at a time, and the user's approval for every change. When it returns, mark those concerns as ruled on in the ledger and record the rulings it reports. The ambiguity concerns of the read that let the run go on replace those of earlier reads. Re-read the doc and take the chunk again as in Phase 0 step 3, since the chunk's text may have changed and ids may have been retired. If the heading no longer matches a group, stop as in Phase 0 step 2. Then run this phase again with a fresh reader. The question can come again. From here on, every phase uses the current chunk text.
- **Stop.** Say the scenario doc has no changes beyond any the user approved in this phase, no code was written and nothing is committed. Print the final report and end your turn.
- **Continue anyway.** Record the concerns in the ledger as open concerns the user chose to continue past, and keep a list of them keyed by the pair of scenario ids (or the scenario id plus "Decided") each names. Go on to Phase 2. tdd implements the scenarios as written, with the chosen readings for any ambiguity. These concerns don't stop the commit in Phase 6.

Once nothing here stops the run, and before Phase 2, run `git status --porcelain`. If it shows the scenario doc changed, stage only the scenario doc by explicit path and commit it on its own with a short docs message: an imperative subject, a one-line why, the session's attribution trailer, every line 72 characters or fewer, and the project's CLAUDE.md commit rules if it has them. Never amend, push or pass `--no-verify`. Print one line with its short hash. The chunk's code is committed separately in Phase 6 (BUILD-026).

## Phase 2: Implement

Invoke `/mikey:tdd` with the Skill tool, `skill: "mikey:tdd"`, with arguments: the doc path, `--group "<group heading>"`, `--auto`, `--test-command "<the test command found in Phase 0>"`, `--model sonnet`, `--effort high`. When the run continued from existing changes, add `--existing-work`: some of the chunk's scenarios may already have passing covering tests, and the tdd-agent's protocol leaves those alone and implements only what's missing. When the scenario read that let the run go on reported `ambiguity` concerns, write one line per scenario id to a readings file and add `--readings-file "<path>"`: each line holds the scenario id and the chosen reading text only, without the `Simplest:` reason (the reviewer's `Simplest:` reading, or the first listed reading when that line is missing), copied as written. Leave out concerns tagged with another group (BUILD-031). Write the file outside the project tree: in the session's scratchpad directory when its instructions list one, otherwise in a directory made with `mktemp -d`, never inside the repository. Delete it once tdd returns. A readings file you wrote that tdd reports as missing or empty is an error: stop the run before using tdd's result, since the file was just written and something is wrong with the run. Every later step uses that same test command.

`/mikey:tdd` doesn't ask the user to confirm the scenarios (BUILD-003). `/mikey:tdd` prints nothing under `--auto`; this skill is the only party that prints progress. When it returns, print exactly one line per scenario (the scenario id and its covering test, copied from the returned report) and nothing else about the implementing step. Record each scenario with the test that covers it, and copy every `Owner decision:` line in the report into the ledger (BUILD-032). Then enter every built reading in the readings ledger, before Phase 3 or any review round: each reading tdd reports as built or as already implemented (tdd as the builder, with its covering test), and each `Owner decision:` line that gives an interpretation for a scenario with no named reading (tdd as the builder; the scenario id, the readings and the interpretation built come from the line). When tdd reports that an existing passing test fixed a different reading than the Phase 1 pick, enter the existing reading as built and record the pick as a differing pick (BUILD-031). When a fixer later adds or renames a covering test, update this map from its report.

If the report shows a scenario not finished or a suite that isn't green, stop.

## Phase 3: Review test design

From here on, testify, every review round, the comment pass and the gate work on the full diff against the base. When the run continued from existing changes, that diff includes the earlier work.

1. List the files the chunk touched, one path per file with untracked files listed individually: `git status --porcelain --untracked-files=all` and `git diff --name-only <base>`. Keep source and test files only: no scenario doc, no generated artifacts such as reports or plans the run created. Keep only paths that exist on disk: drop deleted paths, and for a rename use the new path.
2. Spawn one `fixer` (`sonnet`, `low`) with: a brief to invoke `/mikey:testify --with-design --auto --files <those paths>` itself with the Skill tool, falling back to reading `${CLAUDE_PLUGIN_ROOT}/skills/testify/SKILL.md` and following it if the skill can't be invoked from a subagent; to apply every finding of every severity per its own protocol and keep the suite green; and to report the findings with outcomes plus the testify grade line. Also pass the chunk's scenarios, a **Built readings** section with every built reading in the readings ledger (each as fixed, with its scenario id), the CLAUDE.md path, the test command, the lint command if any, and the base. Testify reviews only those files (BUILD-005). Fixes that change source code need a test that fails without them (BUILD-006); the fixer's protocol covers that. The main session doesn't invoke testify.
3. Take the findings and outcomes in the fixer's report as the finding list.
4. Record each finding with the fixer's outcome, any scenario note (with the group heading and the kind the fixer gave it, treated like a reviewer concern, see Group tag and Unlabelled concerns above), every `Owner decision:` line (BUILD-032), and any out-of-scope note. Record each differing pick the fixer reports. Enter each reading the fixer reports as already implemented, and each `Owner decision:` line that gives an interpretation of a scenario, in the readings ledger with the fixer as the builder. Update the scenario-to-test map from the fixer's report. Print one line: the testify finding counts by severity and how many the fixer fixed. If the suite isn't green afterwards, stop.

## Phase 4: Review rounds

Run up to three rounds. Each round is a fresh reviewer, then a fresh fixer.

**Reviewer.** Spawn `adversarial-reviewer` (`opus`, `medium`) with these sections and nothing else: the chunk's scenarios verbatim with their Risk paragraphs; the scenario doc path and group heading; the base commit; the CLAUDE.md path; the test command. Don't tell it the round number, what earlier rounds found, what the implementer or any fixer did, or how the code was written (BUILD-007).

**Read the reply.** Take the finding counts from the reviewer's counts line, and check them against its findings. If they disagree, treat the listed findings as the truth and note the mismatch for the final report. Print one line: the round number and the counts by severity (BUILD-012). Don't show the findings in this line. Keep them in the ledger for the final report; they are shown in full only at a stop (BUILD-010, BUILD-029) and in the final report (BUILD-012). Add any entries under Scenario concerns to the scenario-concerns ledger, each with the group heading and the kind the reviewer tagged it with (see Group tag and Unlabelled concerns above). Never pass a `contradiction` or `missing-or-gap` concern to a fixer (BUILD-020, BUILD-029). For each `ambiguity` concern: one about another group goes in the final report only. One for this chunk's group about a scenario already in the readings ledger with a built reading is not passed to the fixer: record its pick under that scenario as a differing pick when it differs from the built reading, and the code is not rebuilt (BUILD-031). Only the remaining `ambiguity` concerns for this chunk's group, those about scenarios with no built reading, go to the round's fixer as the readings to implement. An `ambiguity` concern with no `Simplest:` line takes the first listed reading, as in Phase 1, and the report notes it. When the round is the one that stops the run (three rounds run and a HIGH finding), no fixer is spawned: record its readings as found and not built.

**Decide.**
- Three rounds have run and this round reported a HIGH finding: stop (BUILD-010). Don't spawn a fixer, so this round's findings stay exactly as the reviewer wrote them. Commit nothing. Print the open HIGH findings verbatim, and what each earlier round tried (from the fixer reports). Print the final report and end your turn.
- The round reported no findings and no `ambiguity` concern that goes to a fixer: the loop ends.
- Otherwise spawn a `fixer` (`sonnet`, `low`) with: every finding of the round verbatim, HIGH or not (none, when the round reported only ambiguity concerns); an **Ambiguity readings** section when the round has ambiguity concerns that go to a fixer (see Read the reply), one entry per concern with the scenario id, the readings and the reading the reviewer chose, copied as written; the chunk's scenarios with Risks; a **Built readings** section with every built reading in the readings ledger, as fixed; the CLAUDE.md path; the test command; the lint command if any; the base. For a behavior finding the fixer writes the failing test first and the suite is green when it finishes (BUILD-008). Record each finding's outcome, each differing pick the fixer reports (under its scenario, in the differing-pick column), whether each reading was implemented, already implemented or could not be implemented (with the reason), and add each reading reported as implemented or already implemented to the readings ledger with the fixer as the builder. Also record any scenario note (with the group heading and the kind the fixer gave it, treated like a reviewer concern, see Group tag and Unlabelled concerns above), every `Owner decision:` line (BUILD-032), and any out-of-scope note, and enter each `Owner decision:` line that gives an interpretation of a scenario in the readings ledger with the fixer as the builder. Update the scenario-to-test map from the fixer's report. If the suite isn't green afterwards, stop.
- If that round reported no HIGH finding, the loop ends (BUILD-009), even when the fixer could not fix a MEDIUM or LOW finding. Such a finding never blocks the loop or the commit; it stays in the ledger and appears in the final report. If it reported a HIGH finding, start the next round. A reading the fixer built in a round with no HIGH finding triggers no extra round: the fixer wrote the failing test first (BUILD-008) and the final report lists the reading.

## Phase 5: Clean comments

Spawn a `general-purpose` subagent (`sonnet`, `low`) with: the test command. Tell it to invoke the Skill tool with `skill: "mikey:comment-review"` and argument `--apply`, so comment-review uses its default scope (the working-tree diff against HEAD, including untracked files), and to run the test command afterwards (BUILD-013). If that skill can't be invoked from the subagent, it reads `${CLAUDE_PLUGIN_ROOT}/skills/comment-review/SKILL.md` and follows it as written. Tell it to exclude the scenario doc from comment-review's scope and never to change git state.

From its report, record the edit counts and each comment claim it could not verify, copied as written with `file:line`. Those comments stay as written (BUILD-014). Print one line with the edit counts. If the suite isn't green afterwards, stop.

## Phase 6: Check and commit

1. If any review round's concern, or any scenario note from the testify fixer (Phase 3) or a review-round fixer (Phase 4), is of kind `contradiction` (or unlabelled), tagged with this chunk's own group heading (or with no heading, see Group tag), and names a pair that is not in the list of contradictions continued past in Phase 1: commit nothing. Print each such concern or note verbatim, with the round or phase that raised it, and say the scenario doc is unchanged and the flow waits for the user's ruling. Print the final report and end your turn (BUILD-029). Phase 1 concerns never reach this step: the user ruled on them, or chose to continue past them (BUILD-028). A later contradiction that names a pair already continued past is recorded as still open and does not stop here; one that names a new pair stops. A concern tagged with any other group heading doesn't stop the flow; it goes in the final report only. A concern of kind `ambiguity` or `missing-or-gap` never stops the flow, whatever group it names (BUILD-031, BUILD-020). Unfixed MEDIUM or LOW findings never stop the flow either (BUILD-009).
2. Run the test command, then the lint command if there is one. Run each command so that only its exit status and its last 20 or so lines reach this session (for example, pipe through `tail -n 20` and read the exit status of the command itself, such as with `set -o pipefail`). Show only the result lines and the counts. If either fails, commit nothing. Print the failing output's last lines, print the final report, and stop. (Both must pass immediately before the commit, BUILD-015.)
3. Stage the chunk's files by explicit path, taken from `git status --porcelain --untracked-files=all`, which lists every file individually. The paths the user approved in Phase 0 count as the chunk's files. Never stage the scenario doc, generated artifacts (reports, plans the run created), and never use `git add -A` or `git add .`.
4. Write the commit message:
   - An imperative subject describing the change.
   - A body that says only why: the problem the chunk's scenarios guard against, drawn from their Risk paragraphs. Don't narrate the diff or list files.
   - A `Test plan:` section with one step for each check you ran (the test command, and the lint command if there was one). Each step names the exact command, and a line after it starts with `Expect:` and says the observable result, such as the passing count from the run.
   - The attribution trailer the session's instructions require for commits.
   - Every line 72 characters or fewer. Check with `awk 'length > 72'` before committing.
   - If the project's CLAUDE.md sets commit rules (subject prefix, ticket reference, trailer, section names), follow those over this list.
5. Commit with `git commit`, passing the message on stdin. Never pass `--amend` or `--no-verify`, and never push (BUILD-015). If a commit hook fails, stop and report it.
6. With no lint command, the commit is gated by tests only and the report says no lint step ran (BUILD-016).

## Phase 7: Final report

Print the report whether the flow committed or stopped (BUILD-017). Build it from the ledger. Don't retype: paths, test names and counts come from the subagents' reports and command output.

1. **Outcome**: the commit subject and short hash, or the stop reason. If the scenario doc was committed before tdd, give that commit's subject and short hash too. If the run continued from existing changes, say so and list the paths the user approved in Phase 0. If the user ruled on scenario-read contradictions, or continued past them, say so.
2. **Scenario read** (Phase 1): for each read, the concerns it reported with their kinds, or none. Then the rulings made through `/mikey:user-scenarios`, and the contradictions the user chose to continue past, or none (BUILD-028).
3. **Scenarios**: each scenario id in the chunk with the test that covers it.
4. **Test-design review**: each testify finding with its outcome.
5. **Review rounds**: for each round, every finding with its severity, `file:line` and outcome (fixed, could not fix and why, or left unfixed for a stopped round 3).
6. **Scenario concerns**: each concern of kind `contradiction` verbatim with its group heading, marking which stopped the flow, which the user ruled on, which the user continued past (including later ones that named the same pair, marked as continued past) and which are about another group, or none.
7. **Suggested scenarios and gaps**: each concern of kind `missing-or-gap` verbatim with its group heading, or none. These never stopped the flow and no fixer saw them.
8. **Ambiguity readings**: from the readings ledger, per scenario with its group heading: the readings, the status (built and why, and who built it, tdd or a fixer; already implemented; not built, for a reading found by the round that stopped the run; could not implement, with the reason; other group, report only), and any later differing pick by a reviewer, tdd or a fixer, which was reported and not built. A missing `Simplest:` line is noted, and so is a Phase 1 pick that tdd never reported. Or none. These never stopped the flow and the scenario doc is unchanged; they are the readings for you to confirm or change, next to the owner decisions (BUILD-031).
9. **Owner decisions**: each `Owner decision:` line from tdd and the fixers, copied as written with its value or interpretation, `file:line` and reason, or none. These are product values and interpretations no scenario or Decided note fixes, for you to confirm or change (BUILD-032).
10. **Comment claims left for you**: each unverified claim with `file:line`, or none.
11. **Results**: the test command and its result, the lint command and its result, or that no lint step ran.

## Stops at a glance

Print the final report at every stop except the unmatched-group stop and a stop the user chose at the existing-changes question. Stops before the commit show the user the output tail. A stop after Phase 0 leaves the chunk's changes in the tree; the next run asks whether to continue from them.

| Condition | Result |
|-----------|--------|
| Heading not a group in the doc | Nothing implemented, headings listed (BUILD-002) |
| Changes beyond the scenario doc, and the user chose to stop | Pre-flight stop, paths listed, no final report (BUILD-021) |
| Changes beyond the scenario doc, and the user chose to continue | No stop; the paths count as the chunk's files and the final report lists them (BUILD-021) |
| No test command found | Pre-flight stop |
| Directory isn't a usable git repository (or has no commits) | Pre-flight stop |
| A contradiction in this group, from the scenario read | Scenario read: concerns printed verbatim, no code written yet, and the user chooses: rule now (`/mikey:user-scenarios`, then a fresh read), stop (no commit, final report), or continue anyway (concerns stay open in the final report) (BUILD-027, BUILD-028) |
| A subagent leaves the suite red | Mid-flow stop before the commit, output tail shown |
| tdd leaves a scenario unfinished | Mid-flow stop before the commit, output tail shown |
| A commit hook fails | Mid-flow stop, output tail shown |
| Round 3 reports a HIGH finding | No commit, round 3 findings unfixed (BUILD-010) |
| Any round raised a contradiction (or an unlabelled concern) about this chunk's own group, from a review round, the testify fixer's notes or a round fixer's notes, and not already continued past | No commit, doc unchanged, user rules (BUILD-029) |
| Tests or lint fail at the gate | No commit, output tail shown |
| An ambiguity (built as its chosen reading, or reported when a reading already stands or the round stopped the run), a contradiction about another group, a missing-scenario or gap suggestion, an `Owner decision:`, or an unfixed MEDIUM or LOW finding | No stop; listed in the final report (BUILD-009, BUILD-029, BUILD-031, BUILD-020, BUILD-032) |
