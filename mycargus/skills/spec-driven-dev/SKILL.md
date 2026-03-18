---
name: spec-driven-dev
description: TDD workflow driven by Given/When/Then specifications. Provide a spec file or folder path for autonomous batch processing, or run without a path for an interactive TDD loop. Implements code using Functional Core / Imperative Shell design principles.
argument-hint: [path] [--plan] [--verify] [--export]
---

# Spec-Driven Development Skill

## Quick Reference

| Parameter | Description |
|-----------|-------------|
| `path` | File or folder containing Given/When/Then specs (triggers agent mode) |
| `--plan` | Show implementation plan only, do not write code |
| `--verify` | Run `/testify` after completion (default: auto-detect — true if testify installed, false otherwise) |
| `--export` | Save session report to `sdd-report-<timestamp>.md` |

## Description

Test-Driven Development workflow guided by Given/When/Then specifications and the embedded test philosophy.

**Two modes:**
- **Agent mode** (path provided): Reads spec files, extracts scenarios, and implements each via Red-Green-Refactor autonomously with check-ins between scenarios.
- **Interactive mode** (no path): Prompts the user to describe behaviors one at a time, implementing each through the TDD cycle with user approval.

**This skill always applies:**
1. Red-Green-Refactor TDD cycle for every scenario
2. Test philosophy: observable behavior, RITE tests, 5 Questions
3. Functional Core / Imperative Shell code design — pure logic separated from I/O
4. Minimal implementation — only write code required by the current test

**Philosophy reference:** `${CLAUDE_PLUGIN_ROOT}/skills/testify/references/philosophy.md`
**Spec format reference:** `${CLAUDE_PLUGIN_ROOT}/skills/spec-driven-dev/references/spec-format.md`

## Execution Strategy

### Phase 1: Setup

1. **Parse arguments** to extract:
   - Target path (optional — file or folder of spec files)
   - `--plan` flag (plan only, do not implement)
   - `--verify` flag (run testify after completion)
   - `--export` flag (save report)

2. **Detect project conventions** by examining project files:
   - **Language and framework**: Look for `package.json`, `pyproject.toml`, `Cargo.toml`, `go.mod`, `pom.xml`, `build.gradle`, `Gemfile`, `*.csproj`, etc.
   - **Test runner**: Identify the test command (e.g., `npm test`, `pytest`, `go test`, `cargo test`, `mvn test`)
   - **Test file patterns**: Detect conventions (e.g., `*_test.go`, `test_*.py`, `*.spec.ts`, `*.test.js`, `*Test.java`)
   - **Directory structure**: Identify where tests and source files live
   - **Existing test style**: Read 1-2 existing test files to match conventions (assertion library, naming, structure)

3. **Detect testify availability**:
   - Testify is a sibling skill in this plugin: `${CLAUDE_PLUGIN_ROOT}/skills/testify/SKILL.md`
   - Check if the testify skill file exists at that path
   - If `--verify` was not explicitly set: default to `true` if testify skill exists, `false` otherwise
   - If `--verify` was explicitly set to `true` but testify is not available: warn the user

4. **Route to mode**:
   - If `path` is provided → **Agent Mode** (Phase 2A)
   - If no `path` → **Interactive Mode** (Phase 2B)

### Phase 2A: Agent Mode (spec path provided)

#### Step 1: Parse Specs

1. If path is a file, read it
2. If path is a directory, glob for spec files: `**/*.feature`, `**/*.md`, `**/*.txt`, `**/*.spec`
3. Read the spec format reference: `${CLAUDE_PLUGIN_ROOT}/skills/spec-driven-dev/references/spec-format.md`
4. Parse Given/When/Then scenarios from the files using the parsing rules in the reference
5. Group scenarios by feature/file

#### Step 2: Present Plan

Display a numbered list of all scenarios extracted:

```
Parsed {N} scenarios from {source}:

  1. {Feature}: {Scenario name}
     Given {precondition}
     When {action}
     Then {outcome}

  2. ...

Test location: {detected test dir}
Source location: {detected source dir}
Test runner: {detected runner}
```

