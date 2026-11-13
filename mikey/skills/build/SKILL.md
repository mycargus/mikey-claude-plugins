---
name: mikey:build
description: "Implement one approved chunk of Given/When/Then scenarios end to end: TDD, test-design review, up to three adversarial review and fix rounds, comment cleanup, and a commit. Use when the user says 'build the chunk', 'implement this group', 'run the build loop', 'build this scenario group', or gives a user-scenarios doc and a group heading to implement. The main session only coordinates; subagents write every change."
argument-hint: <doc path> "<group heading>"
user-invocable: true
---

# Build

Implements one `##` group of an approved user-scenarios doc. The scenarios are written and approved beforehand with `/mikey:user-scenarios`. This skill never proposes, edits, or reorders scenarios.

Specification: `docs/user-scenarios/mikey-build.md` (BUILD-001 to BUILD-017). Design record: `docs/adr/adr-011-build-orchestrator.md`.

| Parameter | Description |
|-----------|-------------|
| `doc path` | The user-scenarios doc |
| `group heading` | The text of one `##` heading in that doc. One invocation is one chunk |

## How the flow runs

1. Locate the group and prepare (Phase 0).
2. Implement with `/mikey:tdd` (Phase 1).
3. A fixer subagent runs `/mikey:testify` on the touched files and applies its findings (Phase 2).
4. Review rounds: a fresh reviewer, then a fresh fixer, up to three rounds (Phase 3).
5. Clean comments (Phase 4).
6. Check tests and lint, then commit (Phase 5).
7. Print the final report (Phase 6), whether the flow committed or stopped.

## Roles

Pass `model` and `effort` on every spawn exactly as this table says.

| Role | Agent | Model | Effort |
|------|-------|-------|--------|
| Implementer | `tdd-agent`, spawned by `/mikey:tdd` | `sonnet` | `high` |
| Test-design fixer | `fixer`, which invokes `/mikey:testify` itself | `sonnet` | `low` |
| Test-design analysis | `analysis-agent`, spawned by `/mikey:testify` | inherits the invoking fixer | inherits |
| Review-round fixer | `fixer` | `sonnet` | `low` |
| Adversarial reviewer | `adversarial-reviewer` | `opus` | `medium` |
| Comment reviewer | `general-purpose` | `sonnet` | `low` |

Name the agents `mikey:adversarial-reviewer` and `mikey:fixer`. If the qualified form doesn't resolve, use the bare name.

Every reviewer and every fixer is a new spawn. Never continue an earlier one with SendMessage, and never tell one about another.

## Rules for the main session

- **Never edit a project file yourself**, not even a one-line fix. Source, test and doc changes come from subagents. The main session only coordinates: it reads the project's conventions and git state, invokes the skills, briefs subagents, reads their reports, runs the final test, lint and commit commands, and talks to the user.
- **Brief with dynamic context only.** The protocols live in the agent files and in the skills you invoke (ADR-005). A brief carries the scenarios, paths, the base commit, commands and findings, and nothing else. Do not add instructions that restate a protocol, and never include your own opinion of the code.
- **Copy, don't retype.** Scenario text, findings, file paths, test names and counts are copied from the doc, the subagents' reports and command output. Never recompose them from memory.
- **Never push. Never amend.** Always a new commit.
- **Never change the scenario doc.** A scenario you think is wrong goes to the user (BUILD-011).
- **Output is one line per step.** Print one line per step of the flow (start, tdd, testify-and-fix, each review round, comment pass, gate, commit), plus the per-scenario lines when tdd returns, and nothing else except at a stop or in the final report.
- **A stop is a stop.** When a rule below says the flow stops, print what it says, print the final report (Phase 6), and end your turn. Don't continue until the user says what to do.
- Keep a running ledger in your context: each scenario with its covering test, every finding with its outcome per pass, scenario concerns, unverified comment claims, and command results. The final report is built from it.

## Phase 0: Locate the group and prepare

1. Read the doc. List its `##` headings that contain at least one `###` scenario. Headings with none (Decided, Parked, intro) aren't groups.
2. Match the given heading against that list, ignoring surrounding whitespace and letter case. If the doc is missing, or no group matches, or no heading was given: implement nothing. Print the group headings the doc does have, and tell the user to pick one or to write the missing group with `/mikey:user-scenarios`. Stop (BUILD-002). There is no final report for this stop.
3. The chunk is the text under the matching heading up to the next `##` heading, copied character for character. It holds exactly that group's scenarios, and nothing from any other group is implemented (BUILD-001).
4. Run `git rev-parse HEAD` and keep the result as the **base**. Run `git status --porcelain --untracked-files=all`. If anything is uncommitted other than the scenario doc, stop and tell the user which paths: the commit must hold only this chunk's changes. If the directory isn't a usable git repository, stop; a repository with no commits has no base, so that is the same stop.
5. Find the **test command** and the **lint command**. Read the project's CLAUDE.md first (it wins), then the Makefile, then package manifests (`package.json` scripts, `pyproject.toml`, `Cargo.toml`, `go.mod` conventions, and similar). For lint, accept only check-only commands: what the project calls lint, static checks, type checks or format checks, run in a mode that reports and never rewrites files. Never accept a formatter or fixer that writes (for example one run with a fix or write flag); if the project's only lint command writes, treat it as having no lint command. If you find no test command, stop and tell the user. If you find no lint command, carry on with tests only and remember to say so in the report (BUILD-016).
6. Print one start line (not a progress line): the group heading, the number of scenarios, the test command, and the lint command or that there is none.

