# ADR-005: TDD Agent Protocol in System Prompt, Not Spawn Prompt

**Status:** Accepted
**Date:** 2026-03-20

## Context

The tdd-agent executes a strict Red-Green-Refactor cycle across multiple scenarios. The execution protocol (~200 lines covering RED, GREEN, REFACTOR, VALIDATE steps, test naming conventions, and code design rules) needs to be followed consistently across all scenarios in a single agent run.

Options were: (A) embed the protocol in the spawn prompt passed from the tdd skill; (B) move the protocol into the agent definition file so it lands in the system prompt position.

## Decision

Option B -- the execution protocol lives in `agents/tdd-agent.md` (system prompt). The spawn prompt from the tdd skill passes only dynamic context: project conventions, scenarios, and the validate flag.

## Alternatives Considered

- **Protocol in spawn prompt (A):** Keeps the tdd skill self-contained in a single file. However, instructions in mid-context (spawn prompt) are more susceptible to drift as the agent processes multiple scenarios and accumulates context. The protocol was being paraphrased differently on each spawn, introducing inconsistency. System prompt instructions have stronger adherence because they occupy the highest-priority position in the LLM context window.

## Consequences

**Positive:**
- Stronger instruction following -- system prompt position resists mid-context drift across long multi-scenario runs.
- Clean separation -- agent file owns the *how* (protocol), skill file owns the *what* (which scenarios, which project).
- Spawn prompt is reduced to ~3 dynamic values, making skill code easier to read.

**Negative:**
- Protocol changes require editing the agent file, not the skill file. Two files to consider when modifying TDD behavior.
- The rationale (LLM positional instruction following) is non-obvious and may confuse contributors unfamiliar with prompt engineering.
