# Spec Format Reference

## Given/When/Then Structure

Specs describe user scenarios using the Given/When/Then pattern:

- **Given**: The precondition or initial state
- **When**: The action or event
- **Then**: The expected outcome (observable behavior)

## Accepted Formats

The tdd skill accepts any text format containing Given/When/Then patterns. It does not enforce strict Gherkin syntax.

### Gherkin (.feature files)

```gherkin
Feature: User Registration

  Scenario: Successful registration
    Given a valid email "user@example.com"
    And a password "securePass123"
    When the user submits the registration form
    Then the account is created
    And a confirmation email is sent

  Scenario: Duplicate email
    Given an existing account with email "user@example.com"
    When a new user tries to register with "user@example.com"
    Then registration fails with "email already taken"
```

### Markdown

```markdown
# User Registration

## Successful registration
- Given a valid email and password
- When the user submits the registration form
- Then the account is created and a confirmation email is sent

## Duplicate email
- Given an existing account with email "user@example.com"
- When a new user tries to register with "user@example.com"
- Then registration fails with "email already taken"
```

### Plain Text

```
User Registration

Scenario: Successful registration
Given a valid email and password
When the user submits the registration form
Then the account is created and a confirmation email is sent

Scenario: Duplicate email
Given an existing account with email "user@example.com"
When a new user tries to register with "user@example.com"
Then registration fails with "email already taken"
```

### User-scenarios docs (`/mikey:user-scenarios`)

A scenario is a `###` heading (its text is the scenario name, often an id such as `CART-003`), a `**Risk:**` paragraph, and a blockquote of bold keywords. `##` headings are groups of scenarios.

```markdown
## Starting a chunk

### CART-001

**Risk:** If removing an item leaves a stale total, customers are charged for
goods they no longer want.

> **Given** a cart with three items
> **When** the user removes one item
> **Then** the cart shows two items
> **And** the total excludes the removed item
```

A continuation line of a clause starts with `>` and indentation instead of a keyword; it belongs to the clause above it.

## Parsing Rules

1. Look for lines starting with `Given`, `When`, `Then`, `And`, `But` (case-insensitive)
2. `And`/`But` lines continue the previous Given/When/Then clause
3. Group into scenarios by:
   - Explicit `Scenario:` or `##` headers
   - Blank-line separation between Given/When/Then groups
4. Extract `Feature:` or `#` headers as the feature name
5. If no explicit scenario grouping, treat each Given/When/Then triplet as a scenario
6. **User-scenarios format.** A file with `###` headings that are followed by Given/When/Then blockquotes uses this reading, where `##` means a group and `###` means a scenario (not the single-level `##` scenario headers of the plain Markdown format above):
   - Strip the leading `>` and the `**` around the keyword, so `> **Given** x` reads as `Given x`. Remove nothing else: the clause text reaches the tdd-agent unchanged. `**And**` continues the clause before it.
   - The `###` heading text is the scenario name.
   - Sections with no Given/When/Then lines (`## Decided, no scenario needed`, `## Parked`, intro prose) contain no scenarios and are skipped.
7. **Risk paragraph.** A `**Risk:**` paragraph (from the `**Risk:**` marker to the next blank line or the blockquote) belongs to the scenario that follows it. Keep it with that scenario and pass it to the tdd-agent verbatim as the reason the scenario matters. Never drop it, and never fold it into the Given/When/Then text.
8. **`--group "<heading>"`.** Keep only the scenarios between the matching `##` heading and the next `##` heading (or the end of the file). The match ignores surrounding whitespace and letter case. If no `##` heading matches, or the matched heading has no scenarios (a matched heading with no scenarios counts as missing), stop and list the `##` headings that contain scenarios.

## Writing Good Specs

**Focus on observable behavior**, not implementation:

```
# GOOD: Describes what the user sees
Given a shopping cart with 3 items
When the user removes an item
Then the cart shows 2 items

# BAD: Describes implementation
Given items are stored in an array
When splice is called with index 1
Then the array length is 2
```

**Include error scenarios**:

```
Given an empty shopping cart
When the user tries to checkout
Then an error is shown: "Cart is empty"
```

**Include edge cases**:

```
Given a cart with the maximum allowed items (99)
When the user tries to add another item
Then an error is shown: "Cart is full"
```
