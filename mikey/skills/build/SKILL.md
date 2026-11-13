---
name: mikey:build
description: "Implement one approved chunk of Given/When/Then scenarios end to end: TDD, test-design review, up to three adversarial review and fix rounds, comment cleanup, and a commit. Use when the user says 'build the chunk', 'implement this group', 'run the build loop', 'build this scenario group', or gives a user-scenarios doc and a group heading to implement. The main session only coordinates; subagents write every change."
argument-hint: <doc path> "<group heading>" [--resume | --discard]
user-invocable: true
---

# Build

Implements one `##` group of an approved user-scenarios doc. The scenarios are written and approved beforehand with `/mikey:user-scenarios`. This skill never proposes, edits, or reorders scenarios.

Specification: `docs/user-scenarios/mikey-build.md` (BUILD-001 to BUILD-017). Design record: `docs/adr/adr-011-build-orchestrator.md`.

| Parameter | Description |
|-----------|-------------|
| `doc path` | The user-scenarios doc |
| `group heading` | The text of one `##` heading in that doc. One invocation is one chunk |
| `--resume` | Continue a stopped run for this doc and group in its existing worktree, with its original base |
| `--discard` | Remove the stopped worktree and branch for this doc and group, then start fresh from the current HEAD |

Passing both flags is an error: stop and say so.

## How the flow runs

1. Locate the group, set up the work worktree and prepare (Phase 0).
2. A fresh reviewer reads the scenarios, with no code (Phase 1).
3. Implement with `/mikey:tdd` (Phase 2).
4. A fixer subagent runs `/mikey:testify` on the touched files and applies its findings (Phase 3).
5. Review rounds: a fresh reviewer, then a fresh fixer, up to three rounds (Phase 4).
6. Clean comments (Phase 5).
7. Check tests and lint, commit in the worktree, then bring the commit to the starting branch (Phase 6).
8. Print the final report (Phase 7), whether the flow committed or stopped.

All work happens in a git worktree on a work branch, so a stop leaves the original checkout clean and the run can be resumed.

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

- **Never edit a project file yourself**, not even a one-line fix. Source, test and doc changes come from subagents. The main session only coordinates: it reads the project's conventions and git state, invokes the skills, briefs subagents, reads their reports, runs the final test, lint and commit commands, and talks to the user.
- **Brief with dynamic context only.** The protocols live in the agent files and in the skills you invoke (ADR-005). A brief carries the scenarios, paths, the worktree path, the base commit, commands and findings, and nothing else. Do not add instructions that restate a protocol, and never include your own opinion of the code.
- **Copy, don't retype.** Scenario text, findings, file paths, test names and counts are copied from the doc, the subagents' reports and command output. Never recompose them from memory.
- **Never push. Never amend.** Always a new commit.
- **Work in the worktree.** After Phase 0 every subagent brief names the worktree's absolute path and tells the subagent to run every command there and edit only files under it. The main session runs its own git, test and lint commands there too, with `git -C <worktree>` or a `cd`. Only Phase 0 and the hand-off in Phase 6 touch the original checkout.
- **Never change the scenario doc.** A scenario you think is wrong goes to the user (BUILD-011).
- **Output is one line per step.** Print one line per step of the flow (start, scenario read, tdd, testify-and-fix, each review round, comment pass, gate, commit), plus the per-scenario lines when tdd returns, and nothing else except at a stop or in the final report.
- **A stop is a stop.** When a rule below says the flow stops, print what it says, print the final report (Phase 7), and end your turn. Don't continue until the user says what to do.
- Keep a running ledger in your context: each scenario with its covering test, every finding with its outcome per pass, scenario concerns (each with its kind), `Owner decision:` lines, unverified comment claims, and command results. The final report is built from it.

## Phase 0: Locate the group and prepare

