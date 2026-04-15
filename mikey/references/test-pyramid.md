# Test Pyramid — Where Does This Test Belong?

This document defines the test pyramid: four layers of functional tests, each with distinct scope, cost, and purpose. It answers the question "which layer should this test live at?" and provides decision criteria for placing tests correctly.

**Scope**: This pyramid covers **functional correctness testing only**. Other types of testing — security, accessibility, load, and performance — are outside the scope of this document and have their own strategies.

## The Pyramid Shape

The pyramid shape conveys the relative number, speed, and cost of tests at each layer:

```
        /\
       /  \        Fewer tests, slower, more coverage per test,
      / E2E\       closer to user experience, more expensive
     /------\
    /Contract\
   /----------\
  / Interface  \   <-- The sweet spot: high value, reasonable cost
 /--------------\
/     Unit       \  Many tests, fast, cheap, close to code
/________________\
```

- **Bottom (Unit)**: Many tests. Fast, cheap, low maintenance, close to the code.
- **Middle (Interface)**: The sweet spot. Tests behavior through the public entry point of a single service. High confidence per test at reasonable cost.
- **Upper-middle (Contract)**: Validates data formats between components. Essential in service-oriented architectures.
- **Top (E2E)**: Few tests. Slow, expensive, highest confidence. Exercises multiple services with real infrastructure.

> "... to evaluate any testing strategy, you cannot just evaluate how it finds bugs. You also must evaluate how it enables developers to fix (and even prevent) bugs."
> — Mike Wacker, Google Testing Blog

## Layer Definitions

### Unit Layer

**Tests specific implementations of business logic or code. The most stable and fastest of all tests.**

Unit tests are the backbone of the pyramid. They validate pure functions — parsing, validation, transformation, calculation, decision-making — in isolation, with no I/O and no mocks needed.

Because they are cheap to execute and maintain, they should be written liberally during development. However, high unit test coverage does not remove the need for interface or contract tests — those layers serve purposes that unit tests cannot fulfill.

**When to use**: The behavior is pure logic with no I/O dependencies.

| Attribute | Value |
|-----------|-------|
| Mocks, fakes, stubs | Not needed (code is pure) |
| Network access | No |
| Database | No |
| File system access | No |
| More than one service | No |

### Interface Layer

**Tests a single application, service, or library through its public entry point. The sweet spot of the pyramid.**

Interface tests exercise the system the same way a real user or consumer would — through the UI, API, or CLI — but within the scope of a **single service**. External service dependencies are mocked; internal dependencies are real.

> **Why "interface" not "integration"?** The term "integration test" is ambiguous — it can mean anything from two-function composition to a full system test. "Interface test" is precise: test through the public interface of a single service, with external services mocked and internal dependencies real.

The scope of interface testing is always the behavior of a single application, service, or shared library. By limiting scope to a single service, it is possible to thoroughly acceptance-test the encapsulated behavior while maintaining tests that execute faster than E2E equivalents.

**When to use**: The behavior involves I/O or exercises a user-facing entry point. **This is the default for any scenario with user-facing behavior.**

| Attribute | Value |
|-----------|-------|
| Mocks, fakes, stubs | Allowed (for external service dependencies) |
| Network access | Localhost only |
| Database | Yes |
| File system access | Yes |
| More than one service | No |

#### Interface Test Subtypes

**UI interface tests** exercise a web application or graphical interface as a user would. They can use front-end testing technologies and leverage many of the same patterns that unit tests use to seed data or mock/stub/fake external interactions. UI interface tests can use the UI to submit test input, to validate test output, or both.

**API interface tests** are similar to UI interface tests, except they use only an HTTP or other API interface rather than a visual UI. For applications or services without a visual UI, these are the only type of interface tests possible. For applications with a UI, API tests are an effective supplement — validating business logic and behavior with greater speed and reliability than UI-driven interface tests.

### Contract Layer