## Phase 1: Implement

Invoke `/mikey:tdd` with the Skill tool, `skill: "mikey:tdd"`, with arguments: the doc path, `--group "<group heading>"`, `--auto`, `--test-command "<the test command found in Phase 0>"`, `--model sonnet`, `--effort high`. Every later step uses that same test command.

`/mikey:tdd` doesn't ask the user to confirm the scenarios (BUILD-003). `/mikey:tdd` prints nothing under `--auto`; this skill is the only party that prints progress. When it returns, print exactly one line per scenario (the scenario id and its covering test, copied from the returned report) and nothing else about the implementing step. Record each scenario with the test that covers it. When a fixer later adds or renames a covering test, update this map from its report.

If the report shows a scenario not finished or a suite that isn't green, stop.

## Phase 2: Review test design

1. List the files the chunk touched, one path per file with untracked files listed individually: `git status --porcelain --untracked-files=all` and `git diff --name-only <base>`. Keep source and test files only: no scenario doc, no generated artifacts such as reports or plans the run created. Keep only paths that exist on disk: drop deleted paths, and for a rename use the new path.
2. Spawn one `fixer` (`sonnet`, `low`) with: a brief to invoke `/mikey:testify --with-design --auto --files <those paths>` itself with the Skill tool, falling back to reading `${CLAUDE_PLUGIN_ROOT}/skills/testify/SKILL.md` and following it if the skill can't be invoked from a subagent; to apply every finding of every severity per its own protocol and keep the suite green; and to report the findings with outcomes plus the testify grade line. Also pass the chunk's scenarios, the CLAUDE.md path, the test command, the lint command if any, and the base. Testify reviews only those files (BUILD-005). Fixes that change source code need a test that fails without them (BUILD-006); the fixer's protocol covers that. The main session doesn't invoke testify.
3. Take the findings and outcomes in the fixer's report as the finding list.
4. Record each finding with the fixer's outcome, any "scenario seems wrong" note (tagged with the group heading, treated like a reviewer concern), and any out-of-scope note. Update the scenario-to-test map from the fixer's report. Print one line: the testify finding counts by severity and how many the fixer fixed. If the suite isn't green afterwards, stop.

## Phase 3: Review rounds

Run up to three rounds. Each round is a fresh reviewer, then a fresh fixer.

**Reviewer.** Spawn `adversarial-reviewer` (`opus`, `medium`) with these sections and nothing else: the chunk's scenarios verbatim with their Risk paragraphs; the scenario doc path and group heading; the base commit; the CLAUDE.md path; the test command. Don't tell it the round number, what earlier rounds found, what the implementer or any fixer did, or how the code was written (BUILD-007).

**Read the reply.** Take the finding counts from the reviewer's counts line, and check them against its findings. If they disagree, treat the listed findings as the truth and note the mismatch for the final report. Print one line: the round number and the counts by severity (BUILD-012). Don't show the findings in this line. Keep them in the ledger for the final report; they are shown in full only at a stop (BUILD-010, BUILD-011) and in the final report (BUILD-012). Add any entries under Scenario concerns to the scenario-concerns ledger, each with the group heading the reviewer tagged it with. Never pass them to a fixer.

**Decide.**
- Three rounds have run and this round reported a HIGH finding: stop (BUILD-010). Don't spawn a fixer, so this round's findings stay exactly as the reviewer wrote them. Commit nothing. Print the open HIGH findings verbatim, and what each earlier round tried (from the fixer reports). Print the final report and end your turn.
- The round reported no findings: the loop ends.
- Otherwise spawn a `fixer` (`sonnet`, `low`) with: every finding of the round verbatim, HIGH or not; the chunk's scenarios with Risks; the CLAUDE.md path; the test command; the lint command if any; the base. For a behavior finding the fixer writes the failing test first and the suite is green when it finishes (BUILD-008). Record each finding's outcome, any "scenario seems wrong" note (tagged with the group heading, treated like a reviewer concern), and any out-of-scope note. Update the scenario-to-test map from the fixer's report. If the suite isn't green afterwards, stop.
- If that round reported no HIGH finding, the loop ends (BUILD-009), even when the fixer could not fix a MEDIUM or LOW finding. Such a finding never blocks the loop or the commit; it stays in the ledger and appears in the final report. If it reported a HIGH finding, start the next round.