1. Read the doc. List its `##` headings that contain at least one `###` scenario. Headings with none (Decided, Parked, intro) aren't groups.
2. Match the given heading against that list, ignoring surrounding whitespace and letter case. If the doc is missing, or no group matches, or no heading was given: implement nothing. Print the group headings the doc does have, and tell the user to pick one or to write the missing group with `/mikey:user-scenarios`. Stop (BUILD-002). There is no final report for this stop.
3. The chunk is the text under the matching heading up to the next `##` heading, copied character for character. It holds exactly that group's scenarios, and nothing from any other group is implemented (BUILD-001).
4. Run `git status --porcelain --untracked-files=all` in the original checkout. If anything is uncommitted other than the scenario doc, stop and tell the user which paths. The dirty-tree stop checks the original checkout only, never the worktree: the commit must hold only this chunk's changes, and the hand-off in Phase 6 needs a clean checkout. If the directory isn't a usable git repository, stop; a repository with no commits has no base, so that is the same stop.
5. Find the **test command** and the **lint command**. Read the project's CLAUDE.md first (it wins), then the Makefile, then package manifests (`package.json` scripts, `pyproject.toml`, `Cargo.toml`, `go.mod` conventions, and similar). For lint, accept only check-only commands: what the project calls lint, static checks, type checks or format checks, run in a mode that reports and never rewrites files. Never accept a formatter or fixer that writes (for example one run with a fix or write flag); if the project's only lint command writes, treat it as having no lint command. If you find no test command, stop and tell the user. If you find no lint command, carry on with tests only and remember to say so in the report (BUILD-016).
6. Name the run. The **key** is the first 8 characters of `git hash-object --stdin` run on the doc's path relative to the repository root, a newline, and the group heading as matched (letter case folded, whitespace trimmed). The **slug** is the heading in lowercase with every run of other characters turned into one hyphen, cut to 40 characters. The **work branch** is `mikey-build/<slug>-<key>`. The **worktree** is `<repo name>.build-<slug>-<key>`, a sibling of the original checkout's directory. The same doc and heading always give the same names.
7. Look for a stopped run: `git worktree list --porcelain`, and `git rev-parse --verify --quiet refs/heads/<work branch>`.
   - Both `--resume` and `--discard` given: stop and say so.
   - A stopped worktree or branch exists and neither flag was given: stop before doing anything. Print the worktree path, the branch name and the base it was created from (read from the branch's config, below), and tell the user to re-run with `--resume` to continue it or `--discard` to throw it away.
   - `--discard`: remove the worktree with `git worktree remove --force <path>`, delete the branch with `git update-ref -d refs/heads/<work branch>`, run `git worktree prune`, and remove the branch's config section with `git config --remove-section branch.<work branch>`. Then start fresh. Nothing in the stopped worktree is kept.
   - `--resume` and no stopped worktree or branch: stop and say so.
   - `--resume` and a stopped worktree: keep its **base**, the starting branch and the stored chunk (see below). Compare the chunk's current text against the stored chunk with `git cat-file -p`. If it differs, print the scenario ids added, changed and removed, then continue. Check `git -C <worktree> status` for an unfinished merge or rebase and stop if there is one.
   - No stopped run and no flag: start fresh. `--resume` is the only way to reuse a worktree.
8. Fresh start: run `git rev-parse HEAD` and keep the result as the **base**. Record the starting branch with `git symbolic-ref -q HEAD` (empty when HEAD is detached). Create the worktree and branch with `git worktree add -b <work branch> <worktree path> <base>`. Store the run's facts in the branch's config so a later session can read them: `git config branch.<work branch>.buildBase <base>`, `.buildStart <starting ref>`, and `.buildChunk <blob>`, where the blob is the chunk text written with `git hash-object -w --stdin`. Nothing goes in the project tree. The scenario doc stays where it is and is read from the original checkout by absolute path.
9. Print one start line (not a progress line): the group heading, the number of scenarios, whether this is a fresh run or a resume, the worktree path, the test command, and the lint command or that there is none.

## Phase 1: Read the scenarios

Before any code is written, spawn one fresh `adversarial-reviewer` (`opus`, `medium`) in scenario-read mode with these sections and nothing else: the chunk's scenarios verbatim with their Risk paragraphs, and the doc's Decided section copied verbatim (every `##` section whose heading starts with Decided; say there is none if the doc has none). Don't give it a diff, a path to the code or the worktree, or anything from an earlier run. It reads no code.

Add each concern in its reply to the scenario-concerns ledger with its kind, copied as written. Print one line: how many concerns of each kind. If it reports any `ambiguity-or-contradiction` concern for this group, stop before tdd: print each one verbatim, say the scenario doc is unchanged and no code was written and nothing is committed, print the final report and end your turn. Concerns of kind `missing-or-gap` never stop the flow; they go in the final report. On a re-run, this phase runs again against the current doc.

## Phase 2: Implement

On a fresh run, change into the worktree and invoke `/mikey:tdd` with the Skill tool, `skill: "mikey:tdd"`, with arguments: the doc path, `--group "<group heading>"`, `--auto`, `--test-command "<the test command found in Phase 0>"`, `--model sonnet`, `--effort high`. Every later step uses that same test command.

On `--resume`, `/mikey:tdd` has no way to receive the earlier state, so spawn `tdd-agent` directly (`sonnet`, `high`) with the same context `/mikey:tdd` would give it (project context, the scenarios as numbered Given/When/Then blocks copied verbatim with their Risk paragraphs), the worktree path, and an **Existing work** section: the base, and the output of `git -C <worktree> status --porcelain --untracked-files=all` and `git -C <worktree> diff --name-only <base>`. If the chunk changed since the stopped run, add the added, changed and removed scenario ids from Phase 0. The agent's protocol says what to do with it: scenarios that already have a passing covering test are not rewritten, and only new or changed ones go through red-green-refactor.

`/mikey:tdd` doesn't ask the user to confirm the scenarios (BUILD-003). `/mikey:tdd` prints nothing under `--auto`; this skill is the only party that prints progress. When it returns, print exactly one line per scenario (the scenario id and its covering test, copied from the returned report) and nothing else about the implementing step. Record each scenario with the test that covers it, and copy every `Owner decision:` line in the report into the ledger. When a fixer later adds or renames a covering test, update this map from its report.

If the report shows a scenario not finished or a suite that isn't green, stop.

## Phase 3: Review test design

1. List the files the chunk touched, one path per file with untracked files listed individually: `git status --porcelain --untracked-files=all` and `git diff --name-only <base>`. Keep source and test files only: no scenario doc, no generated artifacts such as reports or plans the run created. Keep only paths that exist on disk: drop deleted paths, and for a rename use the new path.
2. Spawn one `fixer` (`sonnet`, `low`) with: a brief to invoke `/mikey:testify --with-design --auto --files <those paths>` itself with the Skill tool, falling back to reading `${CLAUDE_PLUGIN_ROOT}/skills/testify/SKILL.md` and following it if the skill can't be invoked from a subagent; to apply every finding of every severity per its own protocol and keep the suite green; and to report the findings with outcomes plus the testify grade line. Also pass the chunk's scenarios, the worktree path, the CLAUDE.md path, the test command, the lint command if any, and the base. Testify reviews only those files (BUILD-005). Fixes that change source code need a test that fails without them (BUILD-006); the fixer's protocol covers that. The main session doesn't invoke testify.
3. Take the findings and outcomes in the fixer's report as the finding list.
4. Record each finding with the fixer's outcome, any "scenario seems wrong" note (tagged with the group heading and kind `ambiguity-or-contradiction`, treated like a reviewer concern), every `Owner decision:` line, and any out-of-scope note. Update the scenario-to-test map from the fixer's report. Print one line: the testify finding counts by severity and how many the fixer fixed. If the suite isn't green afterwards, stop.

## Phase 4: Review rounds

Run up to three rounds. Each round is a fresh reviewer, then a fresh fixer.

**Reviewer.** Spawn `adversarial-reviewer` (`opus`, `medium`) with these sections and nothing else: the chunk's scenarios verbatim with their Risk paragraphs; the scenario doc path and group heading; the worktree path; the base commit; the CLAUDE.md path; the test command. Don't tell it the round number, what earlier rounds found, what the implementer or any fixer did, or how the code was written (BUILD-007).

**Read the reply.** Take the finding counts from the reviewer's counts line, and check them against its findings. If they disagree, treat the listed findings as the truth and note the mismatch for the final report. Print one line: the round number and the counts by severity (BUILD-012). Don't show the findings in this line. Keep them in the ledger for the final report; they are shown in full only at a stop (BUILD-010, BUILD-011) and in the final report (BUILD-012). Add any entries under Scenario concerns to the scenario-concerns ledger, each with the group heading and the kind the reviewer tagged it with. A concern with no kind label counts as `ambiguity-or-contradiction`, the safer choice: it can stop the flow, and a missing scenario can't slip through. Never pass any concern to a fixer, whatever its kind.

**Decide.**
- Three rounds have run and this round reported a HIGH finding: stop (BUILD-010). Don't spawn a fixer, so this round's findings stay exactly as the reviewer wrote them. Commit nothing. Print the open HIGH findings verbatim, and what each earlier round tried (from the fixer reports). Print the final report and end your turn.
- The round reported no findings: the loop ends.
- Otherwise spawn a `fixer` (`sonnet`, `low`) with: every finding of the round verbatim, HIGH or not; the chunk's scenarios with Risks; the worktree path; the CLAUDE.md path; the test command; the lint command if any; the base. For a behavior finding the fixer writes the failing test first and the suite is green when it finishes (BUILD-008). Record each finding's outcome, any "scenario seems wrong" note (tagged with the group heading and kind `ambiguity-or-contradiction`, treated like a reviewer concern), every `Owner decision:` line, and any out-of-scope note. Update the scenario-to-test map from the fixer's report. If the suite isn't green afterwards, stop.
- If that round reported no HIGH finding, the loop ends (BUILD-009), even when the fixer could not fix a MEDIUM or LOW finding. Such a finding never blocks the loop or the commit; it stays in the ledger and appears in the final report. If it reported a HIGH finding, start the next round.

## Phase 5: Clean comments

Spawn a `general-purpose` subagent (`sonnet`, `low`) with: the worktree path and the test command. Tell it to invoke the Skill tool with `skill: "mikey:comment-review"` and argument `--apply`, so comment-review uses its default scope (the working-tree diff against HEAD, including untracked files), and to run the test command afterwards (BUILD-013). If that skill can't be invoked from the subagent, it reads `${CLAUDE_PLUGIN_ROOT}/skills/comment-review/SKILL.md` and follows it as written. Tell it to exclude the scenario doc from comment-review's scope and never to change git state.

From its report, record the edit counts and each comment claim it could not verify, copied as written with `file:line`. Those comments stay as written (BUILD-014). Print one line with the edit counts. If the suite isn't green afterwards, stop.

## Phase 6: Check and commit

1. If any round or Phase 1 reported a concern of kind `ambiguity-or-contradiction` tagged with this chunk's own group heading: commit nothing. Print each such concern verbatim, with the round that raised it, and say the scenario doc is unchanged and the flow waits for the user's ruling. Print the final report and end your turn (BUILD-011). A concern tagged with any other group heading doesn't stop the flow; it goes in the final report only. A concern of kind `missing-or-gap` never stops the flow, whatever group it names. Unfixed MEDIUM or LOW findings never stop the flow either (BUILD-009).
2. In the worktree, run the test command, then the lint command if there is one. Run each command so that only its exit status and its last 20 or so lines reach this session (for example, pipe through `tail -n 20` and read the exit status of the command itself, such as with `set -o pipefail`). Show only the result lines and the counts. If either fails, commit nothing. Print the failing output's last lines, print the final report, and stop. (Both must pass immediately before the commit, BUILD-015.)
3. Stage the chunk's files in the worktree by explicit path, taken from `git status --porcelain --untracked-files=all`, which lists every file individually. Never stage the scenario doc, generated artifacts (reports, plans the run created), and never use `git add -A` or `git add .`. Only the chunk's files are committed.
4. Write the commit message:
   - An imperative subject describing the change.
   - A body that says only why: the problem the chunk's scenarios guard against, drawn from their Risk paragraphs. Don't narrate the diff or list files.
   - A `Test plan:` section with one step for each check you ran (the test command, and the lint command if there was one). Each step names the exact command, and a line after it starts with `Expect:` and says the observable result, such as the passing count from the run.
   - The attribution trailer the session's instructions require for commits.
   - Every line 72 characters or fewer. Check with `awk 'length > 72'` before committing.
   - If the project's CLAUDE.md sets commit rules (subject prefix, ticket reference, trailer, section names), follow those over this list.
5. Commit in the worktree with `git commit`, passing the message on stdin. It is the only commit on the work branch. Never pass `--amend` or `--no-verify`, and never push (BUILD-015). If a commit hook fails, stop and report it; the worktree stays for `--resume`.
6. With no lint command, the commit is gated by tests only and the report says no lint step ran (BUILD-016).
7. Bring the commit to the user's branch, with no amend and no push. In the original checkout, confirm `git symbolic-ref -q HEAD` still names the starting ref and `git status --porcelain --untracked-files=all` shows nothing but the scenario doc; if not, stop and leave the worktree and branch in place. If `git rev-parse HEAD` still equals the base, run `git merge --ff-only <work branch>`. If the branch has moved on, run `git cherry-pick <commit>`; on a conflict run `git cherry-pick --abort`, stop, and leave the worktree and branch in place. After a cherry-pick, run the test command once in the original checkout and report its result.
8. Clean up. Run `git worktree remove <path>` without `--force`. If it refuses because the worktree holds uncommitted files, leave the worktree and branch and put their path in the final report. Otherwise delete the branch with `git branch -d <work branch>` after a fast-forward, or with `git update-ref -d refs/heads/<work branch>` after a cherry-pick (the commit is already on the user's branch), and remove the branch's config section with `git config --remove-section branch.<work branch>`.

## Phase 7: Final report

Print the report whether the flow committed or stopped (BUILD-017). Build it from the ledger. Don't retype: paths, test names and counts come from the subagents' reports and command output.

1. **Outcome**: the commit subject and short hash, or the stop reason. Say whether the run was fresh or resumed, and the worktree path and branch if they still exist.
2. **Scenario read** (Phase 1): the concerns it reported with their kinds, or none.
3. **Scenarios**: each scenario id in the chunk with the test that covers it.
4. **Test-design review**: each testify finding with its outcome.
5. **Review rounds**: for each round, every finding with its severity, `file:line` and outcome (fixed, could not fix and why, or left unfixed for a stopped round 3).
6. **Scenario concerns**: each concern of kind `ambiguity-or-contradiction` verbatim with its group heading, marking which stopped the flow and which are about another group, or none.
7. **Suggested scenarios and gaps**: each concern of kind `missing-or-gap` verbatim with its group heading, or none. These never stopped the flow and no fixer saw them.
8. **Owner decisions**: each `Owner decision:` line from tdd and the fixers, copied as written with its value, `file:line` and reason, or none. These are product values no scenario or Decided note fixes, for you to confirm or change.
9. **Comment claims left for you**: each unverified claim with `file:line`, or none.
10. **Results**: the test command and its result, the lint command and its result, or that no lint step ran.

## Stops at a glance

Print the final report at every stop except the unmatched-group stop and the three flag stops (both flags, `--resume` with nothing to resume, and a stopped run found with no flag), which happen before a run exists. Stops before the commit show the user the output tail. A stop after Phase 0 leaves the worktree and branch in place; re-run with `--resume` to continue.

| Condition | Result |
|-----------|--------|
| Heading not a group in the doc | Nothing implemented, headings listed (BUILD-002) |
| Both `--resume` and `--discard` given | Pre-flight stop, nothing done |
| Dirty original checkout beyond the scenario doc | Pre-flight stop, paths listed |
| A stopped worktree or branch exists and neither flag was given | Pre-flight stop, worktree path, branch and base printed, re-run with `--resume` or `--discard` |
| `--resume` and no stopped worktree | Pre-flight stop |
| No test command found | Pre-flight stop |
| Directory isn't a usable git repository (or has no commits) | Pre-flight stop |
| The scenario read reports an ambiguity or contradiction in this group | No code written, no commit, doc unchanged, concerns printed verbatim, user rules |
| A subagent leaves the suite red | Mid-flow stop before the commit, output tail shown, worktree kept |
| tdd leaves a scenario unfinished | Mid-flow stop before the commit, output tail shown, worktree kept |
| A commit hook fails | Mid-flow stop, output tail shown, worktree kept |
| Round 3 reports a HIGH finding | No commit, round 3 findings unfixed, worktree kept (BUILD-010) |
| Any round raised an ambiguity or contradiction (or an unlabelled concern) about this chunk's own group | No commit, doc unchanged, worktree kept, user rules (BUILD-011) |
| Tests or lint fail at the gate | No commit, output tail shown, worktree kept |
| The starting checkout moved or got dirty, or a cherry-pick conflicts | Commit stays on the work branch, worktree kept, reason shown |
| A concern about another group, a missing-scenario or gap suggestion, an `Owner decision:`, or an unfixed MEDIUM or LOW finding | No stop; listed in the final report (BUILD-009, BUILD-011) |
