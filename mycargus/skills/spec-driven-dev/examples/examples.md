# spec-driven-dev — Example Workflows

## Example Spec File

```markdown
# Shopping Cart

## Add item to cart
- Given an empty cart
- When the user adds a product with name "Widget" and price 9.99
- Then the cart contains 1 item
- And the cart total is 9.99

## Add duplicate item
- Given a cart with 1 "Widget" at 9.99
- When the user adds another "Widget" at 9.99
- Then the cart contains 2 items
- And the cart total is 19.98

## Remove item from cart
- Given a cart with 2 items
- When the user removes one item
- Then the cart contains 1 item

## Empty cart checkout
- Given an empty cart
- When the user tries to checkout
- Then checkout fails with "Cart is empty"
```

## Example: Agent Mode Output

```
Parsed 4 scenarios from specs/shopping-cart.md:

  1. Add item to cart
  2. Add duplicate item
  3. Remove item from cart
  4. Empty cart checkout

Detected: Node.js project (package.json), test runner: vitest
Test location: src/__tests__/cart.test.ts
Source location: src/cart.ts

Starting TDD loop...

━━━ Scenario 1/4: Add item to cart ━━━

🔴 RED — Writing failing test...

  ✎ Created src/__tests__/cart.test.ts
    test: "Given an empty cart, when adding a product, should contain 1 item with correct total"

  ▶ Running tests... FAIL (expected — test references Cart which doesn't exist yet)

🟢 GREEN — Writing minimal implementation...

  ✎ Created src/cart.ts
    - Cart class with addItem() method
    - items getter, total getter

  ▶ Running tests... PASS ✓

🔁 REFACTOR — Reviewing...

  ✓ Pure logic (no I/O) — no refactoring needed

━━━ Scenario 2/4: Add duplicate item ━━━

🔴 RED — Writing failing test...

  ✎ Updated src/__tests__/cart.test.ts
    test: "Given a cart with 1 Widget, when adding another Widget, should contain 2 items with combined total"

  ▶ Running tests... FAIL (cart allows add but doesn't accumulate correctly)

🟢 GREEN — Writing minimal implementation...

  ✎ Updated src/cart.ts — fixed addItem to handle duplicates

  ▶ Running tests... PASS ✓ (2/2 tests passing)

🔁 REFACTOR — Reviewing...

  ✓ Clean — no refactoring needed

━━━ Scenario 3/4: Remove item from cart ━━━

🔴 RED — Writing failing test...

  ✎ Updated src/__tests__/cart.test.ts
    test: "Given a cart with 2 items, when removing one, should contain 1 item"

  ▶ Running tests... FAIL (removeItem not implemented)

🟢 GREEN — Writing minimal implementation...

  ✎ Updated src/cart.ts — added removeItem()

  ▶ Running tests... PASS ✓ (3/3 tests passing)

🔁 REFACTOR — Reviewing...

  ✓ Clean — all logic is pure, no I/O

━━━ Scenario 4/4: Empty cart checkout ━━━

🔴 RED — Writing failing test...

  ✎ Updated src/__tests__/cart.test.ts
    test: "Given an empty cart, when checking out, should throw 'Cart is empty'"

  ▶ Running tests... FAIL (checkout not implemented)

🟢 GREEN — Writing minimal implementation...

  ✎ Updated src/cart.ts — added checkout() with empty guard

  ▶ Running tests... PASS ✓ (4/4 tests passing)

🔁 REFACTOR — Reviewing...

  ✓ checkout() mixes validation (pure) with payment processing (I/O)
  ✎ Extracted validateCheckout() as pure function
  ▶ Running tests... PASS ✓ (4/4 tests passing)

━━━ Complete ━━━

All 4 scenarios implemented. 4/4 tests passing.

Running /mycargus:testify for verification...
[testify output would appear here]
```

## Example: Interactive Mode

```
No spec file provided — entering interactive TDD mode.

Describe a behavior using Given/When/Then
(or just describe what you want the code to do):

> Given a list of users, when filtering by active status, then only active users are returned

━━━ TDD: Filter active users ━━━

🔴 RED — Writing failing test...

  ✎ Created src/__tests__/user-filter.test.ts
    test: "Given a list of mixed users, when filtering by active, should return only active users"

  Does this test look right? [Y/n]

> y

  ▶ Running tests... FAIL ✓ (expected)

🟢 GREEN — Writing minimal implementation...

  ✎ Created src/user-filter.ts
    - filterActiveUsers(users) — pure function

  ▶ Running tests... PASS ✓

🔁 REFACTOR — No changes needed (already pure)

Next behavior? (or "done" to finish):

> done

Session complete. 1 scenario implemented, 1/1 tests passing.

Note: testify skill not found. Verify the mycargus plugin is fully installed for automatic test quality verification.
```
