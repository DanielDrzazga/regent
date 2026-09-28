# Technology Stack

> Wypełnij konkretami wykrytymi przez `/regent:init` (package.json, tsconfig, docker) lub z wywiadu.

## Runtime & Language

| Element | Wartość |
|---------|---------|
| Runtime | [np. Node.js 20] |
| Język | [np. TypeScript 5.3] |
| Package manager | [npm / pnpm / yarn] |

## Framework

| Warstwa | Technologia |
|---------|-------------|
| Backend | [np. NestJS 10 / Express / FastAPI] |
| ORM / DB access | [np. Prisma / TypeORM] |
| Walidacja | [np. class-validator / zod] |

## Frontend (jeśli dotyczy — usuń w projektach backend-only)

<!-- Obecność tej sekcji = sygnał "projekt ma frontend" dla komend i agentów. -->

| Element | Technologia |
|---------|-------------|
| Framework UI | [np. React 18 / Vue 3] |
| Build tool | [np. Vite / Next] |
| State management | [np. TanStack Query + Zustand] |
| Styling | [np. Tailwind / CSS Modules] |
| Biblioteka komponentów | [np. wewnętrzny DS / MUI / brak] |
| Routing | [np. React Router / file-based] |

Szczegóły wzorców: `ai/docs/patterns/frontend-patterns.md`.

## Database

| Element | Wartość |
|---------|---------|
| Silnik | [np. PostgreSQL 16] |
| Migracje | [np. Prisma Migrate] |
| Cache | [np. Redis / brak] |

## Message Queue / Events (jeśli dotyczy)

| Element | Technologia |
|---------|-------------|
| Broker | [np. RabbitMQ / Kafka / brak] |
| Klient | [np. @golevelup/nestjs-rabbitmq] |
| Event bus | [np. @nestjs/cqrs] |

## Testing

| Typ | Narzędzie |
|-----|-----------|
| Unit / Integration | [np. Jest / Vitest] |
| Component (UI) | [np. Vitest + Testing Library / brak — projekt backend-only] |
| E2E | [API: np. Supertest / przeglądarkowe: np. Playwright] |
| Coverage | [np. c8 / built-in] |

## Infrastruktura

- Konteneryzacja: [np. Docker + docker-compose]
- CI/CD: [np. GitHub Actions]
- Środowiska: [dev / staging / prod]

## TypeScript Config (jeśli TS — wycinek istotnych opcji)

```json
{
  "module": "[np. commonjs]",
  "target": "[np. ES2023]",
  "strict": "[true/false]",
  "strictNullChecks": "[true/false]"
}
```

## Ports (jeśli dotyczy)

| Port | Cel |
|------|-----|
| [np. 80] | [REST API] |
| [np. 8081] | [health] |
| [np. 5001] | [metrics] |

## Kluczowe zależności

| Pakiet | Wersja | Po co |
|--------|--------|-------|
| [np. nestjs-pino] | [1.x] | [logowanie] |
