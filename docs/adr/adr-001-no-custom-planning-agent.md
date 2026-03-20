# ADR-001: No Custom Planning-Agent for Testify

**Status:** Accepted
**Date:** 2026-03-20

## Context

Testify Phase 5 (Planning) spawns the built-in `Plan` subagent to generate implementation plans from the analysis report. The plugin already defines two custom agents: `analysis-agent` (structured JSON analysis) and `tdd-agent` (autonomous TDD implementation). The question was whether to add a third custom `planning-agent` to handle Phase 5.

Options were: (A) keep the built-in Plan subagent; (B) create a custom planning-agent with the test philosophy and output format baked into its definition.

## Decision

Option A -- keep the built-in Plan subagent. No custom planning-agent.

## Alternatives Considered

- **Custom planning-agent (B):** Would move philosophy embedding and output format instructions from SKILL.md Phase 5 into a dedicated agent file. Provides architectural consistency (one agent per phase) and slightly cleaner SKILL.md. However, the domain context is already injected via the spawn prompt -- a custom agent would relocate instructions, not change behavior or output quality. The analysis-agent justified itself through context isolation on large file sets and structured JSON output. The tdd-agent justified itself through autonomous code implementation. Planning is simpler -- it takes a report and produces markdown, which the built-in Plan agent handles well.

## Consequences

**Positive:**
- Fewer files to maintain (no `agents/planning-agent.md`, no plugin.json update).
- Built-in Plan agent's read-only restriction is a natural fit for the planning phase's intent.
- Flexibility preserved -- Phase 5 prompt construction in SKILL.md can evolve without coordinating changes across agent and skill files.

**Negative:**
- Phase 5 in SKILL.md remains responsible for assembling the full prompt (philosophy + report + scope). Slightly more complex than a single agent spawn.
- If planning needs expand (e.g., running tests or exploring code during planning), this decision should be revisited in favor of a custom agent with broader tool access.
