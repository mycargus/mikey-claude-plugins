# Report Template

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
- Interface: {count}

### Anti-Patterns Found
{Prioritized list with severity, file, line, issue, suggestion, confidence}

## RITE Evaluation
| Test File | Readable | Isolated | Thorough | Explicit |
|-----------|----------|----------|----------|----------|

## Mock Analysis
| Test File | Mock Count | Assertion Count | Ratio | Assessment |
|-----------|------------|-----------------|-------|------------|

## Test Layer Placement

### Layer Misplacements
| Test File:Line | Current Layer | Recommended Layer | Reason | Severity |
|----------------|---------------|-------------------|--------|----------|

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
