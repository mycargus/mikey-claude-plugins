---
name: mikey:tdd
description: TDD workflow driven by Given/When/Then specifications. Provide a spec file or folder path for autonomous batch processing, or run without a path for an interactive TDD loop. Implements code using Functional Core / Imperative Shell design principles.
argument-hint: [path] [--plan] [--validate] [--export]
user-invocable: true
---

# Spec-Driven Development Skill

## Quick Reference

| Parameter | Description |
|-----------|-------------|
| `path` | File or folder containing Given/When/Then specs (triggers agent mode) |
| `--plan` | Show implementation plan only, do not write code |
| `--validate` | Run `/testify` after completion (default: auto-detect — true if testify installed, false otherwise) |
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

**Philosophy reference:** See Embedded References below.
**Spec format reference:** See Embedded References below.

## Execution Strategy

### Phase 1: Setup

1. **Parse arguments** to extract:
   - Target path (optional — file or folder of spec files)
   - `--plan` flag (plan only, do not implement)
   - `--validate` flag (run testify after completion)
   - `--export` flag (save report)

2. **Detect project conventions** by examining project files:
   - **Language and framework**: Look for `package.json`, `pyproject.toml`, `Cargo.toml`, `go.mod`, `pom.xml`, `build.gradle`, `Gemfile`, `*.csproj`, etc.
   - **Test runner**: Identify the test command (e.g., `npm test`, `pytest`, `go test`, `cargo test`, `mvn test`)
   - **Test file patterns**: Detect conventions (e.g., `*_test.go`, `test_*.py`, `*.spec.ts`, `*.test.js`, `*Test.java`)
   - **Directory structure**: Identify where tests and source files live
   - **Existing test style**: Read 1-2 existing test files to match conventions (assertion library, naming, structure)

3. **Detect testify availability**:
   - Testify is a sibling skill in this plugin and is always co-installed with tdd
   - If `--validate` was not explicitly set: default to `true`
   - If `--validate` was explicitly set to `false`: respect the flag

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

Spawn a `general-purpose` agent with a prompt that includes:

1. **Role**: "You are a TDD agent. Implement features by strictly following the Red-Green-Refactor cycle for each scenario."
2. **Philosophy**: Include the complete Test Philosophy from Embedded References (copy verbatim) in the spawn prompt
3. **Spec format**: Include the complete Spec Format from Embedded References (copy verbatim) in the spawn prompt
4. **Project context** (detected in Phase 1):
   - Language/framework
   - Test runner command
   - Test file pattern
   - Source directory
   - Test directory
