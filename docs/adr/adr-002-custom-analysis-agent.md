# ADR-002: Custom Analysis-Agent Over Built-In Explore

**Status:** Accepted
**Date:** 2026-03-20

## Context

Testify Phase 2 (Analysis) needs to read test and source files, evaluate them against the test philosophy, and return structured findings. Options were: (A) use Claude Code's built-in Explore subagent; (B) create a custom `analysis-agent` with a controlled tool set and output contract.

The built-in Explore agent uses Haiku by default, has a fixed system prompt, and returns free-form text.

## Decision

Option B -- custom `analysis-agent` with read-only tools (`Read`, `Grep`, `Glob`) and a strict JSON output contract.

## Alternatives Considered

- **Built-in Explore (A):** Simpler setup (no agent file, no plugin registration). However, it defaults to Haiku which reduces analysis quality, returns unstructured text requiring post-processing, and offers no control over which tools the agent can use. The lack of a structured output contract made synthesis (Phase 3) fragile -- findings had to be parsed from prose.

## Consequences

**Positive:**
- Model inherits from parent session, so analysis quality matches the user's active model.
- JSON output contract makes Phase 3 synthesis deterministic -- no parsing ambiguity.
- Read-only tool restriction guarantees analysis cannot modify code.
- Analysis prompt (`analysis-prompt.md`) serves as a testable contract between the skill and the agent.

**Negative:**
- Adds two files to maintain (`agents/analysis-agent.md` and `references/analysis-prompt.md`).
- Requires plugin.json registration. Changes to the agent definition require a plugin version bump.
