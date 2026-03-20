# ADR-004: Agents at Plugin Root, Not Inside Skills

**Status:** Accepted
**Date:** 2026-03-20

## Context

The plugin has two custom agents (`analysis-agent` and `tdd-agent`) and two skills (`testify` and `tdd`). Each agent is currently consumed by one skill. The question was where to place agent definition files: (A) inside the consuming skill's directory (e.g., `skills/testify/agents/`); (B) at the plugin root (`agents/`).

This decision was revisited multiple times. An early commit moved the analysis agent into the testify references directory, but this was later reversed back to plugin root.

## Decision

Option B -- agents live at `mikey/agents/` at the plugin root, registered in `plugin.json`.

## Alternatives Considered

- **Inside skill directories (A):** Keeps agents co-located with their consumer for discoverability. However, agent definitions become system prompts -- the strongest instruction position in the LLM context. Burying them inside a skill directory underrepresents their importance. Additionally, if a future skill needs to reuse an agent, co-location forces duplication or cross-directory references.

## Consequences

**Positive:**
- Agents are first-class plugin citizens, visible at the top level alongside skills.
- Future skills can reference existing agents without cross-directory paths.
- Plugin.json registration is cleaner with a single `agents/` directory.

**Negative:**
- Agent and consuming skill are not co-located -- requires navigating between `agents/` and `skills/` when editing related files.
- Currently each agent serves exactly one skill, so reusability is theoretical.