**Validates interactions between two applications. Critical for ensuring stability between services.**

Every interaction between two services has a format and data type(s). An HTTP request and response involves JSON and a data type (string, integer, float, etc.) for each attribute. That schema constitutes the contract. Other intra-service technologies with contracts include message queues, gRPC, and GraphQL. No matter the technology or protocol, the need to protect the contract from unintentional changes remains.

Contract tests provide limited functional coverage but are critical to ensuring stability between applications. Their absence can be mitigated with heavier E2E testing — but contract tests are cheaper, faster, and more reliable.

There are two approaches to contract testing:

1. **Spin up both services**, perform the interaction, verify the result. Slow, high coupling, high maintenance.
2. **Consumer-Driven Contracts (CDC)**: Generate and publish a contract in the consumer's CI build. Fetch and verify it in the provider's CI build. Fast, decoupled, low maintenance. **Preferred.**

Published API documentation such as Swagger/OpenAPI is the most limited form of contract exposure — allowing a consumer to auto-generate tests against the provider's most recent published specification. This notifies about broken contracts but does not prevent them.

**When to use**: The behavior validates a shared data format between components (JSON schemas, API specs, message queue payloads).

| Attribute | Value |
|-----------|-------|
| Mocks, fakes, stubs | Everything outside the service being tested |
| Network access | Localhost only |
| Database | Yes |
| File system access | Yes |
| More than one service | No |

### E2E Layer

**Exercises most or all of the services in an application. Almost all applications should have some form of E2E testing.**

E2E tests exercise the entire application, especially tests that involve multiple services. They use real infrastructure — load balancers, networks, message queues, storage, cache — and provide confidence that the system works end-to-end after a deployment.

The primary purpose of E2E testing is to cover system requirements that aren't being tested at lower layers of the pyramid and to provide confidence after code deploys. **The key principle: every E2E test can be broken down into smaller tests at lower layers of the pyramid.** If a requirement can be tested at a lower level, it should be — it will run faster, cost less to maintain, and perform more reliably.

> High-level tests are there as a second line of test defense. If you get a failure in a high level test, not just do you have a bug in your functional code, you also have a missing or incorrect lower-level test. Thus before fixing a bug exposed by a high level test, you should replicate the bug with a lower-level test. Then the lower-level test ensures the bug stays dead.
> — Martin Fowler, The Test Pyramid

**When to use**: The behavior requires real external service behavior that mocks cannot replicate — stateful round-trips, auth token exchanges, redirects, cross-service workflows.

| Attribute | Value |
|-----------|-------|
| Mocks, fakes, stubs | No |
| Network access | Yes |
| Database | Yes |
| File system access | Yes |
| More than one service | Yes |

## Layer Attributes Summary

|  | Unit | Interface | Contract | E2E |
|--|------|-----------|----------|-----|
| **Mocks, fakes, stubs** | Not needed | Allowed (externals) | Everything outside service | No |
| **Network access** | No | Localhost only | Localhost only | Yes |
| **Database** | No | Yes | Yes | Yes |
| **File system access** | No | Yes | Yes | Yes |
| **More than one service** | No | No | No | Yes |

## Layer Decision Criteria

Use this decision tree to determine the correct layer for a test:

1. **Is the behavior pure logic with no I/O?** (parsing, validation, transformation, calculation)
   - Yes → **Unit test**. No mocks needed.

2. **Does the behavior exercise a user-facing entry point or involve I/O within a single service?** (CLI command, HTTP route, API endpoint, file operations)
   - Yes → **Interface test**. Mock external services, keep internal dependencies real.

3. **Does the behavior validate a shared data format between two services?** (JSON schema conformance, API contract, message queue payload structure)
   - Yes → **Contract test**. Use CDC if possible.

4. **Does the behavior require real external service behavior that mocks cannot replicate?** (stateful round-trips, auth token exchange, cross-service workflows, redirect chains)
   - Yes → **E2E test**.

