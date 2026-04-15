---
name: mikey:testify
description: "Review and align tests with test philosophy. Identifies code design issues (I/O mixed with logic), implementation detail testing, excessive mocking, negative test coverage gaps (untested error paths/validations in source), and suggests improvements. Use --plan to generate a saved implementation plan without bloating the current context."
argument-hint: [path] [--with-design] [--with-coverage] [--plan] [--export]
user-invocable: true
---

# Test Philosophy Alignment Skill

## Quick Reference

| Parameter | Description |
|-----------|-------------|
| `path` | Target directory or file (default: project test directory) |
| `--with-design` | Analyze source code for I/O/logic mixing |
| `--with-coverage` | Run tests with coverage, find untested code |
| `--plan` | Generate implementation plan and save to project root |
| `--export` | Save report to `testify-report-<timestamp>.md` |

## Description

Review and align tests with embedded test philosophy. Identifies code design issues (I/O mixed with logic), implementation detail testing, excessive mocking, negative test coverage gaps, and suggests improvements.

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
6. Can optionally generate a saved implementation plan (via `--plan`)

**Shared references:**
- `${CLAUDE_PLUGIN_ROOT}/references/code-testability.md` — How to structure code for testability
- `${CLAUDE_PLUGIN_ROOT}/references/test-quality.md` — What makes tests reliable and valuable
- `${CLAUDE_PLUGIN_ROOT}/references/test-pyramid.md` — Which test layer each scenario belongs at

## Execution Strategy

### Phase 1: Setup

1. **Parse arguments** to extract:
   - Target path (default: detect from project structure)
   - `--with-design` flag (analyze source code structure)
   - `--with-coverage` flag (find untested code)
   - `--plan` flag (generate and save an implementation plan after analysis)

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

4. **Display setup summary** to the user before proceeding:
   ```
   Phase 1: Setup
   - Target: {path} — {language} project, {test pattern} convention
   - Flags: {enabled flags}

   Source files ({count}):
   - {grouped by directory}

   Test files ({count}):
   - {grouped by directory}
   ```

5. **Run tests with coverage** (if `--with-coverage`):
   - Run the project's coverage command, scoping to the target path if possible
   - Read the coverage output file directly using the Read tool
   - Extract per-file summaries: coverage percentages, uncovered functions/lines/branches
   - If coverage data is unavailable, warn the user and fall back to inference-based analysis

### Phase 2: Analysis

Spawn an `analysis-agent` subagent for context isolation. The spawn prompt must follow the instructions in `${CLAUDE_PLUGIN_ROOT}/skills/testify/references/analysis-prompt.md`. Pass the following context:

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
   - I/O functions without interface tests → flag as gap
   - Over-mocked tests + mixed architecture → flag as root cause issue

2. **Cross-reference** test layer placement (using criteria from `${CLAUDE_PLUGIN_ROOT}/references/test-pyramid.md`):
   - Merge layer misplacements reported by the analysis-agent
   - Correlate with code design findings — misplaced tests often indicate code design violations

3. **Cross-reference** negative test coverage gaps:
   - Source validations (throws, guard clauses) without corresponding negative tests → flag as gap
   - State machine violations without tests → flag as gap
   - Error stubs / fallback handlers without tests → flag as gap

4. **Cross-reference** edge case gaps:
   - Boundary values (0, empty, single-element) in source logic without corresponding tests → flag as gap
   - Default parameter paths untested → flag as gap
   - Falsy-but-valid values where truthy checks exist → flag as gap

5. **Calculate grade** (A/B/C/D/F):
   - **HIGH issues always cap the grade at B or below**
   - A: 90%+ pure/interface tests, <10% mocked, 90%+ negative coverage, 80%+ edge case coverage, zero HIGH issues, RITE all "pass"
   - B: 70%+ pure/interface tests, <20% mocked, 70%+ negative coverage, one or few HIGH issues
   - C: 50%+ pure/interface tests, <40% mocked, multiple HIGH issues
   - D: <50% pure/interface tests, heavy mocking, many HIGH issues
   - F: Mostly mocked tests, tests implementation not behavior, many violations

6. **Prioritize issues**:
   - HIGH: Design violations, implementation testing, test layer misplacement (user-facing behavior tested at unit level), uncovered public API validations, correctness-affecting boundary conditions
   - MEDIUM: Over-mocking, brittle assertions, uncovered internal validations, untested defaults, test files exceeding 500 lines
   - LOW: Style issues, minor improvements, defensive checks unlikely to be hit

### Phase 4: Report

Generate a structured markdown report following the template in `${CLAUDE_PLUGIN_ROOT}/skills/testify/references/report-template.md`.

