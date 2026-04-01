# Test Philosophy - Embedded Reference

This document contains the complete test philosophy used by the testify skill. These principles are language-agnostic.

## Goal: Confidence in Code Changes

Tests that provide high confidence allow refactoring without fear—and without rewriting tests.

## Core Principles

### 1. Test Observable Behavior, Not Implementation

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

### 2. Prefer Integration Tests

- Test the system as users interact with it
- Catch issues unit tests miss
- Resistant to refactoring
- Provide higher confidence per test

**Test pyramid**:
- **Many integration tests**: CLI commands, public API entry points
- **Some unit tests**: Pure functions, utilities, data transformations
- **Few mocks**: Only for external dependencies (unavailable runtimes, external APIs)

### 3. Don't Unit Test I/O

I/O operations should be tested via integration tests:
- **Unit tests**: Pure functions, business logic, calculations
- **Integration tests**: CLI commands, file operations, API calls

If mocking I/O in unit tests → extract pure logic OR write integration test instead.

### 4. Separate Logic from I/O (Functional Core / Imperative Shell)

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

## Anti-Patterns

| Anti-Pattern | Why It's Bad | Fix |
|--------------|--------------|-----|
| Testing implementation details | Breaks on refactor | Test outputs, not internals |
| Over-mocking | Tests don't validate real behavior | Use integration tests |
| Brittle assertions | Exact strings, whitespace | Assert structure, not format |
| I/O in unit tests | Couples to filesystem/network | Extract pure logic |
| Testing private state | Implementation detail | Test public interface |
| Call count assertions | Implementation detail | Assert return value |

## Identifying Function Types

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

## When to Mock

### Acceptable Mocking
- External services in integration tests (APIs, databases)
- System clock for time-dependent tests
- Unavailable runtimes (e.g., modules that only run in a specific runtime environment)
- Limit: 2-3 mocks per test maximum

### Mocking Red Flags
- Mocking filesystem in unit tests → extract pure logic instead
- Mocking more than 2-3 things → code may be too tightly coupled
- Mocking pure functions → never needed
- More mock setup than test code → design smell

## Test File Size Limit

**Test files must not exceed 500 lines.** Longer test files cause context bloat and unnecessary maintenance burden.

- When writing tests: split into multiple focused files before reaching 500 lines. Group by feature, behavior, or function under test.
- When reviewing tests: flag any test file exceeding 500 lines as a MEDIUM-severity issue requiring a split.

## Test Coverage Guidelines

- **Coverage target**: Check the project's test configuration for thresholds
- **Integration tests**: Entry point is CLI binary or public API
- **Unit tests**: Pure functions and business logic in isolation

## Further Reading

- [Functional Core, Imperative Shell](https://www.destroyallsoftware.com/screencasts/catalog/functional-core-imperative-shell)
- [Mocking is a Code Smell](https://medium.com/javascript-scene/mocking-is-a-code-smell-944a70c90a6a)
- [TDD the RITE Way](https://medium.com/javascript-scene/tdd-the-rite-way-53c9b46f45e3)
- [5 Questions Every Unit Test Must Answer](https://medium.com/javascript-scene/what-every-unit-test-needs-f6cd34d9836d)
