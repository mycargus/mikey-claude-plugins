---
name: testify
description: Review and align tests with test philosophy. Identifies code design issues (I/O mixed with logic), implementation detail testing, excessive mocking, negative test coverage gaps (untested error paths/validations in source), and suggests or implements improvements.
argument-hint: [path] [--with-design] [--with-coverage] [--implement] [--export]
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

**Philosophy reference:** `${CLAUDE_PLUGIN_ROOT}/skills/testify/references/philosophy.md`

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

5. **Determine strategy**:
   - **< 10 total files** (test + source): Analyze directly in this context
   - **>= 10 total files**: Spawn a subagent for parallel analysis (see Phase 2B)

### Phase 2: Analysis

#### Strategy A: Direct Analysis (fewer than 10 files)

1. Read all test and source files
2. Read philosophy reference: `${CLAUDE_PLUGIN_ROOT}/skills/testify/references/philosophy.md`
3. Apply philosophy checks inline, including negative test coverage and edge case gap analysis
4. If `--with-coverage`: incorporate coverage data
5. If `--with-design`: classify functions as pure/I/O/orchestrator/violation
6. Generate report

#### Strategy B: Subagent Analysis (10+ files)

1. Read the agent template: `${CLAUDE_PLUGIN_ROOT}/skills/testify/agents/analysis-agent.md`
2. Assemble the prompt by replacing placeholders:
   - `{{TEST_FILES}}` — absolute file paths, one per line, prefixed with `- `
   - `{{SOURCE_FILES}}` — absolute file paths, one per line, prefixed with `- `
   - `{{INCLUDE_DESIGN}}` — `true` if `--with-design`, else `false`
   - `{{INCLUDE_COVERAGE}}` — `true` if `--with-coverage`, else `false`
   - `{{COVERAGE_DATA}}` — coverage summaries from Phase 1 (or `N/A` if not available)
   - `{{PHILOSOPHY_PATH}}` — absolute path to `${CLAUDE_PLUGIN_ROOT}/skills/testify/references/philosophy.md`
3. Spawn as an `Explore` agent
4. Wait for completion

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

Generate a structured markdown report following the template at `${CLAUDE_PLUGIN_ROOT}/skills/testify/references/report-template.md`.

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

- Read the philosophy at `${CLAUDE_PLUGIN_ROOT}/skills/testify/references/philosophy.md` before analysis
- Code design issues are often the root cause of test issues
- Negative test gap analysis runs every time (not behind a flag) because untested validations are a fundamental quality concern
- The target path can be a test directory OR a source directory — infer the counterpart accordingly
- When `--export` is set, generate `testify-report-<timestamp>.md` using `date +%Y%m%d-%H%M%S`
- For 10+ files, use subagent mode for efficiency

## Related Documentation

- `${CLAUDE_PLUGIN_ROOT}/skills/testify/references/philosophy.md` — test philosophy reference
- `${CLAUDE_PLUGIN_ROOT}/skills/testify/references/report-template.md` — report structure template
- `${CLAUDE_PLUGIN_ROOT}/skills/testify/examples/examples.md` — example report output
- `${CLAUDE_PLUGIN_ROOT}/skills/testify/agents/analysis-agent.md` — subagent prompt template
