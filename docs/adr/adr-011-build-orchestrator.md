# ADR-011: Compose Existing Skills Under a Build Orchestrator

**Status:** Accepted
**Date:** 2026-11-12

## Context

Implementing a group of approved scenarios takes several steps that already exist as separate skills: `/mikey:tdd` implements, `/mikey:testify` reviews test design, `/mikey:comment-review` cleans comments. Between them sits an adversarial review that no skill covers. Run by hand, each step needs a person to decide what comes next, re-brief the next agent, and judge when the work is done. A session that does the implementing also anchors on its own reasoning, so it reviews its own work poorly.

The question was how to chain these steps so a chunk of scenarios goes from approved to committed without a person in the loop, and so that every review is independent of the work it reviews.

## Decision

`/mikey:build` composes the existing skills under one orchestrating skill, and the main session only coordinates: it reads the project's conventions and git state, invokes the skills, briefs subagents, reads their reports, runs the final test, lint and commit commands, and talks to the user. The loop has this shape:

1. `/mikey:tdd` runs once per chunk (a chunk is one `##` group of a user-scenarios doc), with `--auto`.
2. One fixer subagent invokes `/mikey:testify --with-design --auto` on the touched files itself, then applies every finding of every severity and reports the findings with outcomes and the testify grade line.
3. Review and fix, up to three rounds. Each round is a fresh `adversarial-reviewer` and then a fresh `fixer`.
4. `/mikey:comment-review --apply` runs once, in a subagent.
5. Tests and lint run, and the chunk is committed. Nothing is pushed or amended.

The exit rule: a round that reports no HIGH finding ends the loop once its findings are fixed. HIGH means a correctness bug, a scenario not implemented or implemented differently, a scenario with no test that would fail if it broke, or drift from docs and conventions the project says must stay in sync. Everything else is MEDIUM or LOW and gets fixed but never forces another round; one the fixer could not fix never blocks the loop or the commit and is listed in the final report. If round three still reports a HIGH finding, nothing is committed and the findings stay unfixed for the user. A reviewer that finds a scenario wrong or missing reports it separately; the doc is never edited. A concern about a scenario in the chunk's own group stops the flow before the commit; a concern about another group goes in the final report only.

The flow also stops before the commit, showing the user the output tail, when a subagent leaves the suite red, when tdd leaves a scenario unfinished, or when a commit hook fails. Pre-flight stops (unmatched group, dirty tree, no test command or no git repository) end it before any work.

Models per role: implementer Sonnet at high effort, adversarial reviewer Opus at medium effort, fixer and comment reviewer Sonnet at low effort. Testify's analysis agent inherits the invoking fixer's model.

The reviewer and fixer protocols live in `agents/*.md` system prompts (ADR-005), and the skill passes only dynamic context.

## Alternatives Considered

- **Re-run the implementer each round:** The implementer would fix what the reviewer finds. It carries its own reasoning from the first pass and tends to defend it, and re-running `/mikey:tdd` re-parses and re-implements scenarios that already pass. A fixer that gets only the findings has no reasoning to defend.
- **Comment review inside each round:** Every fix edits code and comments, so cleaning comments each round pays for the pass up to three times and cleans comments that the next round rewrites. One pass after the loop sees the final code.
- **A single long-lived reviewer:** The reviewer would keep its memory across rounds and check whether earlier findings were fixed. It also inherits its own earlier blind spots, so a bug it passed in round one gets passed again. A fresh reviewer per round re-judges the whole chunk from the scenarios and the diff.

## Consequences

**Positive:**
- A chunk runs unattended from approved scenarios to a commit, and the user sees one line per round.
- Each review is independent: it knows the scenarios, the diff and the project's conventions, and nothing about earlier rounds.
- The main session's context stays small because it never reads diffs or full test output. It reads subagent reports, and it runs the final test and lint commands through `tail` so only the exit status and the last lines reach it, then the commit.
- A wrong scenario can't pass silently: it stops the commit and goes to the user, and the doc is never changed without approval.

**Negative:**
- A fresh reviewer re-reads the whole chunk each round, so a three-round run costs three full reviews at Opus.
- A fixer has no memory of why code was written a certain way, so it can undo a decision the next reviewer then flags again. The three-round cap bounds that.
- The main session holds every round's findings until the final report, so a long run still grows its context a little.