If `--plan` flag is set: **STOP HERE**. Output the plan and exit.

If `--plan` is not set: Ask the user to confirm before proceeding. Use AskUserQuestion:
- "Implement all scenarios"
- "Let me pick specific scenarios"
- "Cancel"

#### Step 3: Spawn TDD Agent

1. Read the agent template: `${CLAUDE_PLUGIN_ROOT}/skills/spec-driven-dev/agents/tdd-agent.md`
2. Assemble the prompt by replacing placeholders:
   - `{{PHILOSOPHY_PATH}}` — absolute path to `${CLAUDE_PLUGIN_ROOT}/skills/testify/references/philosophy.md`
   - `{{SPEC_FORMAT_PATH}}` — absolute path to `${CLAUDE_PLUGIN_ROOT}/skills/spec-driven-dev/references/spec-format.md`
   - `{{LANGUAGE}}` — detected language/framework
   - `{{TEST_RUNNER}}` — detected test command
   - `{{TEST_PATTERN}}` — detected test file pattern
   - `{{SOURCE_DIR}}` — detected source directory
   - `{{TEST_DIR}}` — detected test directory
   - `{{SCENARIOS}}` — the selected scenarios, formatted as numbered Given/When/Then blocks
   - `{{VERIFY_INSTRUCTIONS}}` — see Verify Instructions below
3. Spawn as a `general-purpose` agent
4. Wait for completion

#### Step 4: Post-Completion

After the agent completes:
1. Show final test suite results
2. If `--verify` is true and testify is available: invoke `/mycargus:testify` on the test directory with `--with-design`
3. If `--verify` is true but testify is NOT available: warn the user
4. If `--export`: write report (see Export section)

### Phase 2B: Interactive Mode (no spec path)

#### Step 1: Prompt for Behavior

Display:

```
Interactive TDD mode. Describe a behavior using Given/When/Then:

  Example:
    Given a list of users
    When filtering by active status
    Then only active users are returned

  (Or just describe what you want the code to do)
```

Use AskUserQuestion to get the user's input.

#### Step 2: Parse the Behavior

1. Extract Given/When/Then from the user's input
2. If the user provided a plain description instead of GWT, convert it to Given/When/Then format and confirm with the user
3. Identify what needs to be tested and where the test/source files should go

#### Step 3: RED — Write Failing Test

1. Read the philosophy: `${CLAUDE_PLUGIN_ROOT}/skills/testify/references/philosophy.md`
2. Write a test that describes the expected behavior:
   - Test observable behavior (return values, errors), NOT implementation
   - Follow RITE principles
   - Answer the 5 Questions
   - Match the project's existing test conventions
3. Determine the right test type based on the scenario:
   - If the behavior is pure logic (calculation, transformation, validation) → **unit test, no mocks**
   - If the behavior involves I/O (file ops, network, CLI) → **integration test through real entry point**
4. Run the test suite — show the failure output
5. Confirm the test is failing for the right reason

#### Step 4: GREEN — Write Minimal Implementation

1. Write the **minimum** code to make the test pass
2. **Apply Functional Core / Imperative Shell**:
   - Extract pure logic into pure functions (no I/O, deterministic)
   - Keep I/O operations in thin shell functions
   - If the scenario involves both logic and I/O, write them as separate functions
3. Do NOT add code beyond what the test requires
4. Run the test suite — show all tests passing

#### Step 5: REFACTOR

1. Review the implementation for:
   - **I/O mixed with logic** → extract pure functions
   - **Duplication** → extract if genuinely duplicated
   - **Naming clarity** → functions and variables express intent
   - **Test quality** → still RITE? Testing behavior, not implementation?
2. If changes needed, apply them and re-run tests
3. If no refactoring needed, state why briefly

#### Step 6: Loop

After completing the cycle, ask the user:

Use AskUserQuestion:
- "Describe the next behavior"
- "Done — finish session"

If "next behavior": return to Step 1.
If "done": proceed to Post-Completion.

