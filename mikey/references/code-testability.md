# Code Testability — What Makes Code Testable?

This document defines how to structure code so that it is easy to test. It is language-agnostic and applies to any codebase.

## Functional Core / Imperative Shell

The single most important design principle for testability is **separating pure logic from I/O**. This separation creates code that is naturally testable without mocks.

| Layer | Description | Characteristics |
|-------|-------------|-----------------|
| **Pure Core** | Data transformation, validation, decision-making | No I/O, deterministic, returns data based solely on inputs |
| **I/O Shell** | File reads, console output, network calls, database access | Has side effects, coordinates with external resources |
| **Orchestrator** | Coordinates pure and I/O functions | Usually an entry point (main, command handler, request handler) |

### Example (pseudocode)

```
# BAD: I/O mixed with logic — hard to test without mocking
function process_file(path):
    data = read_file(path)           # I/O
    parsed = parse(data)             # Pure
    filtered = filter_active(parsed) # Pure
    print("Found " + len(filtered))  # I/O
    return filtered

# GOOD: Separated — pure logic is trivially testable
function filter_active(items):       # Pure - easy to test
    return [x for x in items if x.active]

function process_file(path):         # I/O shell - test via interface
    data = read_file(path)
    parsed = parse(data)
    filtered = filter_active(parsed)
    print("Found " + len(filtered))
    return filtered
```

The bad version forces you to mock `read_file` and `print` just to test filtering logic. The good version lets you test `filter_active` directly with plain data — no mocks needed.

## Identifying Function Types

### Pure Core (unit testable without mocks)

A function is pure if **all** of these are true:

- No file, network, database, or console I/O
- No mutations of external state
- Returns data based solely on inputs
- Deterministic (same input produces same output every time)

Examples: parsers, validators, transformers, calculators, formatters, reducers.

### I/O Shell (testable via interface tests)

A function is I/O if **any** of these are true:

- Reads from or writes to external systems (files, network, database, stdout)
- Has side effects visible outside the function
- Coordinates with external resources (subprocess execution, timers)

Examples: file readers, HTTP clients, database queries, CLI output writers.

### Orchestrators (testable via interface tests through entry point)

An orchestrator:

- Calls both pure and I/O functions
- Usually serves as an entry point (main, command handler, request handler, route handler)
- Wires together the pure core and I/O shell

Examples: CLI command handlers, HTTP route handlers, message queue consumers, scheduled job runners.

### Violations

A function is a **violation** if it mixes data transformation AND I/O in the same function body. The fix is always the same: extract the pure logic into a separate function.

**How to spot violations:**
- The function reads/writes external systems AND contains branching logic, loops, or data transformations
- You cannot test the logic without mocking the I/O
- The function does more than one conceptual thing

**How to fix violations:**
1. Identify the pure logic (filtering, mapping, validating, calculating)
2. Extract it into a named pure function with clear inputs and outputs
3. Leave the original function as a thin I/O shell that calls the pure function

## Design Principles

1. **Push logic down, push I/O up.** Pure functions should be at the bottom of the call stack, orchestrators at the top.
2. **Thin shells.** I/O functions should do as little as possible — read data, call a pure function, write the result.
3. **No logic in I/O.** If you find an `if` statement in an I/O function, ask whether the condition could be evaluated by a pure function instead.
4. **Prefer data over side effects.** Return data from functions instead of performing side effects. Let the caller decide what to do with the result.
5. **Explicit dependencies.** Pass I/O dependencies as parameters rather than importing and calling them directly. This makes the dependency visible and replaceable.

## Further Reading

- [Functional Core, Imperative Shell](https://www.destroyallsoftware.com/screencasts/catalog/functional-core-imperative-shell)
- [Mocking is a Code Smell](https://medium.com/javascript-scene/mocking-is-a-code-smell-944a70c90a6a)
