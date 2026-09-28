# Naming Conventions

> Wypełnij na podstawie istniejących plików i kodu wykrytych przez `/regent:init`.

## Pliki i katalogi

| Element | Konwencja | Przykład |
|---------|-----------|----------|
| Pliki | [np. kebab-case] | `user-registration.service.ts` |
| Katalogi | [np. kebab-case] | `template-management/` |
| Sufiksy plików | [wg roli] | `*.service.ts`, `*.repository.ts`, `*.entity.ts`, `*.controller.ts` |
| Pliki testów | [np. `*.spec.ts` / `*.test.ts`] | `user.service.spec.ts` |

## Kod

| Element | Konwencja | Przykład |
|---------|-----------|----------|
| Klasy / typy | PascalCase | `UserRepository` |
| Zmienne / funkcje | camelCase | `findByEmail` |
| Stałe | UPPER_SNAKE_CASE | `MAX_RETRY_COUNT` |
| Interfejsy | [np. PascalCase bez `I`] | `UserRepository` |
| Enumy | [PascalCase + wartości] | `OrderStatus.Pending` |

## Nazewnictwo domenowe

- Nazwy opisują **intencję**, nie implementację (`findActiveUsers`, nie `queryUsers2`).
- Metody: czasownik + rzeczownik (`createOrder`, `sendNotification`).
- Booleany: `is`/`has`/`can` (`isActive`, `hasAccess`).

## Schematy nazw klas (wg roli)

| Rola | Schemat | Przykład |
|------|---------|----------|
| Entity (domain) | `{Name}` (l.poj.) | `Order` |
| Value Object | `{Concept}` | `Money`, `EmailAddress` |
| Domain Event | `{VerbPastTense}{Context}Event` | `OrderCreatedEvent` |
| Exception | `{Description}Exception` | `OrderNotFoundException` |
| Repository (interfejs) | `{Name}Repository` | `OrderRepository` |
| Application Service | `{Action/Module}Service` | `CreateOrderService` |
| Controller | `{Context}Controller` | `OrderController` |
| Adapter | `{Service}Adapter` | `PaymentGatewayAdapter` |
| Mapper / Builder | `{Name}Mapper` / `{Name}Builder` | `OrderMapper`, `OrderBuilder` |

## Database

| Typ | Konwencja | Przykład |
|-----|-----------|----------|
| Tabele | snake_case, l.mn. | `order_items` |
| Kolumny | snake_case | `created_at`, `user_id` |
| Indeksy | `idx_{table}_{columns}` | `idx_orders_user_id` |

## API

| Typ | Konwencja | Przykład |
|-----|-----------|----------|
| Endpoints | kebab-case, REST | `/order-items/:id` |
| Path params | [np. camelCase / UPPER_SNAKE] | `:orderId` |
| Query params | camelCase | `?pageSize=20` |
| Body fields | camelCase | `{ "templateName": "..." }` |

## Log `action`

`RZECZOWNIK_CZASOWNIK`, UPPERCASE, EN (`MESSAGE_SENT`) — zob. `logging-patterns.md`.
