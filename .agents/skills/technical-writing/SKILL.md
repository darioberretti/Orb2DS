---
name: technical-writing
description: Draft, revise, condense, and review scientific, academic, engineering, and other technical prose while avoiding formulaic AI-writing patterns and preserving technical meaning. Use for papers, theses, research proposals, technical reports, abstracts, introductions, methods, results, discussions, conclusions, captions, reviewer responses, technical explanations, API guides, configuration references, and user-facing software documentation in LaTeX, Markdown, or document text. Do not use as the default style guide for email, marketing copy, or fiction.
---

# Technical Writing

Produce prose that sounds like a technically competent author with a specific point to make. Preserve the author's ideas, evidence, level of certainty, vocabulary, and useful idiosyncrasies. Do not replace them with generic polished prose. USE SIMPLE WORDING, the manuscript should be clear, to the point and easy to read!!! To make the text sound less robotic, feel free to link together two phrases using simple conjunctions. This is to say, don't always write single period phrases.

Apply this skill in three layers:

1. Apply all general writing principles.
2. Apply the technical-writing requirements and the conventions of the specific document and section.
3. Revise silently and iteratively until every applicable requirement passes.

## Instruction priority

Resolve conflicts in this order:

1. Follow the user's explicit request and required output format.
2. Preserve source truth, technical meaning, evidence, and uncertainty.
3. Fulfil the function and conventions of the document and section.
4. Apply active rules in [references/additional-rules.md](references/additional-rules.md).
5. Apply the general and technical defaults in this file.
6. Use [references/examples.md](references/examples.md) as decision guidance, not as text to imitate.

Never sacrifice technical accuracy to satisfy a stylistic preference. If requirements conflict or the source lacks information needed to satisfy them, state the problem instead of inventing a solution.

## Prepare before writing

Before drafting or revising:

1. Identify the document type, section, audience, purpose, and requested operation.
2. Read enough surrounding material to understand the argument, terminology, notation, and voice.
3. Read `references/additional-rules.md` in full.
4. Read the relevant entries in `references/examples.md` when active examples exist.
5. Establish a content contract containing:
   - the claims and distinctions that must survive;
   - the evidence, numbers, equations, units, citations, and terminology that support them;
   - the demonstrated results, interpretations, hypotheses, assumptions, limitations, and future work;
   - the information that is missing and must not be invented;
   - the requested length, format, and degree of intervention.
6. Infer missing stylistic context from the prompt and surrounding document. Ask only when the missing choice would materially change the result.

## General writing principles

### 1. Start with the actual point

Cut throat-clearing such as "Here's the thing," "It's worth noting," "In today's rapidly evolving...," "When it comes to...," and "Let's explore..." Do not spend a paragraph announcing what the text will discuss before saying anything concrete.

Begin close to the actual object, problem, mechanism, result, or decision. Retain orientation only when readers genuinely need it to understand the point.

### 2. Prefer concrete information to polished abstraction

Prefer names, numbers, mechanisms, observations, decisions, examples, and consequences. Do not write "the implications are significant," "this highlights the importance of...," or "this reflects broader trends" without naming the implication, importance, or trend.

If the source does not support a more concrete statement, keep the claim modest instead of replacing the missing substance with grand language.

### 3. Use ordinary words when ordinary words work

Do not replace "use" with "leverage," "be" with "remain", "help" with "facilitate," "field" with "landscape," or "explain" with "unpack" merely to sound polished.

Watch for habitual model vocabulary such as:

- delve, tapestry, testament;
- crucial, pivotal, vital;
- robust, comprehensive, seamless;
- multifaceted, nuanced, intricate;
- landscape, realm;
- navigate, leverage, foster, facilitate;
- underscore, highlight;
- game-changing, transformative, ever-evolving.

Do not ban these words. Use one when it is technically accurate and genuinely the best word; remove it when it adds only tone.

### 4. Remove habitual negative parallelism

Watch for formulaic constructions such as:

- "It's not X. It's Y."
- "The question isn't X; it is Y."
- "Not because X, but because Y."
- "It is not just X; it is also Y."
- "Not X. Not Y. Z."
- "X rather than Y."

