# Naming Conventions

> Fill in based on the existing files and code detected by `/regent:init`.

## Files and directories

| Element | Convention | Example |
|---------|------------|---------|
| Files | [e.g. kebab-case] | `user-registration.service.ts` |
| Directories | [e.g. kebab-case] | `template-management/` |
| File suffixes | [by role] | `*.service.ts`, `*.repository.ts`, `*.entity.ts`, `*.controller.ts` |
| Test files | [e.g. `*.spec.ts` / `*.test.ts`] | `user.service.spec.ts` |

## Code

| Element | Convention | Example |
|---------|------------|---------|
| Classes / types | PascalCase | `UserRepository` |
| Variables / functions | camelCase | `findByEmail` |
| Constants | UPPER_SNAKE_CASE | `MAX_RETRY_COUNT` |
| Interfaces | [e.g. PascalCase without `I`] | `UserRepository` |
| Enums | [PascalCase + values] | `OrderStatus.Pending` |

## Domain naming

- Names describe **intent**, not implementation (`findActiveUsers`, not `queryUsers2`).
- Methods: verb + noun (`createOrder`, `sendNotification`).
- Booleans: `is`/`has`/`can` (`isActive`, `hasAccess`).

## Class name schemes (by role)

| Role | Scheme | Example |
|------|--------|---------|
| Entity (domain) | `{Name}` (singular) | `Order` |
| Value Object | `{Concept}` | `Money`, `EmailAddress` |
| Domain Event | `{VerbPastTense}{Context}Event` | `OrderCreatedEvent` |
| Exception | `{Description}Exception` | `OrderNotFoundException` |
| Repository (interface) | `{Name}Repository` | `OrderRepository` |
| Application Service | `{Action/Module}Service` | `CreateOrderService` |
| Controller | `{Context}Controller` | `OrderController` |
| Adapter | `{Service}Adapter` | `PaymentGatewayAdapter` |
| Mapper / Builder | `{Name}Mapper` / `{Name}Builder` | `OrderMapper`, `OrderBuilder` |

## Database

| Type | Convention | Example |
|------|------------|---------|
| Tables | snake_case, plural | `order_items` |
| Columns | snake_case | `created_at`, `user_id` |
| Indexes | `idx_{table}_{columns}` | `idx_orders_user_id` |

## API

| Type | Convention | Example |
|------|------------|---------|
| Endpoints | kebab-case, REST | `/order-items/:id` |
| Path params | [e.g. camelCase / UPPER_SNAKE] | `:orderId` |
| Query params | camelCase | `?pageSize=20` |
| Body fields | camelCase | `{ "templateName": "..." }` |

## Log `action`

`NOUN_VERB`, UPPERCASE, EN (`MESSAGE_SENT`) — see `logging-patterns.md`.