**When in doubt, default to interface test.** It is the sweet spot — high confidence, reasonable cost.

## Dependency Decision Tree

When a test encounters an external dependency, the handling depends on the test layer:

### Database

| Layer | Handling |
|-------|----------|
| Unit | No database. Extract pure logic that operates on data, not database queries. |
| Interface | Use a real local database. Seed test data, exercise the entry point, verify results. |
| Contract | Use a real local database if the contract involves database-mediated interactions. |
| E2E | Real database — production-like configuration. |

### HTTP / External API

| Layer | Handling |
|-------|----------|
| Unit | No HTTP. Extract the logic that processes the response into a pure function. |
| Interface | Mock/stub the external HTTP dependency. Use canned JSON responses or fixture-based stubs. Let contract tests cover the interaction format. |
| Contract | Generate or fetch a contract (e.g., via CDC). Verify the service produces/consumes the expected format. |
| E2E | Real HTTP to real services. |

### File System

| Layer | Handling |
|-------|----------|
| Unit | No filesystem. Extract pure logic that operates on data after reading. |
| Interface | Use real filesystem operations (temp directories, fixtures). |
| Contract | N/A (filesystem interactions are rarely contracts between services). |
| E2E | Real filesystem. |

### Message Queues / Events

| Layer | Handling |
|-------|----------|
| Unit | No queues. Extract pure logic that processes the message payload. |
| Interface | Publish/consume on a local queue or use an in-memory fake. |
| Contract | Validate message schema conformance against a shared spec. |
| E2E | Real message infrastructure. |

### System Clock / Time

| Layer | Handling |
|-------|----------|
| Unit | Pass time as a parameter to pure functions. |
| Interface | Mock the system clock. |
| Contract | N/A. |
| E2E | Real system clock. |

## The Push-Down Principle

When a higher-layer test catches a bug, **replicate it at the lowest possible layer first** — provided doing so does not sacrifice the principles and boundaries defined in this document.

- A bug in pure logic caught by an interface test → write a unit test for the pure function, then fix it.
- A bug in wiring caught by an E2E test → write an interface test through the entry point, then fix it.
- A bug in cross-service interaction caught by E2E → write a contract test if the issue is data format, or keep the E2E test if it requires real multi-service behavior.

The lower-level test runs faster, is cheaper to maintain, and ensures the bug stays dead. The higher-level test that originally caught it may become redundant — or it may still provide value as a second line of defense.

**Do not push down when doing so would violate layer boundaries.** If the behavior genuinely requires real external services, keep the E2E test. If the behavior is about wiring and orchestration through a public entry point, keep the interface test. The goal is to test at the right layer, not the lowest layer.

## Common Symptoms of Poor Test Architecture

- Long CI builds
- Unreliable/flaky test suites
- Frequent maintenance of brittle tests
- Heavy refactoring of tests when refactoring application code
- Changes in other applications break your CI builds or product
- Important bugs surface in production despite high code coverage
- Difficult or painful test suite dependency upgrades

A well-balanced test portfolio — where every pyramid layer serves a specific purpose and is adequately represented — addresses all of these symptoms.

## Further Reading

- [The Test Pyramid — Martin Fowler](https://martinfowler.com/bliki/TestPyramid.html)
- [The Practical Test Pyramid — Martin Fowler](https://martinfowler.com/articles/practical-test-pyramid.html)
- [Testing Strategies in a Microservice Architecture — Toby Clemson](https://martinfowler.com/articles/microservice-testing/)
- [Write Tests — Kent C. Dodds](https://kentcdodds.com/blog/write-tests)
- [Unit vs Integration vs E2E Tests — Kent C. Dodds](https://kentcdodds.com/blog/unit-vs-integration-vs-e2e-tests)
- [Just Say No to More End-to-End Tests — Google Testing Blog](https://testing.googleblog.com/2015/04/just-say-no-to-more-end-to-end-tests.html)