State the interesting claim directly when the negated setup exists only to manufacture a reversal. Keep a contrast when the distinction itself carries technical or argumentative meaning. Do not repeat the same contrast pattern nearby.

### 5. Stop defaulting to three

Do not automatically produce three adjectives, examples, reasons, sentences, bullets, or contributions because three sounds complete. Use however many items the content requires: one, two, three, four, or more.

Keep three-part structures when all three items are real, distinct, and necessary. Never delete a technical condition or invent an extra item merely to change the count.

### 6. Vary rhythm naturally

Let sentence and paragraph length follow the material. Do not make every paragraph follow claim, explanation, example, and neat takeaway. Some ideas need one sentence; others need six.

Avoid metronomic regularity, but do not alternate long and short sentences according to a formula. Natural rhythm comes from differences in thought, not decorative variation.

### 6a. Control sentence load

Judge a sentence by the amount of reasoning it asks the reader to hold, not by word count alone. A long sentence may work when it has one clear grammatical spine and every qualification belongs to the same claim. Split it when it combines several independent claims, methods, conditions, examples, or outcomes, especially when the main verb becomes difficult to locate.

Treat sentences above roughly 35 words as a review signal, not an automatic error. Check whether the reader must cross more than two levels of subordination, pass through a long embedded list, or reinterpret an earlier clause after reaching the end. If so, divide the sentence at the real logical boundary and use a short connective to preserve sequence, cause, contrast, or dependence. After splitting, read the paragraph aloud in effect: restore any relationship that became implicit and avoid a chain of clipped sentences.

### 7. Do not manufacture profundity with fragments

Avoid applause-cue fragments such as:

- "That changed everything. Completely."
- "The result? Transformation."
- "One word: trust."
- "Not perfect. Not easy. But necessary."

Use short sentences or fragments when the voice and medium naturally call for them, not to make an ordinary claim sound momentous. Technical prose normally benefits from complete statements.

### 8. Avoid fake rhetorical questions

Do not ask a question solely to answer it in the next sentence: "So what does this mean?" "Why does this matter?" "The answer is simple."

Usually delete the setup and state the answer. Retain a research question, organizing question, or unresolved question when the question genuinely structures the inquiry.

### 9. Do not make every paragraph land on a quotable conclusion

Avoid ending each paragraph with a compact maxim, dramatic synthesis, or slogan. Real exposition often finishes the explanation and moves on.

Use a concluding sentence when it performs necessary interpretive work. Do not add one merely to make the paragraph feel polished or complete.

### 10. Do not over-explain transitions

Avoid repeated transitions such as "Furthermore," "Moreover," "Additionally," and "Building on this," especially when the logical connection is already obvious. Remove sentences whose only purpose is to announce how the next sentence relates to the previous one.

Use a pronoun, "but," "so," a precise connective, or no transition when that is enough. Retain explicit transitions when the argument would otherwise be difficult to follow.

### 11. Name actors when doing so adds information

Avoid vague passive constructions and evasive abstract agency when a responsible actor matters. Replace "the decision emerged" with who decided, or "the market rewarded the approach" with what buyers or organizations did, when that information is known and relevant.

Do not force a human subject into scientific sentences. Models may predict, methods may produce, equations may define, results may show, and procedures may be described passively when those constructions are accurate and conventional.

### 12. Never fake specificity

Do not invent a number, anecdote, quotation, citation, source, personal experience, example, or concrete detail merely because specificity sounds more human.

Draw specificity from the source material. When the source is incomplete, use a placeholder if requested, qualify the claim, or identify what information is missing.

### 13. Reduce unnecessary hedging and compulsory balance

Do not soften every claim with "often," "typically," "generally," "in many cases," or an automatic account of the opposing side. Make the claim when the evidence permits it.

Preserve hedges that encode real uncertainty, scope, variability, statistical confidence, model limitations, or epistemic status. Technical calibration is information, not verbal weakness.

### 14. Remove generic enthusiasm and service-desk language

Do not begin authored prose with "Great question," "Absolutely," or "I'd be happy to." Do not end it with "I hope this helps" or "Feel free to reach out."

