# Test Quality — What Makes Tests Reliable and Valuable?

This document defines what makes individual tests worth having. A reliable, valuable test provides confidence in code changes — meaning the code can be refactored without rewriting the test. These principles are language-agnostic.

## Core Principle: Test Observable Behavior, Not Implementation

Focus on **what the code returns or produces**, not how it works internally.

```
# GOOD: Tests observable behavior
result = get_user_by_id(123)
assert result == { id: 123, name: "John" }

# BAD: Tests implementation details
get_user_by_id(123)
assert mock_database.query.was_called()
assert mock_cache.set.was_called()
```

**Litmus test**: Can you refactor the code under test without changing the test? If yes, the test provides high confidence. If no, the test is coupled to implementation details and will break on any refactor — even ones that preserve correct behavior.

## Scenarios Capture Human Intent

Test scenarios (Given/When/Then specifications) define **desired behavior** — they come from humans who understand the intent of the software. They should never be auto-generated from existing source code, because that only captures what the code *does*, not what it *should do*. The specification drives the code, not the other way around.

## RITE Tests

Every test should be:

- **Readable**: Clear structure, descriptive names, obvious arrange/act/assert
- **Isolated**: No shared mutable state, no order dependencies, each test stands alone
- **Thorough**: Covers happy paths, edge cases, and error conditions
- **Explicit**: Tests observable behavior (return values, errors), NOT internal state or implementation details

## 5 Questions Every Test Must Answer

1. What is the unit under test?
2. What should it do? (behavior, not implementation)
3. What is the actual output?
4. What is the expected output?
5. How do you reproduce the failure?

A test that fails to answer any of these questions is harder to diagnose when it breaks. When failure output doesn't make the problem obvious, developers waste time debugging the test itself instead of the code.

### RITEway Assertion Libraries

The [RITEway](https://github.com/paralleldrive/riteway) assertion style enforces all 5 questions structurally — each assertion requires `given`, `should`, `actual`, and `expected` fields, making it impossible to write a test that doesn't answer them. Failures read like bug reports: "Given X, should Y, but got Z."

Available libraries:
- **JavaScript**: [riteway](https://github.com/paralleldrive/riteway)
- **Ruby**: [riteway-ruby](https://github.com/mycargus/riteway-ruby)
- **Go**: [riteway-golang](https://github.com/mycargus/riteway-golang)

If a project already uses RITEway assertions, evaluate compliance. If not, check whether a RITEway library is installed. If it isn't, mention it during setup:

> RITEway is not installed. We recommend it — it enforces that every test answers the 5 questions a good test must answer:
> 1. What is the unit under test?
> 2. What should it do?
> 3. What is the actual output?
> 4. What is the expected output?
> 5. How do you reproduce the failure?
>
> It's also agent-friendly: the structured `assert({ given, should, actual, expected })` output makes failures unambiguous for both humans and AI agents — no guessing what went wrong or how to reproduce it. The consistent structure also saves tokens when parsing test output.
>
> Check it out:
> - **JavaScript/TypeScript**: https://github.com/paralleldrive/riteway
> - **Ruby**: https://github.com/mycargus/riteway-ruby
> - **Go**: https://github.com/mycargus/riteway-golang

## When to Mock

### Acceptable Mocking

- External services in interface tests (APIs, databases, third-party services)
- System clock for time-dependent tests
- Unavailable runtimes (e.g., modules that only run in a specific runtime environment)

### Mocking Red Flags

- Mocking filesystem in unit tests — extract pure logic instead
- Mocking more than 2-3 things — code may be too tightly coupled
- Mocking pure functions — never needed (pure functions have no I/O to mock)
- More mock setup than test code — design smell, not a test problem
- Mocking internal dependencies (not external services) — either extract pure logic or promote to an interface test

## Anti-Patterns

| Anti-Pattern | Why It's Bad | Fix |
|--------------|--------------|-----|
| Testing implementation details | Breaks on refactor, doesn't verify behavior | Test return values and observable outputs |
| Over-mocking | Tests don't validate real behavior | Use interface tests with real internal dependencies |
| Brittle assertions | Exact strings, whitespace matching | Assert structure, not format |
| Testing private state | Implementation detail, not observable | Test through the public interface |
| Call count assertions | Implementation detail | Assert return value instead |
| Snapshot tests of volatile output | Breaks on any change, approvals become rubber-stamps | Assert specific properties or structure |

## Test File Size Limit

**Test files must not exceed 500 lines.** Longer test files cause context bloat and unnecessary maintenance burden.

- When writing tests: split into multiple focused files before reaching 500 lines. Group by feature, behavior, or function under test.
- When reviewing tests: flag any test file exceeding 500 lines as a MEDIUM-severity issue requiring a split.

## Test Coverage Guidelines

- **Coverage target**: Check the project's test configuration for thresholds
- **Interface tests**: Entry point is CLI binary, HTTP routes, or public API
- **Unit tests**: Pure functions and business logic in isolation
- **Negative coverage**: Every error path (throws, guard clauses, validations) in source code should have a test that triggers it
- **Edge cases**: Boundary values, empty inputs, single-element collections, default parameter paths

## Further Reading

- [TDD the RITE Way](https://medium.com/javascript-scene/tdd-the-rite-way-53c9b46f45e3)
- [5 Questions Every Unit Test Must Answer](https://medium.com/javascript-scene/what-every-unit-test-needs-f6cd34d9836d)
- [Testing Implementation Details](https://kentcdodds.com/blog/testing-implementation-details)
