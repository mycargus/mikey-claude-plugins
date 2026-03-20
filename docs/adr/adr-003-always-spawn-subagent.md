# ADR-003: Always Spawn Subagent for Analysis (No File-Count Threshold)

**Status:** Accepted
**Date:** 2026-03-20

## Context

Early versions of testify had a branching strategy: if the target contained 10+ files, spawn the analysis-agent for context isolation; otherwise, analyze inline in the main skill context. This created two code paths (Strategy A and Strategy B) with different behaviors to test and maintain.

Options were: (A) keep the threshold with dual code paths; (B) always spawn the subagent regardless of file count.

## Decision

Option B -- always spawn the analysis-agent. The 10-file threshold and Strategy A/B branching were removed.

## Alternatives Considered

- **File-count threshold (A):** Avoids subagent overhead for small projects (2-3 files). However, maintaining two analysis paths doubled the testing surface and introduced subtle behavioral differences between inline and subagent analysis. Bugs fixed in one path were not always fixed in the other.

## Consequences

**Positive:**
- Single code path -- every analysis runs the same way regardless of project size.
- Predictable context isolation -- parent context never accumulates raw file contents from analysis.
- Easier to debug -- analysis behavior is always in the subagent, never split across two strategies.

**Negative:**
- Small projects pay subagent spawn overhead even when inline analysis would suffice.
- Adds one agent round-trip for projects with only 1-2 test files.
