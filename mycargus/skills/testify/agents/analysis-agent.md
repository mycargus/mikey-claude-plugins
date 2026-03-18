# Test Philosophy Analysis Agent

## Task

Analyze test files and source files against test philosophy principles. Return findings as valid JSON.

Read `{{PHILOSOPHY_PATH}}` for the complete test philosophy reference. Apply those principles throughout this analysis.

## What to Analyze

Perform ALL of the following that apply:

### 1. Test Pattern Analysis (always)

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

### 4. Code Design Analysis (only if `{{INCLUDE_DESIGN}}` is `true`)

For each source file, classify functions/methods as:

- **Pure**: No I/O, deterministic, returns data based solely on inputs
- **I/O**: Reads/writes files, network, database, console/stdout, subprocess execution
- **Orchestrator**: Coordinates pure and I/O functions, usually an entry point
- **Violation**: Mixes data transformation AND I/O in the same function

For violations, identify what pure logic could be extracted and suggest a function name.

Grade each file: **Good** (clean separation), **Mixed** (1-2 violations), **Poor** (significant mixing).

### 5. Coverage Data Analysis (only if `{{INCLUDE_COVERAGE}}` is `true`)

Coverage data is provided below as `{{COVERAGE_DATA}}`. Use it as ground truth:

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
    "_comment": "Only included when INCLUDE_DESIGN is true",
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
    "_comment": "Only included when INCLUDE_COVERAGE is true",
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

## Grading Criteria

**Any HIGH-severity issue caps the grade at B or below.**

- **A**: 90%+ pure/integration tests, <10% mocked, 90%+ negative coverage, 80%+ edge case coverage, zero HIGH issues, RITE all "pass"
- **B**: 70%+ pure/integration tests, <20% mocked, 70%+ negative coverage, one or few HIGH issues
- **C**: 50%+ pure/integration tests, <40% mocked, multiple HIGH issues
- **D**: <50% pure/integration tests, heavy mocking, many HIGH issues
- **F**: Mostly mocked tests, tests implementation not behavior, many violations

## Confidence Reporting

Every finding must include a confidence level:
- `"verified"` — directly observed in code with exact line reference
- `"inferred"` — concluded from patterns (explain reasoning)
- `"uncertain"` — could not determine (include `"uncertainReason"`)

Never fabricate line numbers. If uncertain, add `"lineApproximate": true`.

## Files to Analyze

### Test Files
{{TEST_FILES}}

### Source Files
{{SOURCE_FILES}}

### Coverage Data (if available)
{{COVERAGE_DATA}}
