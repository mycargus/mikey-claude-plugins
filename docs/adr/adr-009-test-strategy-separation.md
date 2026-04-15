# ADR-009: Separate Test Strategy into Three Focused Documents

**Status:** Accepted
**Date:** 2026-04-14
**Supersedes:** [ADR-006](adr-006-shared-reference-files.md) (shared reference files principle retained, location and structure changed)

## Context

ADR-006 established that shared reference files should live in a single location and be read at runtime by all consumers. The test philosophy lived in `skills/testify/references/philosophy.md` because testify "owned" it. This worked when there was one shared document.

As the test strategy matured — incorporating a 4-layer test pyramid (Unit, Interface, Contract, E2E), dependency handling decision trees, and layer placement analysis — the single philosophy document grew to cover three distinct concerns:

1. How to structure code for testability (Functional Core / Imperative Shell)
2. What makes tests reliable and valuable (RITE, anti-patterns, mocking rules)
3. Which test layer a scenario belongs at (pyramid layers, decision criteria, dependency handling)

These concerns map to different decision points in the TDD and testify workflows. An LLM agent deciding "how should I structure this code?" needs different context than one deciding "which test layer should this test be at?" Bundling all three into one document forces every consumer to load all context even when only one concern is relevant.

Additionally, the ownership model broke down: testify doesn't "own" the test pyramid or code testability principles any more than TDD does. Official Claude Code plugin documentation recommends a `references/` directory at the plugin root for resources shared across multiple skills and agents.

## Decision

Split `skills/testify/references/philosophy.md` into three focused documents at `references/` (plugin root):

- **`code-testability.md`** — "What makes code testable?" FC/IS, function types, separation of concerns.
- **`test-quality.md`** — "What makes tests reliable and valuable?" RITE, behavior testing, naming, anti-patterns, mocking rules.
- **`test-pyramid.md`** — "Where does this test belong?" 4 layers, attributes table, interface subtypes, decision criteria, dependency decision tree, push-down principle.

Testify-specific files (`analysis-prompt.md`, `report-template.md`) remain in `skills/testify/references/`.

## Alternatives Considered

- **Keep single philosophy.md, just move to plugin root:** Retains the single-file simplicity but doesn't solve the "three concerns in one doc" problem. LLM agents still load all context for every decision.
- **Split into three docs but keep in testify/references/:** Solves the separation-of-concerns problem but retains the false ownership model. TDD consumers reference testify's directory for documents testify doesn't own.

## Consequences

**Positive:**
- Each document answers one question cleanly, reducing irrelevant context for LLM agents.
- Shared `references/` directory at plugin root follows official plugin conventions and eliminates false ownership.
- ADR-006's single-source-of-truth principle is preserved — just with three sources instead of one.
- PreToolUse hook auto-allows reads to all `${CLAUDE_PLUGIN_ROOT}` files, so no UX friction.

**Negative:**
- Consumers now read three files instead of one — three tool calls per invocation instead of one.
- Cross-referencing between documents is necessary (e.g., code-testability informs test-pyramid layer decisions). A reader needs context from multiple docs for full understanding.