Do not add praise, reassurance, motivational language, or generic enthusiasm that the author did not express. Start with the content and stop when the useful content is finished.

### 15. Match structure to the medium

Do not default to headings, bullets, numbered lists, bold text, or rigid templates. A short explanation may need only two paragraphs. A methods section or proposal may need a clear hierarchy, equations, tables, or lists.

Use structure when it makes the specific material easier to understand. Do not remove necessary structure merely to make the text appear more human.

### 16. Do not automatically summarize the conclusion

Delete a final paragraph that only compresses the previous paragraphs without adding a decision, consequence, limitation, or required synthesis. Avoid "Ultimately" and "In conclusion" unless the genre or argument calls for an explicit close.

In formal papers, a conclusion section may be required. Make it answer the research question and select the strongest evidence rather than replaying every section.

### 17. Editing should usually make prose shorter

When asked to polish or improve text, prefer cuts and substitutions. Do not add transitions, framing, qualifiers, or abstraction merely to make the prose smoother.

Expand only when information, reasoning, or context is genuinely missing and the task authorizes expansion. Never invent the missing material.

### 18. Preserve the writer's useful irregularities

Do not silently replace slightly unusual vocabulary, contractions, fragments, repetitions, or rhythms with a uniform model house style. Preserve choices that carry voice, emphasis, or technical intent.

Fix genuine ambiguity, awkwardness, inconsistency, and error. Do not equate individuality with imperfection or polish with correctness.

### 19. Do not manufacture humanity with errors

Do not add deliberate misspellings, random slang, lowercase gimmicks, fake profanity, invented opinions, fake anecdotes, or awkward grammar to evade an "AI voice."

Make the prose sound authored through purpose, specificity, judgment, and rhythm, not simulated carelessness.

### 20. Keep it simple

Do not fake profoundness with complex wording. A good text is a comprehensible text. Use simple syntax to express what you want to say.

## Technical-writing requirements

### Preserve technical integrity

- Preserve factual meaning, claim strength, scope, and epistemic status.
- Never invent results, citations, equations, parameters, definitions, motivations, validation, or novelty.
- Distinguish demonstrated results, observations, interpretations, hypotheses, assumptions, limitations, preliminary evidence, and future work.
- Preserve meaningful distinctions even when they make the prose less symmetrical.
- Keep quantitative comparisons tied to their conditions, baselines, models, and units.
- Do not turn correlation into causation, feasibility into validation, one application into generality, or a model result into operational proof.
- If evidence is incomplete, state the boundary or request the missing information.

### Preserve notation, terminology, and sources

- Preserve symbols, equations, subscripts, superscripts, signs, dimensions, units, significant figures, variable definitions, and cross-references.
- Preserve citations and their attachment to the claims they support. Do not move a citation so that it appears to support a different claim.
- Do not create plausible-looking citations or bibliography entries.
- Use established domain terminology when it is more precise than an ordinary substitute.
- Define unfamiliar terms according to the audience; do not repeatedly redefine standard terms for specialists.
- Keep acronyms, capitalization, hyphenation, spelling convention, tense, and names consistent with the surrounding document.
- Preserve LaTeX commands, Markdown structure, Word field meaning, labels, references, and other markup unless the user asks to change them.

### Fit the audience without diluting the content

- For specialists, use the field's natural vocabulary and omit elementary explanations that interrupt the argument.
- For mixed or cross-disciplinary readers, explain the system or mechanism in ordinary technical language before introducing dense jargon.
- Replace jargon only when it obscures rather than specifies.
- Do not turn a proposal or paper into a public-facing explainer merely to make it readable.
- Prefer one accurate explanation to a stack of near-synonymous technical nouns.

### Use scientific grammar naturally

- Allow passive voice when the procedure, object, or result matters more than the actor, especially in methods.
- Prefer active voice when it clarifies responsibility, reasoning, or experimental action.
- Allow models, methods, data, figures, equations, and results as grammatical subjects when the construction is conventional and accurate.
- Use precise adverbs such as "linearly," "numerically," "statistically," or "dynamically" when they carry technical meaning.
- Preserve complete lists of variables, constraints, cases, metrics, or contributions regardless of their length.
- Avoid noun stacks when a short clause would make the relationship clearer.

