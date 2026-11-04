# Domain glossary — [Project name]

> **What this file is:** a glossary of this project's domain language and **only that**.
> A term, its meaning here, and the synonyms we avoid.
>
> **What is not here:** implementation decisions, class and file names, architecture description,
> working notes. Those belong in `ai/docs/patterns/`, `design.md` and `ai/docs/adr/`.
> The file must stay readable when all the code gets rewritten.
>
> **When to add:** when the meaning of a term gets settled in a conversation, or it comes to light
> that two people understood a word differently. Add right away, as you go — do not save it for later.

## Terms

Only terms specific to THIS domain. General programming concepts (repository,
cache, middleware) stay outside the glossary.

**[Term]** — [definition in 1-2 sentences, in domain language, without references to code]
_Avoid:_ [synonyms that come up in conversations or code, which we do not use]

**[Term]** — [definition]
_Avoid:_ [synonyms]

<!-- Example:
**Order** — a single request to perform a service placed by a Client, from acceptance
to settlement. Has exactly one Contractor.
_Avoid:_ purchase, task, job, ticket
-->

## Relations

How terms connect to each other — one sentence per relation.

- [Term A] contains many [Term B]
- [Term C] belongs to exactly one [Term A]

<!-- Example:
- A Client places many Orders
- An Order has exactly one Contractor
-->

## Resolved ambiguities

A record of terminology disputes that are already settled. Prevents returning to the same discussion
and explains why the code is the way it is.

- **[word]** previously meant both [A] and [B]. Resolution: [A] is **[Term]**,
  [B] is **[Term]**. [Date]

<!-- Example:
- **"cancellation"** meant both withdrawing an Order before acceptance and aborting it
  midway. Resolution: before acceptance it is a **Withdrawal**, midway it is an **Abort**.
  2026-09-13
-->
