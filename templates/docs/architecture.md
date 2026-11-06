# Architecture Patterns

> Fill in based on the directory structure and imports detected by `/regent:init`.

## Architecture type

[Modular Monolith / Microservices / Monolith] — [1-2 sentences of rationale]

## Layers

| Layer | Responsibility | May depend on |
|-------|----------------|---------------|
| Domain | Entities, value objects, business rules | (nothing) |
| Application | Use cases, application services | Domain |
| Infrastructure | Repositories, external integrations | Domain, Application |
| Interface | Controllers, API, CLI | Application |

**Dependency direction:** Domain ← Application ← Infrastructure/Interface (Domain depends on nothing).

## Module structure

```
src/
└── modules/
    └── {module}/
        ├── domain/
        ├── application/
        ├── infrastructure/
        └── interface/
```

## Module boundaries

- [Rule for communication between modules — e.g. only through ports/API, not directly through the repo]
- [Shared code → where, e.g. `src/core/` / `src/shared/`]

## Cross-cutting patterns

| Pattern | Usage |
|---------|-------|
| DI | [e.g. NestJS built-in] |
| Error handling | [→ exception-patterns.md] |
| Logging | [→ logging-patterns.md] |

## Reference Implementations

> For each key pattern, point to 1-2 REAL, exemplary implementations in the code.
> This is the "imitate this" source of truth that lets `regent:architect`/`regent:backend-dev` read
> ONE indicated file instead of scanning `src/` in search of the pattern (`/regent:propose`, `/regent:apply`).
> Filled in by `/regent:init`; update through `/regent:revise` when a cleaner example appears.

| Pattern | Exemplary implementation (paths from `src/`) | What it shows |
|---------|----------------------------------------------|---------------|
| [e.g. AMQP consumer] | [full file path] | [1 sentence: validation, delegation, error handling] |
| [e.g. Domain event + handler] | [event path + handler path] | [1 sentence] |
| [e.g. Repository] | [interface + implementation] | [1 sentence] |

## Non-negotiable principles (MUST)

> 3-7 rules that ALREADY apply in the project and can be checked (lint rule, CI gate,
> ADR, team agreement). A "just in case" rule is noise that every agent reads on every
> change — no such rules → remove the section. A deviation in a specific change goes to
> design.md → "Deviations from principles", with a rationale; without that entry `regent:code-reviewer` gives 🔴.

| ID | Principle (MUST) | How to check |
|----|------------------|--------------|
| MUST-1 | [e.g. Domain does not import from Infrastructure] | [e.g. lint rule / review] |
| MUST-2 | [e.g. every public endpoint validates input] | [e.g. integration test → 400] |

## Design guidelines

- The simplest solution that meets the requirements (YAGNI).
- Important decisions → ADR in `ai/docs/adr/` (created by `regent:architect`).