## Phase 4: Clean comments

Spawn a `general-purpose` subagent (`sonnet`, `low`) with: the test command. Tell it to invoke the Skill tool with `skill: "mikey:comment-review"` and argument `--apply`, so comment-review uses its default scope (the working-tree diff against HEAD, including untracked files), and to run the test command afterwards (BUILD-013). If that skill can't be invoked from the subagent, it reads `${CLAUDE_PLUGIN_ROOT}/skills/comment-review/SKILL.md` and follows it as written. Tell it to exclude the scenario doc from comment-review's scope and never to change git state.

From its report, record the edit counts and each comment claim it could not verify, copied as written with `file:line`. Those comments stay as written (BUILD-014). Print one line with the edit counts. If the suite isn't green afterwards, stop.

## Phase 5: Check and commit

1. If any round reported a scenario concern tagged with this chunk's own group heading: commit nothing. Print each such concern verbatim, with the round that raised it, and say the scenario doc is unchanged and the flow waits for the user's ruling. Print the final report and end your turn (BUILD-011). A concern tagged with any other group heading doesn't stop the flow; it goes in the final report only. Unfixed MEDIUM or LOW findings never stop the flow either (BUILD-009).
2. Run the test command, then the lint command if there is one. Run each command so that only its exit status and its last 20 or so lines reach this session (for example, pipe through `tail -n 20` and read the exit status of the command itself, such as with `set -o pipefail`). Show only the result lines and the counts. If either fails, commit nothing. Print the failing output's last lines, print the final report, and stop. (Both must pass immediately before the commit, BUILD-015.)
3. Stage the chunk's files by explicit path, taken from `git status --porcelain --untracked-files=all`, which lists every file individually. Never stage the scenario doc, generated artifacts (reports, plans the run created), and never use `git add -A` or `git add .`.
4. Write the commit message:
   - An imperative subject describing the change.
   - A body that says only why: the problem the chunk's scenarios guard against, drawn from their Risk paragraphs. Don't narrate the diff or list files.
   - A `Test plan:` section with one step for each check you ran (the test command, and the lint command if there was one). Each step names the exact command, and a line after it starts with `Expect:` and says the observable result, such as the passing count from the run.
   - The attribution trailer the session's instructions require for commits.
   - Every line 72 characters or fewer. Check with `awk 'length > 72'` before committing.
   - If the project's CLAUDE.md sets commit rules (subject prefix, ticket reference, trailer, section names), follow those over this list.
5. Commit with `git commit`, passing the message on stdin. Never pass `--amend` or `--no-verify`, and never push (BUILD-015). If a commit hook fails, stop and report it.
6. With no lint command, the commit is gated by tests only and the report says no lint step ran (BUILD-016).

## Phase 6: Final report

Print the report whether the flow committed or stopped (BUILD-017). Build it from the ledger. Don't retype: paths, test names and counts come from the subagents' reports and command output.

1. **Outcome**: the commit subject and short hash, or the stop reason.
2. **Scenarios**: each scenario id in the chunk with the test that covers it.
3. **Test-design review**: each testify finding with its outcome.
4. **Review rounds**: for each round, every finding with its severity, `file:line` and outcome (fixed, could not fix and why, or left unfixed for a stopped round 3).
5. **Scenario concerns**: each one verbatim with its group heading, marking which stopped the flow and which are about another group, or none.
6. **Comment claims left for you**: each unverified claim with `file:line`, or none.
7. **Results**: the test command and its result, the lint command and its result, or that no lint step ran.

## Stops at a glance

Print the final report at every stop except the unmatched-group stop. Stops before the commit show the user the output tail.

| Condition | Result |
|-----------|--------|
| Heading not a group in the doc | Nothing implemented, headings listed (BUILD-002) |
| Dirty tree beyond the scenario doc | Pre-flight stop, paths listed |
| No test command found | Pre-flight stop |
| Directory isn't a usable git repository (or has no commits) | Pre-flight stop |
| A subagent leaves the suite red | Mid-flow stop before the commit, output tail shown |
| tdd leaves a scenario unfinished | Mid-flow stop before the commit, output tail shown |
| A commit hook fails | Mid-flow stop, output tail shown |
| Round 3 reports a HIGH finding | No commit, round 3 findings unfixed (BUILD-010) |
| Any round raised a scenario concern about this chunk's own group | No commit, doc unchanged, user rules (BUILD-011) |
| Tests or lint fail at the gate | No commit, output tail shown |
| A concern about another group, or an unfixed MEDIUM or LOW finding | No stop; listed in the final report (BUILD-009, BUILD-011) |
