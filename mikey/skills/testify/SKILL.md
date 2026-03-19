---
name: mikey:testify
description: Review and align tests with test philosophy. Identifies code design issues (I/O mixed with logic), implementation detail testing, excessive mocking, negative test coverage gaps (untested error paths/validations in source), and suggests or implements improvements.
argument-hint: [path] [--with-design] [--with-coverage] [--implement] [--export]
user-invocable: true
---

# Test Philosophy Alignment Skill

## Quick Reference

| Parameter | Description |
|-----------|-------------|
| `path` | Target directory or file (default: project test directory) |
| `--with-design` | Analyze source code for I/O/logic mixing |
| `--with-coverage` | Run tests with coverage, find untested code |
| `--implement` | Apply fixes after analysis |
| `--export` | Save report to `testify-report-<timestamp>.md` |

## Description

Review and align tests with embedded test philosophy. Identifies code design issues (I/O mixed with logic), implementation detail testing, excessive mocking, negative test coverage gaps, and suggests or implements improvements.

**Use when:**
- Adding new test files
- Reviewing test quality
- Refactoring tests for maintainability
- After significant code changes
- When tests require lots of mocking

**This skill:**
1. Analyzes code design (functional core vs imperative shell)
2. Analyzes tests against test philosophy
3. Identifies discrepancies (implementation testing, brittle assertions, excessive mocking)
4. **Always** cross-references source validations against tests to find negative coverage gaps
5. Provides structured report with specific improvements
6. Can optionally implement the improvements

**Philosophy reference:** See Embedded References below.

## Execution Strategy

### Phase 1: Setup

1. **Parse arguments** to extract:
   - Target path (default: detect from project structure)
   - `--with-design` flag (analyze source code structure)
   - `--with-coverage` flag (find untested code)
   - `--implement` flag (apply fixes after analysis)

2. **Detect project conventions** by examining project files:
   - **Language and framework**: Look for `package.json`, `pyproject.toml`, `Cargo.toml`, `go.mod`, `pom.xml`, `build.gradle`, `Gemfile`, `*.csproj`, etc.
   - **Test runner**: Identify the test command (e.g., `npm test`, `pytest`, `go test`, `cargo test`, `mvn test`)
   - **Test file patterns**: Detect conventions (e.g., `*_test.go`, `test_*.py`, `*.spec.ts`, `*.test.js`, `*Test.java`)
   - **Directory structure**: Identify where tests and source files live

3. **Gather file lists**:
   - Determine if target is a test path or source path based on project conventions
   - Glob test and source files using detected patterns
   - If given a test path, find corresponding source files by reading imports
   - If given a source path, find corresponding test files by convention

4. **Run tests with coverage** (if `--with-coverage`):
   - Run the project's coverage command, scoping to the target path if possible
   - Read the coverage output file directly using the Read tool
   - Extract per-file summaries: coverage percentages, uncovered functions/lines/branches
   - If coverage data is unavailable, warn the user and fall back to inference-based analysis

### Phase 2: Analysis

Spawn an `analysis-agent` subagent for context isolation. The spawn prompt must begin with the complete Test Philosophy from Embedded References (copy verbatim), followed by the Analysis Instructions from Embedded References. Pass the following context:

- **Test files**: absolute file paths, one per line, prefixed with `- `
- **Source files**: absolute file paths, one per line, prefixed with `- `
- **include_design**: `true` if `--with-design`, else `false`
- **include_coverage**: `true` if `--with-coverage`, else `false`
- **coverage_data**: coverage summaries from Phase 1 (or `N/A` if not available)

Wait for agent completion.

### Phase 3: Synthesis

Merge findings from analysis (direct or subagent):

1. **Cross-reference** code design with tests (if `--with-design`):
   - Pure functions with mocked tests → flag as violation
   - I/O functions without integration tests → flag as gap
   - Over-mocked tests + mixed architecture → flag as root cause issue

2. **Cross-reference** negative test coverage gaps:
   - Source validations (throws, guard clauses) without corresponding negative tests → flag as gap
   - State machine violations without tests → flag as gap
   - Error stubs / fallback handlers without tests → flag as gap

