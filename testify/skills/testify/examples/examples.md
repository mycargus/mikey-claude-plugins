# Testify Skill — Example Report

This is a representative example of testify output. Adapt structure and language to match the project being analyzed.

```markdown
# Test Philosophy Alignment Report

## Executive Summary
**Grade: B**

Tests show good integration testing patterns via CLI invocation and real filesystem operations. Main issues: (1) 3 uncovered public API validations in `user_service`, (2) excessive mocking in `auth_handler` tests where pure logic could be extracted.

## Code Design Analysis

### Functional Core / Imperative Shell Separation
**Overall: Mixed**

### Files with Mixed I/O and Logic
| File | Issue | Extractable Pure Logic |
|------|-------|------------------------|
| user_service:45-67 | Validation mixed with file reads | `validate_user_config(config)` |
| auth_handler:23-45 | Token parsing mixed with HTTP calls | `parse_token_claims(raw_token)` |

## Test Pattern Analysis

### Test Distribution
- Total tests: 28
- Unit (pure): 15
- Unit (mocked): 5
- Integration: 8

### Anti-Patterns Found
1. **HIGH** - Implementation testing - `test_auth_handler:67` - Asserts mock HTTP client was called instead of checking return value `(verified)`
2. **MEDIUM** - Over-mocking - `test_user_service:34` - 4 mocks for 2 assertions `(verified)`

## RITE Evaluation
| Test File | Readable | Isolated | Thorough | Explicit |
|-----------|----------|----------|----------|----------|
| test_auth_handler | ✓ | ✓ | ⚠ missing error paths | ⚠ checks mock calls |
| test_user_service | ✓ | ✓ | ✓ | ✓ |

## Mock Analysis
| Test File | Mock Count | Assertion Count | Ratio | Assessment |
|-----------|------------|-----------------|-------|------------|
| test_auth_handler | 4 | 2 | 2:1 | ⚠ Over-mocked |
| test_user_service | 1 | 8 | 0.13:1 | ✓ Good |

## Negative Test Coverage
**5/8 validations tested (62%)**

### Uncovered Validations
| Source File:Line | Error/Validation | Severity | Suggested Test |
|------------------|------------------|----------|----------------|
| user_service:52 | Raises ValueError on empty name | HIGH | "should reject empty user name" |
| user_service:58 | Raises ValueError on duplicate email | HIGH | "should reject duplicate email" |
| auth_handler:30 | Returns 401 on expired token | HIGH | "should return 401 for expired token" |

## Edge Case Coverage
**3/6 edge cases tested (50%)**

### Uncovered Edge Cases
| Source File:Line | Boundary | Type | Severity | Suggested Test |
|------------------|----------|------|----------|----------------|
| user_service:70 | Empty user list | empty_collection | HIGH | "should handle empty user list" |
| auth_handler:15 | Token with no claims | boundary_value | MEDIUM | "should handle token with empty claims" |

## Recommendations

### Code Design Improvements
1. Extract `validate_user_config()` from `user_service:45` — removes 3 mocks from tests
2. Extract `parse_token_claims()` from `auth_handler:23` — enables pure unit testing

### Test Improvements
1. HIGH - Add negative tests for 3 uncovered public API validations
2. HIGH - Replace mock-call assertions in `test_auth_handler:67` with return value checks
3. MEDIUM - Add edge case tests for empty collections and boundary inputs

## Impact
- Files affected: 4
- Lines changed: ~80
- Coverage impact: 62% → ~90% negative coverage
```
