# DI Patterns

> Optional. Fill in if `/regent:init` detects a DI container. Describes how to inject dependencies.

## Container

| Field | Value |
|-------|-------|
| Mechanism | [e.g. NestJS built-in / InversifyJS / manual] |
| Registration | [e.g. module `@Module({ providers: [...] })`] |

## Injection rules

- Injection through the **constructor** (not property/setter).
- Dependency on an **abstraction** (interface/port), not a concrete implementation.
- Stateless services; state → dedicated objects.

```typescript
constructor(
  private readonly userRepository: UserRepository, // interface/port
  private readonly logger: CustomLoggerService,
) {}
```

## Tokens / ports

- [How to define ports and bind them to implementations — e.g. `provide: USER_REPOSITORY, useClass: PrismaUserRepository`]

## Scopes

| Scope | When |
|-------|------|
| Singleton | [default] |
| Request-scoped | [when request context is needed] |

## Tests

- In tests, inject port mocks (shared mocks from `tests/helpers/mocks/`).
