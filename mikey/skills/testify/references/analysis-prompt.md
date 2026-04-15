# Test Philosophy Analysis Prompt

Use this prompt when spawning a subagent for large-scale test analysis (10+ files).

## Instructions for the Subagent

Analyze test files and source files against test philosophy principles. Return findings as valid JSON.

Read the following shared references and apply their principles throughout this analysis:
- `${CLAUDE_PLUGIN_ROOT}/references/code-testability.md` — How to structure code for testability
- `${CLAUDE_PLUGIN_ROOT}/references/test-quality.md` — What makes tests reliable and valuable
- `${CLAUDE_PLUGIN_ROOT}/references/test-pyramid.md` — Which test layer each scenario belongs at

## Expected Input

The spawn prompt must include the following labeled sections:

### Test Files
Absolute file paths, one per line, prefixed with `- `:
```
- /absolute/path/to/test_file1.test.js
- /absolute/path/to/test_file2.test.js
```

### Source Files
Absolute file paths, one per line, prefixed with `- `:
```
- /absolute/path/to/source1.js
- /absolute/path/to/source2.js
```

### Flags
- **include_design**: `true` or `false` — whether to perform code design analysis (section 4)
- **include_coverage**: `true` or `false` — whether to incorporate coverage data (section 6)

### Coverage Data
Coverage summaries from the test runner, or `N/A` if not available. When present, use as ground truth in section 6.

## What to Analyze

Perform ALL of the following that apply:

### 1. Test Pattern Analysis (always)

For each test file:

1. **Categorize tests** as **Unit (pure)**, **Unit (mocked)**, or **Interface** using the layer definitions in `${CLAUDE_PLUGIN_ROOT}/references/test-pyramid.md`. Note: tests that only mock unavailable external runtimes count as `unitPure`.

2. **Evaluate RITE principles** (see `${CLAUDE_PLUGIN_ROOT}/references/test-quality.md` for definitions). Score each principle per test file: `"pass"`, `"concern"` (with evidence), or `"fail"` (with evidence).

3. **Detect anti-patterns** listed in `${CLAUDE_PLUGIN_ROOT}/references/test-quality.md`: implementation testing, over-mocking, brittle assertions, missing isolation. Record the specific code evidence for each.

4. **Verify 5 Questions** — see `${CLAUDE_PLUGIN_ROOT}/references/test-quality.md` for the questions and RITEway recommendation. If many tests fail to answer them, recommend adopting a RITEway assertion library.

5. **Calculate metrics**: Mock count, assertion count, and ratio per test file

6. **Check file size**: Count lines in each test file. Any test file exceeding 500 lines is a MEDIUM-severity anti-pattern (`file_too_long`). Suggest splitting by feature or behavior.

### 2. Negative Test Coverage Gaps (always)

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

### 3. Edge Case Gaps (always)

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

### 4. Code Design Analysis (only if include_design is true)

For each source file, classify functions/methods as **Pure**, **I/O**, **Orchestrator**, or **Violation** using the definitions in `${CLAUDE_PLUGIN_ROOT}/references/code-testability.md`. For violations, identify what pure logic could be extracted and suggest a function name.

Grade each file: **Good** (clean separation), **Mixed** (1-2 violations), **Poor** (significant mixing).

### 5. Test Layer Placement Analysis (always)

For each test, evaluate whether it is at the appropriate test layer:

1. **Identify the test's current layer**: unit (pure), unit (mocked), or interface — based on how the test invokes the code under test.

2. **Identify the recommended layer** using the decision criteria in `${CLAUDE_PLUGIN_ROOT}/references/test-pyramid.md`.

3. **Flag misplacements** with severity:
   - Unit test testing user-facing behavior that has a public entry point → **HIGH**
   - Unit test excessively mocking internal dependencies (not external APIs) → **HIGH**
   - Interface test using real external APIs when mocks would suffice → **MEDIUM**
   - Pure logic tested at interface level when a unit test would suffice → **LOW**

For each misplacement, record the test file:line, current layer, recommended layer, reason, and severity.

### 6. Coverage Data Analysis (only if include_coverage is true)

Use the provided coverage data as ground truth:

- Use coverage percentages directly — do not estimate
- Identify uncovered functions, statements, and branches by line number
- Read source files at uncovered lines to understand what's missing
- Mark findings as `"confidence": "verified"` when backed by coverage data
- If a file is absent from coverage data, fall back to inference and mark as `"confidence": "inferred"`
- Watch for false positives: factory methods or constructors may show as uncovered when the class is instantiated through other means

## Output Format

Return **valid JSON only** — no markdown, no explanations outside the JSON:

```json
{
  "testAnalysis": {
    "files": [
      {
        "path": "path/to/test_file",
        "testCount": 12,
        "categories": { "unitPure": 8, "unitMocked": 2, "interface": 2 },
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
  "testLayerPlacement": [
    {
      "testFile": "path/to/test_file",
      "testLine": 42,
      "testName": "name of the test",
      "currentLayer": "unit|unitMocked|interface",
      "recommendedLayer": "unit|interface|contract|e2e",
      "reason": "why this test is at the wrong layer",
      "severity": "HIGH|MEDIUM|LOW",
      "confidence": "verified|inferred|uncertain"
    }
  ],
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
    "interface": 7,
    "antiPatternCount": 8,
    "highSeverityIssues": 3,
    "negativeGaps": { "total": 8, "covered": 5, "uncovered": 3, "coveragePercent": 62.5 },
    "edgeCaseGaps": { "total": 12, "covered": 8, "uncovered": 4, "coveragePercent": 66.7 },
    "layerMisplacements": 0,
    "grade": "A|B|C|D|F"
  }
}
```

## Grading Criteria

**Any HIGH-severity issue caps the grade at B or below.**

- **A**: 90%+ pure/interface tests, <10% mocked, 90%+ negative coverage, 80%+ edge case coverage, zero HIGH issues, RITE all "pass"
- **B**: 70%+ pure/interface tests, <20% mocked, 70%+ negative coverage, one or few HIGH issues
- **C**: 50%+ pure/interface tests, <40% mocked, multiple HIGH issues
- **D**: <50% pure/interface tests, heavy mocking, many HIGH issues
- **F**: Mostly mocked tests, tests implementation not behavior, many violations

## Confidence Reporting

Every finding must include a confidence level:
- `"verified"` — directly observed in code with exact line reference
- `"inferred"` — concluded from patterns (explain reasoning)
- `"uncertain"` — could not determine (include `"uncertainReason"`)

Never fabricate line numbers. If uncertain, add `"lineApproximate": true`.
