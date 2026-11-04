---
name: minimal-code
description: Write, modify, refactor, or review code for the smallest correct, readable implementation, without unnecessary abstraction, scaffolding, or defensive complexity.
---

# Minimal Code

Write the smallest clear solution that fully solves the requested problem.

## Priorities

Apply these priorities in order:

1. Correctness.
2. Readability.
3. Simplicity.
4. Brevity.
5. Extensibility only for a concrete current need.

Succinct code is not code golf. Prefer a few obvious lines over one clever line.

## Keep the implementation minimal

Every added behavior, function, class, abstraction, dependency, configuration option, fallback, and error path must justify its existence. Minimize conceptual machinery, not whitespace or useful documentation.

Do not add speculative future-proofing, unused flexibility, compatibility layers, redundant validation, unrequested fallbacks, or abstractions for hypothetical reuse. Avoid helpers that merely rename one or two obvious operations.

Before adding something, ask: "Would the code be less correct or harder to understand without this?" If not, omit it.

Reuse the language, standard library, existing project dependencies, and established project utilities before creating new machinery.

## Abstract only when useful

Raise the level of abstraction only when it reduces real cognitive complexity. An abstraction is justified when it does at least one of the following:

- represents a meaningful domain concept;
- hides genuinely complex implementation details;
- removes meaningful duplication;
- establishes a real boundary or contract;
- follows an established repository pattern in this area.

Do not extract code merely to shorten a function. Keep simple operations at the call site when extraction would make the reader navigate elsewhere to understand them. Make the main control flow easy to follow without repeatedly opening trivial helpers.

## Structure and comments

Match the repository's conventions unless they are clearly harmful. Prefer direct control flow, precise names, cohesive functions, and explicit data flow.

Keep related logic together. Use whitespace and short workflow comments to make the main stages visible. Give scripts, public functions, and substantial helpers well-written headers. Documentation should explain intent and interfaces without narrating every statement.

- Before writing, modifying, or reviewing code, read [formatting and workflow comments](references/readable-code-style.md).
- When creating or modifying a script, function, or other documented entry point, also read [header conventions and examples](references/headers.md).

## Comments and documentation for current users

Describe the current implementation and interface. Comments and user-facing
documentation must be understandable without private conversations,
inaccessible workspaces, removed scripts, or knowledge of earlier versions.

Explain the algorithm or behavior directly. Keep development chronology,
source mappings and comparisons with previous implementations in the
project's designated maintainer material. Preserve scientific references,
attribution and license notices needed to understand or distribute the code.

For exposed settings, document meaning, units, accepted values, defaults,
omission behavior and precedence where applicable. Distinguish numerical
controls from physical requirements.

## Errors and edge cases

Handle errors and edge cases that realistically belong to the requested behavior. Do not add branches for impossible or unsupported states without evidence they matter. Prefer clear failure over silent fallback, and catch an exception only when it can be handled meaningfully.

## Simplify before finishing

Remove unnecessary machinery while preserving useful spacing, comments, documentation, and local variables. Check readability and documentation against the relevant references. Preserve required behavior and repository conventions, then run the relevant checks or tests.

Review comments and documentation semantically, not only through keyword
searches. Read the text as someone who has access only to the distributed
project and its declared dependencies. Verify referenced identifiers,
paths, settings and behavior against the implementation.

Match the review to the requested scope. A repository-wide documentation
audit includes unchanged first-party headers and internal helpers.
Passing tests or finding no prohibited keywords does not complete this review.