3. **Cross-reference** edge case gaps:
   - Boundary values (0, empty, single-element) in source logic without corresponding tests → flag as gap
   - Default parameter paths untested → flag as gap
   - Falsy-but-valid values where truthy checks exist → flag as gap

4. **Calculate grade** (A/B/C/D/F):
   - **HIGH issues always cap the grade at B or below**
   - A: 90%+ pure/integration tests, <10% mocked, 90%+ negative coverage, 80%+ edge case coverage, zero HIGH issues, RITE all "pass"
   - B: 70%+ pure/integration tests, <20% mocked, 70%+ negative coverage, one or few HIGH issues
   - C: 50%+ pure/integration tests, <40% mocked, multiple HIGH issues
   - D: <50% pure/integration tests, heavy mocking, many HIGH issues
   - F: Mostly mocked tests, tests implementation not behavior, many violations

5. **Prioritize issues**:
   - HIGH: Design violations, implementation testing, uncovered public API validations, correctness-affecting boundary conditions
   - MEDIUM: Over-mocking, brittle assertions, uncovered internal validations, untested defaults
   - LOW: Style issues, minor improvements, defensive checks unlikely to be hit

### Phase 4: Report

Generate a structured markdown report following the Report Template from Embedded References below.

**Evidence Standards:**
- Every finding MUST include `[file:line]` reference
- Include exact code quotes for violations
- Mark confidence: `(verified)`, `(inferred)`, or `(uncertain)`
- Do NOT report findings without supporting evidence

### Phase 4.5: Export (if --export)

Write the report to `testify-report-<timestamp>.md` in the project root using `date +%Y%m%d-%H%M%S` for the timestamp.

### Phase 5: Implementation (if --implement)

#### Step 1: Present Implementation Plan

After showing the report, present a numbered list of specific changes. Every item MUST reference actual findings from the analysis phase with file:line.

#### Step 2: Ask for Confirmation

Use AskUserQuestion:
- "All fixes (Recommended)"
- "Code design fixes only"
- "Test fixes only"
- "Let me pick specific items"

#### Step 3: Execute Fixes

For each approved fix:
- **Design extraction**: Extract pure logic from mixed I/O functions into separate testable functions
- **Test simplification**: Replace implementation-testing assertions with behavior-testing assertions
- **Integration conversion**: Replace heavily mocked tests with integration tests using real entry points
- **Brittle assertion fixes**: Replace exact format checks with structural assertions

#### Step 4: Verify Changes

After each fix or batch:
1. Run affected tests and show actual output
2. If tests pass, continue to next fix
3. If tests fail, show failure output and ask user how to proceed

#### Step 5: Final Verification

After all fixes:
1. Run the full test suite — show actual output
2. If `--with-coverage` was used, run coverage again and show before/after comparison
3. Report summary with actual values from command output

#### Rollback on Failure

If the full test suite fails after implementation, offer:
- "Revert all changes"
- "Keep changes and debug together"
- "Keep changes, I'll fix manually"

## Uncertainty Handling

**Confidence levels:**
- `(verified)` — directly observed in code with file:line reference
- `(inferred)` — logical conclusion from patterns (explain reasoning)
- `(uncertain)` — could not determine definitively (explain why)

**Never:**
- Report violations without file:line evidence
- Fabricate line numbers, code snippets, test counts, or coverage percentages
- Propose fixes for issues you didn't actually find
- Claim tests pass without running them and showing output
- Summarize test results without showing actual output first

## Important Notes

- Apply the Test Philosophy from Embedded References before analysis
- Code design issues are often the root cause of test issues
- Negative test gap analysis runs every time (not behind a flag) because untested validations are a fundamental quality concern
- The target path can be a test directory OR a source directory — infer the counterpart accordingly
- When `--export` is set, generate `testify-report-<timestamp>.md` using `date +%Y%m%d-%H%M%S`
- Analysis always runs in a subagent for context isolation

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

### Analysis Instructions

Use these instructions when spawning the `analysis-agent` subagent. The subagent prompt must begin with the complete Test Philosophy above (copy verbatim), followed by these instructions.

#### Expected Input

The spawn prompt must include the following labeled sections:

**Test Files**
Absolute file paths, one per line, prefixed with `- `:
```
- /absolute/path/to/test_file1.test.js
- /absolute/path/to/test_file2.test.js
```

