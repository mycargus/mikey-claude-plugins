---
name: mikey:tdd
description: "TDD workflow driven by Given/When/Then specifications. Provide a spec file or folder path for autonomous batch processing, or run without a path for an interactive TDD loop. Implements code using Functional Core / Imperative Shell design principles."
argument-hint: [path] [--plan] [--export]
user-invocable: true
---

# Spec-Driven Development Skill

## Quick Reference

| Parameter | Description |
|-----------|-------------|
| `path` | File or folder containing Given/When/Then specs (triggers agent mode) |
| `--plan` | Show implementation plan only, do not write code |
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

**Shared references:**
- `${CLAUDE_PLUGIN_ROOT}/references/code-testability.md` — How to structure code for testability
- `${CLAUDE_PLUGIN_ROOT}/references/test-quality.md` — What makes tests reliable and valuable
- `${CLAUDE_PLUGIN_ROOT}/references/test-pyramid.md` — Which test layer each scenario belongs at

**Spec format reference:** See Embedded References below.

## Execution Strategy

### Phase 1: Setup

1. **Parse arguments** to extract:
   - Target path (optional — file or folder of spec files)
   - `--plan` flag (plan only, do not implement)
   - `--export` flag (save report)

2. **Detect project conventions** by examining project files:
   - **Language and framework**: Look for `package.json`, `pyproject.toml`, `Cargo.toml`, `go.mod`, `pom.xml`, `build.gradle`, `Gemfile`, `*.csproj`, etc.
   - **Test runner**: Identify the test command (e.g., `npm test`, `pytest`, `go test`, `cargo test`, `mvn test`)
   - **Test file patterns**: Detect conventions (e.g., `*_test.go`, `test_*.py`, `*.spec.ts`, `*.test.js`, `*Test.java`)
   - **Directory structure**: Identify where tests and source files live
   - **Existing test style**: Read 1-2 existing test files to match conventions (assertion library, naming, structure)

3. **Display setup summary** to the user before proceeding:
   ```
   Phase 1: Setup
   - Target: {path or "interactive mode"}
   - Project: {language}, {test pattern} convention
   - Flags: {enabled flags or "none"}
   - Test runner: {detected runner}
   - Test directory: {path or "TBD"}
   - Source directory: {path or "TBD"}
   ```
   In interactive mode or when directories can't be determined yet, show what's known and note the rest as "TBD — will determine from first scenario."

4. **Route to mode**:
   - If `path` is provided → **Agent Mode** (Phase 2A)
   - If no `path` → **Interactive Mode** (Phase 2B)

### Phase 2A: Agent Mode (spec path provided)

#### Step 1: Parse Specs

1. If path is a file, read it
2. If path is a directory, glob for spec files: `**/*.feature`, `**/*.md`, `**/*.txt`, `**/*.spec`
3. Apply the Spec Format from Embedded References below
4. Parse Given/When/Then scenarios from the files using those parsing rules
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

Spawn a `tdd-agent` with the following context:

1. **Project context** (detected in Phase 1):
   - Language/framework
   - Test runner command
   - Test file pattern
   - Source directory
   - Test directory
   - Existing test style conventions (assertion library, naming, structure)
2. **Scenarios**: The selected scenarios, formatted as numbered Given/When/Then blocks

Wait for agent completion.

#### Step 4: Post-Completion

After the agent completes:
1. Show final test suite results
2. If `--export`: write report (see Export section)

### Phase 2B: Interactive Mode (no spec path)

Before starting the interactive loop, read the shared references (`${CLAUDE_PLUGIN_ROOT}/references/code-testability.md`, `${CLAUDE_PLUGIN_ROOT}/references/test-quality.md`, `${CLAUDE_PLUGIN_ROOT}/references/test-pyramid.md`) and apply those principles throughout.

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

1. Apply the test philosophy principles
2. Write a test that describes the expected behavior:
   - Test observable behavior (return values, errors), NOT implementation
   - Follow RITE principles
   - Answer the 5 Questions
   - Match the project's existing test conventions
3. Determine the right test layer (see `${CLAUDE_PLUGIN_ROOT}/references/test-pyramid.md` for full criteria):
   - Pure logic with no I/O → **unit test**
   - I/O or user-facing behavior → **interface test** (the default)
   - Inter-service data format validation → **contract test**
   - Requires real external services → **E2E test**
4. Run the test suite — show the failure output
5. Confirm the test is failing for the right reason

#### Step 4: GREEN — Write Minimal Implementation

1. Write the **minimum** code to make the test pass
2. **Apply Functional Core / Imperative Shell** (see `${CLAUDE_PLUGIN_ROOT}/references/code-testability.md`). If the scenario involves both logic and I/O, write them as separate functions.
3. Do NOT add code beyond what the test requires
4. Run the test suite — show all tests passing
5. **Discipline check**: Verify every branch and guard clause in the new code is exercised by a test. If you added defensive code (null checks, input validation, error guards) that no test exercises, remove it — it violates minimal implementation. Re-run tests if you removed code.

#### Step 5: REFACTOR

1. **Classify** each function written or modified as Pure, I/O, or Orchestrator (see `${CLAUDE_PLUGIN_ROOT}/references/code-testability.md`). Any function that mixes data transformation with I/O is a Violation — extract the pure logic.
2. **Review** for:
   - **Duplication** → extract if genuinely duplicated
   - **Naming clarity** → functions and variables express intent
   - **Test quality** → still RITE? Testing behavior, not implementation?
3. If changes needed, apply them and re-run tests
4. If no refactoring needed, state why briefly

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
   - Tests written (categorized: unit / unit mocked / interface)
   - Pure functions created, I/O shells, orchestrators
3. If `--export`: write report (see Export section)

## Export

When `--export` is set, write a session report to `sdd-report-<timestamp>.md` using `date +%Y%m%d-%H%M%S` for the timestamp. Include:

```markdown
# Spec-Driven Development Report

## Session Summary
- Mode: {Agent|Interactive}
- Scenarios implemented: {count}
- Total tests: {count} (unit: {N}, unit mocked: {N}, interface: {N})

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
{test suite output summary}
```

## Non-Negotiable Principles

The shared references define these principles in full. They are **not optional**:

- **Functional Core / Imperative Shell** — Always separate pure logic from I/O (`${CLAUDE_PLUGIN_ROOT}/references/code-testability.md`)
- **Test layer placement** — Interface tests are the default for I/O; unit tests for pure functions only (`${CLAUDE_PLUGIN_ROOT}/references/test-pyramid.md`)
- **Test quality** — RITE tests, observable behavior, never mock pure functions (`${CLAUDE_PLUGIN_ROOT}/references/test-quality.md`)
- **Minimal implementation** — Only write code the current test demands. Do not anticipate future scenarios.

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

- Read and apply the shared references from `${CLAUDE_PLUGIN_ROOT}/references/` (code-testability.md, test-quality.md, test-pyramid.md) before any analysis or implementation
- Apply the Spec Format from Embedded References when parsing spec files
- The TDD cycle is strict: RED (failing test) → GREEN (minimal pass) → REFACTOR. Never skip steps.
- Code design (functional core / imperative shell) is applied during GREEN and REFACTOR, not as a separate phase
- Match the project's existing conventions for test location, naming, assertion style, and file organization

---

## Embedded References

### Spec Format

See `${CLAUDE_PLUGIN_ROOT}/skills/tdd/references/spec-format.md` for accepted formats, parsing rules, and examples.