#### Post-Completion

1. Run the full test suite and show output
2. Summarize the session:
   - Scenarios implemented
   - Tests written (categorized: unit pure / unit mocked / integration)
   - Pure functions created, I/O shells, orchestrators
3. If `--verify` is true and testify is available: invoke `/mycargus:testify` on the test directory with `--with-design`
4. If `--verify` is true but testify is NOT available: warn the user that testify skill was not found
5. If `--export`: write report (see Export section)

## Verify Instructions

Use this text for `{{VERIFY_INSTRUCTIONS}}` based on the verify state:

**If verify is enabled and testify is available:**
```
After all scenarios are complete, the parent skill will invoke /mycargus:testify for verification. No action needed from you.
```

**If verify is enabled but testify is NOT available:**
```
After all scenarios, warn the user that the testify skill was not found at ${CLAUDE_PLUGIN_ROOT}/skills/testify/SKILL.md.
```

**If verify is disabled:**
```
No verification step. Skip.
```

## Export

When `--export` is set, write a session report to `sdd-report-<timestamp>.md` using `date +%Y%m%d-%H%M%S` for the timestamp. Include:

```markdown
# Spec-Driven Development Report

## Session Summary
- Mode: {Agent|Interactive}
- Scenarios implemented: {count}
- Total tests: {count} (unit pure: {N}, unit mocked: {N}, integration: {N})

## Scenarios

### {Scenario name}
- **Spec**: Given {X}, When {Y}, Then {Z}
- **Test**: {test file}:{line}
- **Implementation**: {source file}:{line}
- **Design**: {pure function | I/O shell | orchestrator}

## Code Design
- Pure functions created: {list with file:line}
- I/O shells: {list with file:line}
- Orchestrators: {list with file:line}

## Verification
{testify report summary or "not run"}
```

## Code Design Principles

**These principles are NOT optional.** Every implementation step must apply them:

1. **Functional Core / Imperative Shell** — Always separate pure logic from I/O
2. **Pure functions** — No side effects, deterministic, easy to unit test without mocks
3. **Thin I/O shells** — Handle only I/O (file, network, console), delegate logic to pure functions
4. **Test what you build** — Pure functions get unit tests. I/O gets integration tests. Never mock pure functions.
5. **Minimal implementation** — Only write code the current test demands. Do not anticipate future scenarios.

## Uncertainty Handling

**If the spec is ambiguous:**
- In agent mode: make a reasonable interpretation, note the assumption, continue
- In interactive mode: ask the user to clarify before writing the test

**If the test fails unexpectedly during GREEN:**
- Debug the failure
- Fix the implementation (not the test — the test defines the desired behavior)
- If the test itself was wrong, explain why and ask the user before changing it

**Never:**
- Skip a failing test
- Write implementation before the test
- Add features not described in the current scenario
- Mock pure functions
- Fabricate test results — always run the actual test command and show output

## Important Notes

- Read the philosophy at `${CLAUDE_PLUGIN_ROOT}/skills/testify/references/philosophy.md` before any analysis or implementation
- Read the spec format at `${CLAUDE_PLUGIN_ROOT}/skills/spec-driven-dev/references/spec-format.md` when parsing spec files
- The TDD cycle is strict: RED (failing test) → GREEN (minimal pass) → REFACTOR. Never skip steps.
- Code design (functional core / imperative shell) is applied during GREEN and REFACTOR, not as a separate phase
- Match the project's existing conventions for test location, naming, assertion style, and file organization

## Related Documentation

- `${CLAUDE_PLUGIN_ROOT}/skills/testify/references/philosophy.md` — test philosophy reference
- `${CLAUDE_PLUGIN_ROOT}/skills/spec-driven-dev/references/spec-format.md` — spec format reference
- `${CLAUDE_PLUGIN_ROOT}/skills/spec-driven-dev/examples/examples.md` — example workflows
- `${CLAUDE_PLUGIN_ROOT}/skills/spec-driven-dev/agents/tdd-agent.md` — TDD agent template