**Source Files**
Absolute file paths, one per line, prefixed with `- `:
```
- /absolute/path/to/source1.js
- /absolute/path/to/source2.js
```

**Flags**
- **include_design**: `true` or `false` — whether to perform code design analysis (section 4)
- **include_coverage**: `true` or `false` — whether to incorporate coverage data (section 5)

**Coverage Data**
Coverage summaries from the test runner, or `N/A` if not available. When present, use as ground truth in section 5.

#### What to Analyze

Perform ALL of the following that apply:

**1. Test Pattern Analysis (always)**

For each test file:

1. **Categorize tests** as:
   - **Unit (pure)**: Tests a pure function with no mocks and no I/O
   - **Unit (mocked)**: Tests that mock the code under test (not external runtime dependencies). Tests that only mock unavailable external runtimes count as `unitPure`.
   - **Integration**: Spawns a process, uses real filesystem, exercises real entry points

2. **Evaluate RITE principles** (for ALL tests regardless of assertion style):
   - **Readable**: Clear test structure? Descriptive names? Obvious arrange/act/assert?
   - **Isolated**: No shared mutable state between tests? No order dependencies?
   - **Thorough**: Happy path + edge cases + error conditions covered?
   - **Explicit**: Tests observable behavior (return values, errors)? Or tests internal state / implementation details?
   - Score each: `"pass"`, `"concern"` (with evidence), or `"fail"` (with evidence)

3. **Detect anti-patterns**:
   - **Implementation testing**: Assertions on mock calls, call counts, or internal method invocations instead of return values or observable behavior
   - **Over-mocking**: Mock/stub/spy count exceeds assertion count
   - **Brittle assertions**: Exact whitespace/formatting checks, snapshot tests of volatile output
   - **Missing isolation**: Shared state, execution order dependencies