#### Captions and table text

- Captions should ONLY explain what's in the figure or text clearly, unambigously and completely, in as little space as possible.

## Draft or revise

### Draft new text

1. Determine the real point and the section's job.
2. Build an argument or explanation from the content contract.
3. Draft with concrete mechanisms, evidence, and boundaries.
4. Use the natural conventions of the field and document.
5. Stop when the requested function is complete; do not append a generic summary.

### Revise existing text

1. Preserve meaning and voice before improving polish.
2. Make the smallest changes that solve the stated problem.
3. Keep technically useful vocabulary and intentional irregularity.
4. Fix ambiguity, weak ordering, repetition, inflated language, and genuine awkwardness.
5. Prefer deletion or substitution to expansion.
6. Do not silently add claims, remove nuance, strengthen certainty, or simplify away a technical distinction.
7. Preserve unchanged passages when they already work.
8. Return revision notes only when requested or when a necessary limitation cannot be represented safely in the text alone.

## Mandatory iterative revision loop

Never return the first draft without review. Perform the following passes silently. After any change, repeat every affected pass. Continue until all applicable checks pass.

### Pass 1: Source and technical fidelity

Confirm that:

- every factual claim is supported by the supplied material;
- no number, unit, equation, citation, condition, definition, or limitation was changed or lost;
- every qualification remains attached to the correct claim;
- no inference is presented as an observation and no planned result as an established result;
- no missing information was replaced with a plausible invention.

Any failure in this pass blocks delivery.

### Pass 2: Document and section function

Confirm that:

- the passage performs the requested section's job;
- the main point appears at the right place;
- the order follows the argument rather than a generic template;
- every paragraph has one coherent function or an intentional connection between functions;
- the technical level fits the audience without diluting the content.

### Pass 3: General writing principles

Check all 20 principles, including:

- throat-clearing or generic framing;
- polished abstractions where concrete content is available;
- habitual model vocabulary;
- repeated negative contrasts, triplets, rhetorical questions, or dramatic fragments;
- metronomic sentence or paragraph structure;
- over-explained transitions and suspiciously neat paragraph endings;
- vague agency, fake specificity, unnecessary hedging, or compulsory balance;
- generic enthusiasm, excessive formatting, redundant conclusions, or homogenized voice;
- clustered em dashes, passive constructions, adverbs, or other devices used automatically rather than purposefully.
- clarity and simplicity of the written text. If something could be written in a more straightforward way, rewrite it.

### Pass 4: Sentence and paragraph quality

Check for:

- ambiguous pronouns or logical relationships;
- overloaded sentences, including sentences above roughly 35 words that combine multiple claims, methods, conditions, lists, or outcomes;
- excessive clause nesting or a main grammatical spine that is difficult to follow;
- choppy compression that damages comprehension;
- repetitive openings, syntax, cadence, or punctuation;
- dense noun stacks and weak verbs;
- paragraphs that repeat rather than advance the argument;
- transitions added for smoothness rather than logic;
- openings that can start later and endings that can stop earlier.

### Pass 5: Compression and preservation

Cut anything that adds no meaning. Then verify that the cuts did not remove precision, qualification, logical continuity, necessary orientation, or authorial voice. Restore content when concision has made the prose less accurate or less readable.

### Pass 6: Final compliance

Confirm that:

- every explicit user requirement is satisfied;
- every active additional rule is satisfied;
- the required length, format, terminology, spelling convention, and markup are preserved;
- the result is ready to use rather than merely polished-sounding;
- nothing else can be cut or clarified without losing meaning.

For software documentation, verify compliance with AR-007 through a semantic
reading of the requested scope. Do not infer compliance from tests,
keyword searches, or the presence of project instructions alone.

If any check fails, revise and repeat. If a check cannot pass because requirements conflict or evidence is missing, identify the conflict for the user instead of concealing it.

Return the finished text without exposing the internal checklist unless the user asks for an audit, rationale, or change log.
