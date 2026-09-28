# DI Patterns

> Opcjonalny. Wypełnij, jeśli `/regent:init` wykryje kontener DI. Opisuje jak wstrzykiwać zależności.

## Kontener

| Pole | Wartość |
|------|---------|
| Mechanizm | [np. NestJS built-in / InversifyJS / manual] |
| Rejestracja | [np. moduł `@Module({ providers: [...] })`] |

## Zasady wstrzykiwania

- Wstrzykiwanie przez **konstruktor** (nie property/setter).
- Zależność od **abstrakcji** (interfejs/port), nie konkretnej implementacji.
- Serwisy bezstanowe; stan → dedykowane obiekty.

```typescript
constructor(
  private readonly userRepository: UserRepository, // interfejs/port
  private readonly logger: CustomLoggerService,
) {}
```

## Tokeny / porty

- [Jak definiować i wiązać porty z implementacjami — np. `provide: USER_REPOSITORY, useClass: PrismaUserRepository`]

## Zasięgi (scopes)

| Scope | Kiedy |
|-------|-------|
| Singleton | [domyślnie] |
| Request-scoped | [gdy potrzebny kontekst requestu] |

## Testy

- W testach wstrzykuj mocki portów (shared mocks z `tests/helpers/mocks/`).