5. **Scenarios**: The selected scenarios, formatted as numbered Given/When/Then blocks
6. **Test naming convention** — follow RITEway principles. Each test should answer the 5 Questions structurally. When the project uses a RITEway assertion library, map Given/When/Then to RITEway's `assert()` interface:
   - `given`: the precondition (from the spec's Given clause)
   - `should`: the expected behavior (from When + Then)
   - `actual`: the actual return value
   - `expected`: the expected return value
   - Example: Given "an empty cart" / When "adding an item" / Then "cart contains 1 item" becomes `assert({ given: 'an empty cart', should: 'contain 1 item after adding', actual: cart.count(), expected: 1 })`
   - When RITEway is not available, use descriptive test names that mirror the Given/When/Then language from the spec.
7. **Execution protocol** — include this in the spawn prompt:
   - **RED**: Write a failing test for the scenario. Test observable behavior, follow RITE principles, answer the 5 Questions, match project conventions. Run tests — confirm failure.
     - Determine test type: pure logic (calculation, transformation, validation) gets a unit test with no mocks. I/O behavior (file ops, network, CLI) gets an integration test through real entry points.
   - **GREEN**: Write minimum code to pass. Apply Functional Core / Imperative Shell — pure logic in pure functions (no I/O, deterministic), I/O in thin wrapper functions. If the scenario requires both, write them as separate functions. Do NOT add code beyond what the test requires. Run tests — confirm ALL tests pass.
   - **REFACTOR**: Review for I/O mixed with logic (extract pure functions), duplication (extract only if genuinely duplicated), naming clarity, test quality (still RITE? testing behavior not implementation?). Re-run tests if changes made. If no refactoring needed, state why briefly.
   - **VALIDATE** (if validate is enabled and testify is available): After each scenario's REFACTOR step, review code design and test quality alignment against the test philosophy. Check: Is I/O separated from logic? Are tests testing observable behavior? Are there untested error paths introduced by this scenario? Fix issues before proceeding to the next scenario. This catches design drift early rather than accumulating it across all scenarios.
   - Between scenarios, output: `Scenario {N}/{total}: {name} — {test count} tests passing`
   - After all scenarios: run full test suite, summarize tests written (unit pure / unit mocked / integration), list pure functions, I/O shells, and orchestrators created.
8. **Code design principles**: Functional Core / Imperative Shell is mandatory. Pure functions get unit tests (no mocks). I/O gets integration tests. Never mock pure functions. Max 2-3 mocks per test for unavailable external services only.
9. **Output expectations**: Show actual test output (not summaries). Show actual code written. Never fabricate test results. If a test unexpectedly fails during GREEN, debug and fix — do NOT skip.
10. **Validate instructions**:
   - If validate is enabled: "Run VALIDATE after each scenario's REFACTOR step (per-scenario code design and test quality review). After all scenarios are complete, the parent skill will invoke /mikey:testify for a final comprehensive review."
   - If validate is disabled: "No validation step. Skip VALIDATE between scenarios."

Wait for agent completion.

#### Step 4: Post-Completion

After the agent completes:
1. Show final test suite results
2. If `--validate` is true: invoke `/mikey:testify` on the test directory with `--with-design`
3. If `--export`: write report (see Export section)

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

1. Apply the Test Philosophy from Embedded References below
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
3. If `--validate` is true: invoke `/mikey:testify` on the test directory with `--with-design`
4. If `--export`: write report (see Export section)

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

- Apply the Test Philosophy from Embedded References before any analysis or implementation
- Apply the Spec Format from Embedded References when parsing spec files
- The TDD cycle is strict: RED (failing test) → GREEN (minimal pass) → REFACTOR. Never skip steps.
- Code design (functional core / imperative shell) is applied during GREEN and REFACTOR, not as a separate phase
- Match the project's existing conventions for test location, naming, assertion style, and file organization

---

## Embedded References

### Test Philosophy

This document contains the complete test philosophy. These principles are language-agnostic.

#### Goal: Confidence in Code Changes

Tests that provide high confidence allow refactoring without fear—and without rewriting tests.

#### Core Principles

##### 1. Test Observable Behavior, Not Implementation

Focus on **what the code returns**, not how it works internally.

```
# GOOD: Tests observable behavior
result = get_user_by_id(123)
assert result == { id: 123, name: "John" }

# BAD: Tests implementation details
get_user_by_id(123)
assert mock_database.query.was_called()
assert mock_cache.set.was_called()
```

**Litmus test**: Can you refactor code without changing tests? If yes, high confidence.

##### 2. Prefer Integration Tests

- Test the system as users interact with it
- Catch issues unit tests miss
- Resistant to refactoring
- Provide higher confidence per test

**Test pyramid**:
- **Many integration tests**: CLI commands, public API entry points
- **Some unit tests**: Pure functions, utilities, data transformations
- **Few mocks**: Only for external dependencies (unavailable runtimes, external APIs)

##### 3. Don't Unit Test I/O

I/O operations should be tested via integration tests:
- **Unit tests**: Pure functions, business logic, calculations
- **Integration tests**: CLI commands, file operations, API calls

If mocking I/O in unit tests → extract pure logic OR write integration test instead.

##### 4. Separate Logic from I/O (Functional Core / Imperative Shell)

| Layer | Description | Testing |
|-------|-------------|---------|
| **Pure Core** | No I/O, deterministic, data transformation | Unit tests, NO mocks |
| **I/O Shell** | File reads, console output, network | Integration tests OR dependency injection |
| **Orchestrator** | Coordinates pure + I/O | Integration tests via entry point |

**Example (pseudocode):**

```
# BAD: I/O mixed with logic
function process_file(path):
    data = read_file(path)           # I/O
    parsed = parse(data)             # Pure
    filtered = filter_active(parsed) # Pure
    print("Found " + len(filtered))  # I/O
    return filtered

# GOOD: Separated
function filter_active(items):       # Pure - easy to test
    return [x for x in items if x.active]

function process_file(path):         # I/O shell
    data = read_file(path)
    parsed = parse(data)
    filtered = filter_active(parsed)
    print("Found " + len(filtered))
    return filtered
```

#### RITE Tests

Every test should be:

- **Readable**: Clear structure, descriptive names, obvious arrange/act/assert
- **Isolated**: No shared mutable state, no order dependencies, each test stands alone
- **Thorough**: Covers happy paths, edge cases, and error conditions
- **Explicit**: Tests observable behavior (return values, errors), NOT internal state or implementation details

#### 5 Questions Every Test Must Answer

1. What is the unit under test?
2. What should it do? (behavior, not implementation)
3. What is the actual output?
4. What is the expected output?
5. How do you reproduce the failure?

##### RITEway Assertion Libraries

The [RITEway](https://github.com/paralleldrive/riteway) assertion style enforces all 5 questions structurally — each assertion requires `given`, `should`, `actual`, and `expected` fields, making it impossible to write a test that doesn't answer them. Failures read like bug reports: "Given X, should Y, but got Z."

Available libraries:
- **JavaScript**: [riteway](https://github.com/paralleldrive/riteway)
- **Ruby**: [riteway-ruby](https://github.com/mycargus/riteway-ruby)
- **Go**: [riteway-golang](https://github.com/mycargus/riteway-golang)

If a project already uses RITEway assertions, evaluate compliance. If not, do not flag non-compliance — but recommend RITEway when tests consistently fail to answer the 5 questions.

#### Anti-Patterns

| Anti-Pattern | Why It's Bad | Fix |
|--------------|--------------|-----|
| Testing implementation details | Breaks on refactor | Test outputs, not internals |
| Over-mocking | Tests don't validate real behavior | Use integration tests |
| Brittle assertions | Exact strings, whitespace | Assert structure, not format |
| I/O in unit tests | Couples to filesystem/network | Extract pure logic |
| Testing private state | Implementation detail | Test public interface |
| Call count assertions | Implementation detail | Assert return value |

#### Identifying Function Types

**Pure Core** (unit testable without mocks):
- No file, network, database, or console I/O
- No mutations of external state
- Returns data based solely on inputs
- Deterministic (same input → same output)

**I/O Shell** (integration testable):
- Reads from or writes to external systems (files, network, database, stdout)
- Has side effects
- Coordinates with external resources

**Orchestrators** (integration testable via entry point):
- Calls both pure and I/O functions
- Usually an entry point (main, command handler, request handler)

#### When to Mock

**Acceptable Mocking**
- External services in integration tests (APIs, databases)
- System clock for time-dependent tests
- Unavailable runtimes (e.g., modules that only run in a specific runtime environment)
- Limit: 2-3 mocks per test maximum

**Mocking Red Flags**
- Mocking filesystem in unit tests → extract pure logic instead
- Mocking more than 2-3 things → code may be too tightly coupled
- Mocking pure functions → never needed
- More mock setup than test code → design smell

#### Test Coverage Guidelines

- **Coverage target**: Check the project's test configuration for thresholds
- **Integration tests**: Entry point is CLI binary or public API
- **Unit tests**: Pure functions and business logic in isolation

#### Further Reading

- [Functional Core, Imperative Shell](https://www.destroyallsoftware.com/screencasts/catalog/functional-core-imperative-shell)
- [Mocking is a Code Smell](https://medium.com/javascript-scene/mocking-is-a-code-smell-944a70c90a6a)
- [TDD the RITE Way](https://medium.com/javascript-scene/tdd-the-rite-way-53c9b46f45e3)
- [5 Questions Every Unit Test Must Answer](https://medium.com/javascript-scene/what-every-unit-test-needs-f6cd34d9836d)

---

### Spec Format

#### Given/When/Then Structure

Specs describe user scenarios using the Given/When/Then pattern:

- **Given**: The precondition or initial state
- **When**: The action or event
- **Then**: The expected outcome (observable behavior)

#### Accepted Formats

The tdd skill accepts any text format containing Given/When/Then patterns. It does not enforce strict Gherkin syntax.

**Gherkin (.feature files)**

```gherkin
Feature: User Registration

  Scenario: Successful registration
    Given a valid email "user@example.com"
    And a password "securePass123"
    When the user submits the registration form
    Then the account is created
    And a confirmation email is sent

  Scenario: Duplicate email
    Given an existing account with email "user@example.com"
    When a new user tries to register with "user@example.com"
    Then registration fails with "email already taken"
```

**Markdown**

```markdown
# User Registration

## Successful registration
- Given a valid email and password
- When the user submits the registration form
- Then the account is created and a confirmation email is sent

## Duplicate email
- Given an existing account with email "user@example.com"
- When a new user tries to register with "user@example.com"
- Then registration fails with "email already taken"
```

**Plain Text**

```
User Registration

Scenario: Successful registration
Given a valid email and password
When the user submits the registration form
Then the account is created and a confirmation email is sent

Scenario: Duplicate email
Given an existing account with email "user@example.com"
When a new user tries to register with "user@example.com"
Then registration fails with "email already taken"
```

#### Parsing Rules

1. Look for lines starting with `Given`, `When`, `Then`, `And`, `But` (case-insensitive)
2. `And`/`But` lines continue the previous Given/When/Then clause
3. Group into scenarios by:
   - Explicit `Scenario:` or `##` headers
   - Blank-line separation between Given/When/Then groups
4. Extract `Feature:` or `#` headers as the feature name
5. If no explicit scenario grouping, treat each Given/When/Then triplet as a scenario

#### Writing Good Specs

**Focus on observable behavior**, not implementation:

```
# GOOD: Describes what the user sees
Given a shopping cart with 3 items
When the user removes an item
Then the cart shows 2 items

# BAD: Describes implementation
Given items are stored in an array
When splice is called with index 1
Then the array length is 2
```

**Include error scenarios**:

```
Given an empty shopping cart
When the user tries to checkout
Then an error is shown: "Cart is empty"
```

**Include edge cases**:

```
Given a cart with the maximum allowed items (99)
When the user tries to add another item
Then an error is shown: "Cart is full"
```
