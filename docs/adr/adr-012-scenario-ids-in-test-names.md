# ADR-012: Scenario Ids Begin the Names of the Tests That Cover Them

**Status:** Accepted
**Date:** 2026-11-15

## Context

`/mikey:build` reports which test covers each scenario, but only in its final report. Afterwards, nothing in the project's code links a test to a scenario. To see which scenarios have a test, the owner had to read every test against the doc. A first look at one project found 366 tests and 90 scenarios with no tie between them: no test title, comment or file mentioned a scenario id.

The owner wants three things from the link: see which scenario a test covers while reading the test, see coverage across the doc at a glance, and have a failing run name the scenario that broke.

Options were: the id in the test name, a tag or option on the test, a comment above the test, the id in the `describe` name, and a separate manifest mapping ids to tests.

## Decision

A test's name begins with the id of the scenario it covers (`<id>: `, or `<id>, <id>: ` in doc order for several). A test that covers no scenario carries no id. A test that begins with an id its doc no longer defines is renamed to the replacement scenario or deleted, and the tdd-agent reports each as an `Owner decision:`.

## Alternatives Considered

- **Tag or option on the test:** The project's runner had no tags. A tag would need its own convention and checking, and it would show in neither the test output nor a failure.
- **Comment above the test:** Visible in the code only. It doesn't show in output, can't be selected by a name filter, and drifts when the test is renamed or moved.
- **Id in the `describe` name:** Appears in output and filters, but `describe` blocks group by topic, not by scenario, so one block rarely maps to one scenario.
- **Manifest file mapping ids to tests:** A second file to keep in step with the tests, and nothing in a test points at it.

## Consequences

**Positive:**
- The id is part of the test's identity: it shows in the code, the output and a failure, it works with a name filter, and a simple script can list the scenarios no test names.
- The tdd-agent finds an existing covering test by its id when a run continues from earlier work, instead of judging by content.
- No new tool in the plugin. The convention is two sentences in the agent files and one in the scenario skill.

**Negative:**
- A meaningful scenario change retires an id and leaves tests that carry it. The tdd-agent renames or deletes them at the start of the next build of the doc, and the owner confirms each through an `Owner decision:` line. Until that build, the old id stays in the test names, and any coverage script flags it as an id no scenario defines.
- Frameworks whose test names are identifiers can't hold `<id>: `. The id comes first in whatever form the framework allows.
- The plugin doesn't ship a coverage script. A project that wants the at-a-glance listing writes its own, or a project's `CLAUDE.md` can state the convention so reviewers enforce it.
