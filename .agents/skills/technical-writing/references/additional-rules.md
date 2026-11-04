# Additional Rules

Read this file in full before drafting or revising. Treat active rules as user-specific instructions that override the default style rules in `SKILL.md`, but never let them override the user's current request or technical truth.

## AR-001 — Verify the active method variant

**Rule**

Before drafting methods or results, resolve the exact implementation used, including active branches, directions, filters, thresholds, timing definitions, and solver policies. Inspect the source or ask when variants remain ambiguous; do not infer them from a related method or figure.

**Applies to**

Scientific methods and results.

**Exceptions**

None identified.

**Reason**

Generic fidelity checks did not prevent plausible but incorrect implementation details.

**Added**

2026-08-21

## AR-002 — Put results before caveats

**Rule**

State the demonstrated result before the qualification needed to interpret it. Do not lead with generic limitations, repeat obvious scope boundaries, or weaken a claim when the evidence and author support stronger wording.

**Applies to**

Results, discussion, and section-closing paragraphs.

**Exceptions**

Lead with a limitation when readers must know it before the result can be understood safely or correctly.

**Reason**

Caveat-first prose hid the finding and sounded more defensive than the evidence required.

**Added**

2026-08-21

## AR-003 — Join related thoughts naturally

**Rule**

When adjacent sentences form one logical step, consider joining them with a simple conjunction or colon. Keep purposeful signposting when it introduces a non-obvious warning that changes interpretation; remove it only when it adds no information.

**Applies to**

Scientific exposition and interpretation.

**Exceptions**

Do not create long sentences with nested clauses or hide distinct claims in one sentence.

**Reason**

Over-segmented prose sounded mechanical, while automatic removal of signposting weakened important interpretation warnings.

**Added**

2026-08-21

## AR-004 — Cite visuals at first use

**Rule**

Cite a figure or table at its first substantive use and state what it contributes there. Keep it close to that discussion when the document format allows.

**Applies to**

Technical manuscripts with figures or tables.

**Exceptions**

Follow mandatory publisher placement rules when they conflict.

**Reason**

Delayed citations separate evidence from the explanation it supports.

**Added**

2026-08-21

## AR-005 — Introduce acronyms only when reused

**Rule**

Spell out every acronym at its first use and give the shortened form in parentheses only when it will be used again. If the term appears only once, use the full term and omit the acronym. Preserve acronyms inside official titles, direct quotations, and source names.

**Applies to**

All authored technical prose, headings, captions, and table text.

**Exceptions**

Standard units, mathematical symbols, and acronyms that form part of an official title, quotation, or source name.

**Reason**

Undefined acronyms make a proposal harder to read, while one-use acronyms add notation without saving space.

**Added**

2026-09-10

## AR-006 — Avoid two disallowed words

**Rule**

Do not use the words "rather" or "genuinely" in authored text. Rewrite the sentence with a direct comparison, use "instead" when it states the intended relationship, or name the precise quality that the intensifier was meant to express.

**Applies to**

All technical-writing outputs.

**Exceptions**

Direct quotations and official titles that must be reproduced exactly.

**Reason**

These words recur as model-writing habits and can usually be replaced by clearer wording.

**Added**

2026-09-10

## AR-007 — Make software documentation self-contained

**Rule**

Write for users of the current software distribution. Describe its current
behavior and supported settings without requiring private conversation
history, inaccessible workspaces, or removed scripts.

Verify explanations against the implementation, including units, defaults,
accepted values and setting interactions. Keep development chronology and
implementation comparisons in designated maintainer material.

Read all text within the requested scope as a new user. For repository-wide
audits, include unchanged headers and internal helpers. Keyword searches
support this review; they do not replace it.

**Applies to**

User-facing software documentation, configuration references, function
headers and source comments.

**Exceptions**

Requested changelogs, migration guides and provenance reports may discuss
historical material when relevant to their audience. Preserve necessary
scientific references, attribution and license notices.

**Reason**

Correct code and passing tests do not establish that its documentation
is understandable without development context.

**Added**

2026-11-05
