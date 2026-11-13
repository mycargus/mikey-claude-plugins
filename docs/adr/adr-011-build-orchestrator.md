# ADR-011: Compose Existing Skills Under a Build Orchestrator

**Status:** Accepted
**Date:** 2026-11-12

## Context

Implementing a group of approved scenarios takes several steps that already exist as separate skills: `/mikey:tdd` implements, `/mikey:testify` reviews test design, `/mikey:comment-review` cleans comments. Between them sits an adversarial review that no skill covers. Run by hand, each step needs a person to decide what comes next, re-brief the next agent, and judge when the work is done. A session that does the implementing also anchors on its own reasoning, so it reviews its own work poorly.

The question was how to chain these steps so a chunk of scenarios goes from approved to committed without a person in the loop, and so that every review is independent of the work it reviews.

## Decision

`/mikey:build` composes the existing skills under one orchestrating skill, and the main session only coordinates: it reads the project's conventions and git state, invokes the skills, briefs subagents, reads their reports, runs the final test, lint and commit commands, and talks to the user. The loop has this shape:

1. A fresh `adversarial-reviewer` reads the whole scenario doc before any code exists, so the other groups and the Decided and Parked sections serve as context, but it judges only the chunk's scenarios. A gap another group or section already covers is dropped. It reads no code, and it halts the run only on a chunk scenario that contradicts another scenario, in any group, or the Decided section. A chunk scenario that can be read more than one way never halts it: the reader names each reading and picks the simplest, and tdd builds that one. When a contradiction halts the run, the user chooses: rule on the concerns now through `/mikey:user-scenarios`, which takes them one at a time with approval for every change, after which a fresh reader reads the changed doc; stop; or continue anyway, with the concerns left open in the final report. Build keeps the contradictions continued past, keyed by the pair of scenario ids (or scenario id and Decided) each names: a later review-round or fixer contradiction naming the same pair is recorded as still open and doesn't stop the run, and one naming a new pair does.
2. `/mikey:tdd` runs once per chunk (a chunk is one `##` group of a user-scenarios doc), with `--auto`.
3. One fixer subagent invokes `/mikey:testify --with-design --auto` on the touched files itself, then applies every finding of every severity and reports the findings with outcomes and the testify grade line.
4. Review and fix, up to three rounds. Each round is a fresh `adversarial-reviewer` and then a fresh `fixer`.
5. `/mikey:comment-review --apply` runs once, in a subagent.
6. Tests and lint run, and the chunk is committed. Nothing is pushed or amended.

The exit rule: a round that reports no HIGH finding ends the loop once its findings are fixed. HIGH means a correctness bug, a scenario not implemented or implemented differently, a scenario with no test that would fail if it broke, or drift from docs and conventions the project says must stay in sync. Everything else is MEDIUM or LOW and gets fixed but never forces another round; one the fixer could not fix never blocks the loop or the commit and is listed in the final report. If round three still reports a HIGH finding, nothing is committed and the findings stay unfixed for the user. A reviewer that finds a scenario wrong, ambiguous or missing reports it separately, labelled with one of three kinds. The doc changes only through `/mikey:user-scenarios` with the user's approval. Only a contradiction halts the flow: a scenario in the chunk's own group that conflicts with another scenario, in any group, or with the Decided section. The scenario read halts before tdd on that kind and asks the user to rule now, stop or continue anyway; concerns the user continued past don't stop the commit. A review round that finds a contradiction in the chunk's own group stops before the commit. A contradiction about another group goes in the final report only, and so does a scenario that only looks wrong, and a Risk paragraph naming harm the Then wouldn't catch. A concern with no label counts as a contradiction, but a reviewer in real doubt between a contradiction and two readings labels it an ambiguity. An ambiguity, a chunk scenario with two or more plausible readings, never halts the flow: the reviewer names the readings and picks the simplest, tdd (or the fixer, in a review round) implements that reading, and the final report lists the scenario, the readings, the reading built, who built it and why, next to the product values. The first reading built for a scenario stands, across runs as well as within one: a passing covering test from an earlier run fixes the reading, and a different pick from a later reviewer, from tdd or from a fixer is reported under that scenario and never rebuilt. Built readings bind every fixer: a finding or an interpretation that conflicts with one is reported as a differing pick and never applied. Review-round ambiguity concerns reach the fixer only for scenarios with no reading built yet. A reading found by the round that stops the run (the third round's HIGH stop) is reported, not built, and a reading a fixer builds in a round with no HIGH finding needs no extra round. Build keeps a readings ledger and enters every built reading in it as the report carrying it comes back, whatever its source (tdd's built and already-implemented readings, a fixer's, and the interpretations tdd or a fixer reports as owner decisions), before a round's ambiguity concerns are filtered against it. Both tdd and the fixers report every interpretation of unclear wording they made as an owner decision. The readings file build hands to tdd lives outside the project tree, in the session scratchpad or a `mktemp -d` directory. A suggestion for a missing scenario, or a gap no approved scenario covers, never stops the flow and goes in the final report; no fixer sees it. When no scenario sets a product value and tdd or a fixer had to choose one, that choice also goes in the final report and never stops the flow.

