---
name: mikey:comment-review
description: >-
  This skill should be used whenever code comments are being written, reviewed, or edited.
  Trigger it before adding a comment to a diff, and when the user asks to "review the comments",
  "clean up the comments", "tighten these comments", "too many comments", "is this comment
  necessary", or mentions comment style, over-commenting, or comments that read like a changelog.
  Also trigger when a comment asserts how a tool, flag, or API behaves, since such claims must be
  verified or flagged. Applies the maintainer's standard: a comment explains WHY, concisely, to a
  new maintainer reading the code as it is now, never its history, never what it does. Pass
  --apply to classify and edit without waiting for approval (used by /mikey:build).
argument-hint: "[--apply] [path | commit range]"
user-invocable: true
---

# Comment Review

A comment exists to explain **why** the code is the way it is, to a new maintainer reading it
**as it is now**.

| Parameter | Description |
|-----------|-------------|
| `path` or commit range | Scope to review. Default: the current diff |
| `--apply` | Classify and apply the edits without the propose-and-wait step. Claims that can't be verified are left untouched and reported |

## The standard

1. **WHY only, and only when necessary.** The decision, the constraint, the invariant that must
   hold, the API quirk that is not visible in the code.
2. **No history.** Git holds the history. Ban "used to", "previously", "formerly", "now also",
   "was changed to", "this fixes", and dates or ticket numbers used as narrative. History explains a
   version of the code the reader will never see; it belongs in the commit message, addressed to
   someone evaluating a *change*.
3. **No what, in production code, never.** Not merely redundant: a WHAT-comment is a liability.
   Code and comment diverge, and the stale comment is the one believed. **Tests protect behavior;
   comments do not**, so a WHAT-comment is an unverifiable claim nothing keeps honest, where a WHY
   records a decision that does not rot when the implementation around it changes. Never paraphrase
   the line below. (Test bodies may say what a scenario exercises; that is the test's contract.)
4. **Concise.** The fewest words that carry the constraint.

Forward-looking warnings are wanted: "without this, `PROJECT_UPLOAD_EXCLUDES` is unset and the
guard sizes the whole tree" tells a maintainer what breaks if they change it, which is about the
code today.

Keep the substance, drop the narrative. Example:

- rejected: "Sets an array rather than echoing a string: the caller used to word-split an unquoted
  substitution, which drops names containing whitespace."
- accepted: "Sets an array so the caller can expand it quoted as `\"${UPL_TAR_EXCLUDES[@]}\"`.
  Exclude names containing whitespace survive that; word-splitting an unquoted string does not."

Other rejected phrasings: "the caller *used to*"; "which *used to be*"; "They *used to carry*", etc.

## Procedure

### 1. Establish scope

Default to the current diff (`git diff`, plus `git diff --cached` and untracked files). If the user
names a path, file, or commit range, use that instead. Comments in code the user is not touching are
**out of scope** unless named. Say so rather than widening silently.

### 2. Re-read the files

Read the target files immediately before proposing anything. The maintainer edits his own comments
down before review; a remembered version is stale.

### 3. Classify every comment before changing anything

| Verdict | When |
|---|---|
| **keep** | Carries a WHY, an invariant, or a non-obvious constraint, and is already tight. Default verdict. |
| **trim** | Right content, too many words. Cut words only; do not re-argue the point. |
| **drop-history** | Contains archaeology. Restate the same constraint in present tense. |
| **drop-what** | Paraphrases the code. Delete, or replace with the WHY if one exists and is non-obvious. |
| **verify** | Asserts how a tool, flag, or API behaves. See step 4. |
| **delete** | Content is now false, redundant with a named symbol, or was only ever restating the code. |

Report a verdict for each comment in scope, including the `keep`s. The count of untouched comments
is what shows the pass was conservative.

### 4. Treat factual claims as suspect

A comment that makes a factual claim about external behaviour is a liability unless the claim was
verified. Either verify it (run it, measure it, read the tool's docs or source) or flag it to the
user. Never silently soften or delete it: a hedged claim reads as verified to the next maintainer.

### 5. Propose, then apply

Show the classification and every proposed before/after before touching a file, and wait for
agreement. Comments are the maintainer's own voice; the point is a shorter diff he recognises, not a
rewrite he has to review from scratch.

#### With `--apply`

Skip the wait. Steps 1 to 4 run as written, then:

- Apply every `trim`, `drop-history`, `drop-what` and `delete` edit. Leave every `keep` alone.
- For a `verify` comment, try to confirm the claim (run it, read the docs or source). If you
  confirm it, classify the comment by the other verdicts and edit accordingly. If you can't
  confirm it, leave the comment exactly as written and list it in the report.
- Edit only comments on lines the scope's diff adds or changes. Comments elsewhere in the same file
  stay as they are.
- Finish with a report: the count of each verdict, each edit as a before/after pair with
  `file:line`, and a separate list of unverified claims, each quoted as written with `file:line`
  and what you tried. Propose code deletion (see Guardrails) in the report only; never make it.
- Run the project's test command if the caller gave you one, and report the result.

## Guardrails

- **Bias to keep.** Deleting a comment that carried a real invariant is a worse outcome than leaving
  a verbose one. When unsure whether a comment encodes a constraint, keep it and say why it was kept.
- **Not a licence for a sweep.** Some codebases are deliberately, heavily commented with invariants
  and non-obvious constraints, and that is wanted. Never propose a wholesale comment rewrite.
- **Comment-only edits.** Preserve behaviour. Do not reformat, rename, or refactor in the same pass.
- **One exception, raised separately:** when a comment exists to explain code that should not exist
  at all, propose deleting the *code*, as its own clearly-labelled change, not folded into the comment pass.
