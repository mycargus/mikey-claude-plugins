# Spec Format Reference

## Given/When/Then Structure

Specs describe user scenarios using the Given/When/Then pattern:

- **Given**: The precondition or initial state
- **When**: The action or event
- **Then**: The expected outcome (observable behavior)

## Accepted Formats

The spec-driven-dev skill accepts any text format containing Given/When/Then patterns. It does not enforce strict Gherkin syntax.

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

## Parsing Rules

1. Look for lines starting with `Given`, `When`, `Then`, `And`, `But` (case-insensitive)
2. `And`/`But` lines continue the previous Given/When/Then clause
3. Group into scenarios by:
   - Explicit `Scenario:` or `##` headers
   - Blank-line separation between Given/When/Then groups
4. Extract `Feature:` or `#` headers as the feature name
5. If no explicit scenario grouping, treat each Given/When/Then triplet as a scenario

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