The flow also stops before the commit, showing the user the output tail, when a subagent leaves the suite red, when tdd leaves a scenario unfinished, or when a commit hook fails. Pre-flight stops (unmatched group, no test command or no git repository) end it before any work. A tree with uncommitted changes other than the scenario doc doesn't stop the flow outright: the user is shown the paths and asked whether to continue from them or stop. On continue, tdd leaves alone scenarios that already have a passing covering test, and review, comment cleanup and the commit cover the earlier changes too.

Models per role: implementer Sonnet at high effort, adversarial reviewer Opus at medium effort, scenario reader (the adversarial reviewer in scenario-read mode) Opus at medium effort, fixer and comment reviewer Sonnet at low effort. Testify's analysis agent inherits the invoking fixer's model.

The reviewer and fixer protocols live in `agents/*.md` system prompts (ADR-005), and the skill passes only dynamic context.

## Alternatives Considered

- **Re-run the implementer each round:** The implementer would fix what the reviewer finds. It carries its own reasoning from the first pass and tends to defend it, and re-running `/mikey:tdd` re-parses and re-implements scenarios that already pass. A fixer that gets only the findings has no reasoning to defend.
- **Comment review inside each round:** Every fix edits code and comments, so cleaning comments each round pays for the pass up to three times and cleans comments that the next round rewrites. One pass after the loop sees the final code.
- **A single long-lived reviewer:** The reviewer would keep its memory across rounds and check whether earlier findings were fixed. It also inherits its own earlier blind spots, so a bug it passed in round one gets passed again. A fresh reviewer per round re-judges the whole chunk from the scenarios and the diff.

## Consequences

**Positive:**
- A chunk runs unattended from approved scenarios to a commit, and the user sees one line per round. It asks up front only when the tree already has uncommitted changes, or when the scenario read finds a contradiction.
- Each review is independent: it knows the scenarios, the diff and the project's conventions, and nothing about earlier rounds.
- The main session's context stays small because it never reads diffs or full test output. It reads subagent reports, and it runs the final test and lint commands through `tail` so only the exit status and the last lines reach it, then the commit.
- A contradictory scenario can't pass silently: it goes to the user, and the doc is never changed without approval. Found by the scenario read, it halts the run before any code is written, and the user can rule on it there without restarting the run.
- An ambiguous scenario doesn't interrupt the run: the simplest reading is built once, it stands against later reviewers' picks, and the final report lists the readings, the one built and any differing pick for the user to confirm or change.

**Negative:**
- A fresh reviewer re-reads the whole chunk each round, so a three-round run costs three full reviews at Opus.
- A fixer has no memory of why code was written a certain way, so it can undo a decision the next reviewer then flags again. The three-round cap bounds that.
- The main session holds every round's findings until the final report, so a long run still grows its context a little.