4. **Verify 5 Questions** — each test should answer: What is the unit under test? What should it do? What is the actual output? What is the expected output? How do you reproduce the failure? If many tests fail to answer these questions, recommend adopting a [RITEway](https://github.com/paralleldrive/riteway) assertion library (available for JavaScript, Ruby, and Go — see philosophy reference for links), which enforces all 5 questions structurally.

5. **Calculate metrics**: Mock count, assertion count, and ratio per test file

**2. Negative Test Coverage Gaps (always)**

Read the source files and scan for **every** error path:

- **Throw/raise statements** — every explicit error throw in source must have a test that triggers it
- **Guard clauses** — early returns or throws on invalid input
- **Validation calls** — calls to validation helpers
- **Error callbacks / fallback handlers**
- **Conditional error branches** — if/else where one branch is an error path
- **State-dependent restrictions** — methods that should error in certain states (e.g., after finalization)

For each error path found, search the test files for a test that exercises it. Record covered and uncovered paths with source file:line, the error message/condition, and a suggested test description for uncovered ones.

**Severity:**
- **HIGH**: Public API validation with no test, state machine violation with no test
- **MEDIUM**: Internal validation that could surface to users
- **LOW**: Defensive checks unlikely to be hit in practice

**3. Edge Case Gaps (always)**

Scan source for boundary conditions and check whether tests exercise them:

- **Boundary values** — 0, negative, max values for numeric parameters; empty iteration (count=0)
- **Empty inputs** — empty collections, empty strings passed to functions that iterate or transform
- **Single-element collections** — off-by-one / fence-post errors
- **Optional/default parameters** — is the default path tested separately from the explicit path?
- **Falsy-but-valid values** — `0`, `""`, `false`, `nil` where truthy checks might incorrectly reject them
- **Iteration boundaries** — first/last iteration, wraparound/modulo logic, off-by-one in index calculations
- **Multiple calls / accumulation** — does state accumulate correctly across calls?

**Severity:**
- **HIGH**: Boundary in public API affecting correctness
- **MEDIUM**: Default parameter paths untested, single-element edge cases
- **LOW**: Internal boundaries unlikely to be hit

**4. Code Design Analysis (only if include_design is true)**

For each source file, classify functions/methods as:

- **Pure**: No I/O, deterministic, returns data based solely on inputs
- **I/O**: Reads/writes files, network, database, console/stdout, subprocess execution
- **Orchestrator**: Coordinates pure and I/O functions, usually an entry point
- **Violation**: Mixes data transformation AND I/O in the same function

For violations, identify what pure logic could be extracted and suggest a function name.

Grade each file: **Good** (clean separation), **Mixed** (1-2 violations), **Poor** (significant mixing).

**5. Coverage Data Analysis (only if include_coverage is true)**

Use the provided coverage data as ground truth:

- Use coverage percentages directly — do not estimate
- Identify uncovered functions, statements, and branches by line number
- Read source files at uncovered lines to understand what's missing
- Mark findings as `"confidence": "verified"` when backed by coverage data
- If a file is absent from coverage data, fall back to inference and mark as `"confidence": "inferred"`
- Watch for false positives: factory methods or constructors may show as uncovered when the class is instantiated through other means

#### Output Format

Return **valid JSON only** — no markdown, no explanations outside the JSON:

```json
{
  "testAnalysis": {
    "files": [
      {
        "path": "path/to/test_file",
        "testCount": 12,
        "categories": { "unitPure": 8, "unitMocked": 2, "integration": 2 },
        "riteEvaluation": {
          "readable": { "score": "pass|concern|fail", "evidence": "..." },
          "isolated": { "score": "pass|concern|fail", "evidence": "..." },
          "thorough": { "score": "pass|concern|fail", "evidence": "..." },
          "explicit": { "score": "pass|concern|fail", "evidence": "..." }
        },
        "antiPatterns": [
          {
            "line": 67,
            "pattern": "implementation_testing|over_mocking|brittle_assertion|missing_isolation",
            "severity": "HIGH|MEDIUM|LOW",
            "code": "the offending code",
            "suggestion": "how to fix",
            "confidence": "verified|inferred|uncertain"
          }
        ],
        "metrics": { "mockCount": 4, "assertionCount": 12, "ratio": 0.33 }
      }
    ]
  },
  "negativeTestGaps": [
    {
      "sourceFile": "path/to/source",
      "sourceLine": 43,
      "errorDescription": "description of the error/validation",
      "type": "throw|guard|validation|error_callback|state_restriction",
      "testedBy": "path/to/test:line or null",
      "covered": true,
      "severity": "HIGH|MEDIUM|LOW",
      "suggestedTest": "description (only if uncovered)",
      "confidence": "verified|inferred|uncertain"
    }
  ],
  "edgeCaseGaps": [
    {
      "sourceFile": "path/to/source",
      "sourceLine": 384,
      "boundary": "short description",
      "description": "what happens at this boundary",
      "type": "boundary_value|empty_collection|single_element|default_parameter|falsy_valid|iteration_boundary|accumulation",
      "testedBy": "path/to/test:line or null",
      "covered": false,
      "severity": "HIGH|MEDIUM|LOW",
      "suggestedTest": "description (only if uncovered)",
      "confidence": "verified|inferred|uncertain"
    }
  ],
  "codeDesign": {
    "_comment": "Only included when include_design is true",
    "files": [
      {
        "path": "path/to/source",
        "architecture": "good|mixed|poor",
        "pureFunctions": [{ "name": "fn", "lines": "10-20", "characteristics": "..." }],
        "ioFunctions": [{ "name": "fn", "lines": "30-40", "characteristics": "..." }],
        "orchestrators": [{ "name": "fn", "lines": "50-60", "characteristics": "..." }],
        "violations": [
          {
            "function": "fn",
            "lines": "70-90",
            "issue": "what's mixed",
            "extractable": "suggestedPureFunctionName(params)",
            "confidence": "verified|inferred|uncertain"
          }
        ]
      }
    ]
  },
  "coverageAnalysis": {
    "_comment": "Only included when include_coverage is true",
    "coverageSource": "actual|inferred",
    "files": [
      {
        "sourcePath": "path/to/source",
        "coverage": {
          "statements": { "covered": 249, "total": 281, "pct": 88.6 },
          "functions": { "covered": 20, "total": 29, "pct": 69.0 },
          "branches": { "covered": 53, "total": 65, "pct": 81.5 }
        },
        "gaps": [
          {
            "type": "no_coverage|uncovered_lines|uncovered_branch",
            "description": "what's missing",
            "lines": "67-72",
            "priority": "HIGH|MEDIUM|LOW",
            "suggestedTest": "description",
            "confidence": "verified|inferred"
          }
        ]
      }
    ]
  },
  "summary": {
    "totalTests": 45,
    "unitPure": 30,
    "unitMocked": 8,
    "integration": 7,
    "antiPatternCount": 8,
    "highSeverityIssues": 3,
    "negativeGaps": { "total": 8, "covered": 5, "uncovered": 3, "coveragePercent": 62.5 },
    "edgeCaseGaps": { "total": 12, "covered": 8, "uncovered": 4, "coveragePercent": 66.7 },
    "grade": "A|B|C|D|F"
  }
}
```

#### Grading Criteria

**Any HIGH-severity issue caps the grade at B or below.**

- **A**: 90%+ pure/integration tests, <10% mocked, 90%+ negative coverage, 80%+ edge case coverage, zero HIGH issues, RITE all "pass"
- **B**: 70%+ pure/integration tests, <20% mocked, 70%+ negative coverage, one or few HIGH issues
- **C**: 50%+ pure/integration tests, <40% mocked, multiple HIGH issues
- **D**: <50% pure/integration tests, heavy mocking, many HIGH issues
- **F**: Mostly mocked tests, tests implementation not behavior, many violations

#### Confidence Reporting

Every finding must include a confidence level:
- `"verified"` — directly observed in code with exact line reference
- `"inferred"` — concluded from patterns (explain reasoning)
- `"uncertain"` — could not determine (include `"uncertainReason"`)

Never fabricate line numbers. If uncertain, add `"lineApproximate": true`.

---

### Report Template

Use this structure for the Test Philosophy Alignment Report.

```markdown
# Test Philosophy Alignment Report

## Executive Summary
**Grade: {A|B|C|D|F}**
{2-3 sentences summarizing findings}

## Code Design Analysis (if --with-design)

### Functional Core / Imperative Shell Separation
**Overall: {Good|Mixed|Poor}**

### Files with Mixed I/O and Logic
| File | Issue | Extractable Pure Logic |
|------|-------|------------------------|

## Test Pattern Analysis

### Test Distribution
- Total tests: {count}
- Unit (pure): {count}
- Unit (mocked): {count}
- Integration: {count}

### Anti-Patterns Found
{Prioritized list with severity, file, line, issue, suggestion, confidence}

## RITE Evaluation
| Test File | Readable | Isolated | Thorough | Explicit |
|-----------|----------|----------|----------|----------|

## Mock Analysis
| Test File | Mock Count | Assertion Count | Ratio | Assessment |
|-----------|------------|-----------------|-------|------------|

## Negative Test Coverage
**{covered}/{total} validations tested ({percent}%)**

### Uncovered Validations
| Source File:Line | Error/Validation | Severity | Suggested Test |
|------------------|------------------|----------|----------------|

### Covered Validations (for reference)
| Source File:Line | Error/Validation | Tested By |
|------------------|------------------|-----------|

## Edge Case Coverage
**{covered}/{total} edge cases tested ({percent}%)**

### Uncovered Edge Cases
| Source File:Line | Boundary | Type | Severity | Suggested Test |
|------------------|----------|------|----------|----------------|

## Coverage Analysis (if --with-coverage)

### Overall Coverage
- Statements: {pct}%
- Functions: {pct}%
- Branches: {pct}%

### Files with Coverage Gaps
| File | Statement % | Function % | Branch % | Status |
|------|-------------|------------|----------|--------|

### High-Priority Coverage Gaps
{Untested functions and uncovered error paths with file:line}

## Recommendations

### Code Design Improvements (if applicable)
1. Extract {function} from {file}:{line}

### Test Improvements
1. {Priority} - {Category} - {Description}

### Assertion Style (if tests consistently fail the 5 Questions)
Consider adopting a RITEway assertion library to enforce all 5 questions structurally:
- **JavaScript**: [riteway](https://github.com/paralleldrive/riteway)
- **Ruby**: [riteway-ruby](https://github.com/mycargus/riteway-ruby)
- **Go**: [riteway-golang](https://github.com/mycargus/riteway-golang)

## Impact
- Files affected: {count}
- Lines changed: ~{estimate}
- Coverage impact: {assessment}
```