**Evidence Standards:**
- Every finding MUST include `[file:line]` reference
- Include exact code quotes for violations
- Mark confidence: `(verified)`, `(inferred)`, or `(uncertain)`
- Do NOT report findings without supporting evidence

### Phase 4.5: Export (if --export)

Write the report to `testify-report-<timestamp>.md` in the project root using `date +%Y%m%d-%H%M%S` for the timestamp.

### Phase 4.75: Plan Prompt (if --plan was NOT specified)

After displaying the report, use AskUserQuestion to ask:

> "Would you like me to generate an implementation plan and save it to the project root?"
> Options: "Yes, include all findings", "Yes, HIGH priority only", "Yes, HIGH and MEDIUM only", "No"

- "Yes, include all findings" → proceed to Phase 5 with all findings
- "Yes, HIGH priority only" → proceed to Phase 5, instruct Plan agent to include only HIGH findings
- "Yes, HIGH and MEDIUM only" → proceed to Phase 5, instruct Plan agent to include only HIGH and MEDIUM findings
- "No" → stop here

Pass the chosen scope to Phase 5 so the Plan agent's instruction reflects it.

### Phase 5: Planning (if --plan was specified, or user said yes in Phase 4.75)

Before spawning the Plan agent, read the shared references (`${CLAUDE_PLUGIN_ROOT}/references/code-testability.md`, `${CLAUDE_PLUGIN_ROOT}/references/test-quality.md`, `${CLAUDE_PLUGIN_ROOT}/references/test-pyramid.md`) yourself and embed their content into the agent prompt.

Spawn a `Plan` subagent with a prompt containing:

- The full report from Phase 4 (paste inline)
- The test philosophy content (paste inline — do not pass a file path)
- The source and test file lists from Phase 1
- This instruction, with `{scope}` replaced by the chosen scope:
  - `--plan` specified upfront → scope = "all findings (HIGH, MEDIUM, and LOW)"
  - User chose "Yes, include all findings" → scope = "all findings (HIGH, MEDIUM, and LOW)"
  - User chose "Yes, HIGH and MEDIUM only" → scope = "only HIGH and MEDIUM findings — omit LOW"
  - User chose "Yes, HIGH priority only" → scope = "only HIGH findings — omit MEDIUM and LOW"

  > Produce a prioritized, step-by-step implementation plan. Output only the plan — no code, no preamble. Include {scope}. Structure it as follows:
  >
  > ## Summary
  > One paragraph: overall test quality state and grade.
  >
  > ## Steps
  > Numbered list. Each step must include:
  > - **What**: concrete description of the change (not just "add a test" — name the scenario, the input, the expected behavior)
  > - **Why**: the finding it addresses, with `[file:line]` reference and its priority (HIGH / MEDIUM / LOW)
  > - **Risk**: `low` (test-only) | `medium` (adds/moves source code) | `high` (restructures source code)
  >
  > Order by impact: design violations → negative coverage gaps → edge case gaps → style/low issues.

#### Save the plan:

After the Plan agent returns, use `date +%Y%m%d-%H%M%S` to get a timestamp, then write the agent's output to `testify-plan-<timestamp>.md` in the project root using the Write tool.

Display the file path to the user so they can open it and run `/tdd` or implement manually at their own pace.

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

- Read and apply the shared references from `${CLAUDE_PLUGIN_ROOT}/references/` (code-testability.md, test-quality.md, test-pyramid.md) before analysis
- Code design issues are often the root cause of test issues
- Negative test gap analysis runs every time (not behind a flag) because untested validations are a fundamental quality concern
- The target path can be a test directory OR a source directory — infer the counterpart accordingly
- When `--export` is set, generate `testify-report-<timestamp>.md` using `date +%Y%m%d-%H%M%S`
- When `--plan` is set, spawn a Plan subagent and save `testify-plan-<timestamp>.md` to the project root — do NOT implement fixes inline
- Analysis always runs in a subagent for context isolation
- `--plan` exists to keep context clean: implementation happens in a separate session using the saved plan

---

## References

### Shared References (read before analysis)

All shared references are in `${CLAUDE_PLUGIN_ROOT}/references/`:

- **code-testability.md** — How to structure code for testability (FC/IS, function types)
- **test-quality.md** — What makes tests reliable and valuable (RITE, anti-patterns, mocking)
- **test-pyramid.md** — Which test layer each scenario belongs at (4 layers, decision criteria)

### Skill-Specific References

Testify-specific references are in `${CLAUDE_PLUGIN_ROOT}/skills/testify/references/`:

- **analysis-prompt.md** — Instructions for the analysis-agent subagent
- **report-template.md** — Markdown template for the alignment report
