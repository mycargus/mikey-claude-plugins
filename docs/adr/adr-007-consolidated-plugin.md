# ADR-007: Single Consolidated Plugin With Namespaced Skills

**Status:** Accepted
**Date:** 2026-03-20

## Context

The project originally had separate plugins for testify (test analysis) and spec-driven-dev (TDD implementation). Both plugins depended on the same test philosophy and shared conceptual foundations. Updating the philosophy required coordinating changes across two independent plugins.

Options were: (A) keep separate plugins; (B) consolidate into a single "mikey" plugin with namespaced skills (`/mikey:testify`, `/mikey:tdd`).

## Decision

Option B -- consolidate into one plugin. Skills are invoked as `/mikey:testify` and `/mikey:tdd`.

## Alternatives Considered

- **Separate plugins (A):** Each plugin is independently installable and versioned. Users who only want test analysis don't need to install TDD tooling. However, the shared philosophy dependency meant version coordination was required across plugins. A philosophy update in testify could break expectations in spec-driven-dev if not released in lockstep. The plugins also shared agent patterns and hook infrastructure, duplicating configuration.

## Consequences

**Positive:**
- Shared reference files (philosophy, analysis prompt) are co-located and versioned atomically.
- Single plugin.json registers all agents and hooks -- no duplication.
- The tdd skill can invoke testify directly via `--validate` without cross-plugin dependencies.
- One version number to track.

**Negative:**
- Users install both skills even if they only want one. Neither skill is independently distributable.
- Plugin namespace (`mikey:`) adds typing overhead compared to bare `/testify` or `/tdd`.
- A breaking change in either skill requires a version bump for the entire plugin.
