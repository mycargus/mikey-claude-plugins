# ADR-006: Shared Reference Files Over Embedded Documentation

**Status:** Accepted
**Date:** 2026-03-20

## Context

The test philosophy is consumed by four components: the analysis-agent, the tdd-agent, the testify skill, and the tdd skill. Early versions embedded the philosophy directly in each consumer's prompt or instructions. When the philosophy was updated (e.g., adding the 500-line file size limit), some consumers received the update and others did not, causing drift.

Options were: (A) embed philosophy content in each consumer; (B) extract to a shared reference file read at runtime by all consumers.

## Decision

Option B -- the test philosophy lives in `skills/testify/references/philosophy.md` and is read at runtime by all consumers via `${CLAUDE_PLUGIN_ROOT}` path resolution.

## Alternatives Considered

- **Embedded in each consumer (A):** Makes each file self-contained and readable without cross-referencing. However, four copies of the philosophy meant four places to update. The 500-line test file limit was missing from two consumers for multiple commits before the drift was caught. Single source of truth eliminates this class of bug entirely.

## Consequences

**Positive:**
- Single source of truth -- philosophy updates propagate to all consumers automatically.
- Analysis-prompt contract (`analysis-prompt.md`) and report template (`report-template.md`) follow the same pattern, creating a consistent reference file convention.
- PreToolUse hook auto-allows reads to plugin files, so the runtime file access adds no UX friction. (See [ADR-008](adr-008-no-jq-in-hooks.md) for a gotcha with hook script dependencies.)

**Negative:**
- Consumers are not self-contained -- understanding the analysis-agent requires reading both the agent file and the referenced philosophy file.
- Runtime file read adds a tool call per invocation. If the file is missing or unreadable, the skill fails at runtime rather than at definition time.
