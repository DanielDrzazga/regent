# Technology Stack

> Fill in with specifics detected by `/regent:init` (package.json, tsconfig, docker) or from the interview.

## Runtime & Language

| Element | Value |
|---------|-------|
| Runtime | [e.g. Node.js 20] |
| Language | [e.g. TypeScript 5.3] |
| Package manager | [npm / pnpm / yarn] |

## Framework

| Layer | Technology |
|-------|------------|
| Backend | [e.g. NestJS 10 / Express / FastAPI] |
| ORM / DB access | [e.g. Prisma / TypeORM] |
| Validation | [e.g. class-validator / zod] |

## Frontend (if applicable — remove in backend-only projects)

<!-- The presence of this section = "project has a frontend" signal for commands and agents. -->

| Element | Technology |
|---------|------------|
| UI framework | [e.g. React 18 / Vue 3] |
| Build tool | [e.g. Vite / Next] |
| State management | [e.g. TanStack Query + Zustand] |
| Styling | [e.g. Tailwind / CSS Modules] |
| Component library | [e.g. internal DS / MUI / none] |
| Routing | [e.g. React Router / file-based] |

Pattern details: `ai/docs/patterns/frontend-patterns.md`.

## Database

| Element | Value |
|---------|-------|
| Engine | [e.g. PostgreSQL 16] |
| Migrations | [e.g. Prisma Migrate] |
| Cache | [e.g. Redis / none] |

## Message Queue / Events (if applicable)

| Element | Technology |
|---------|------------|
| Broker | [e.g. RabbitMQ / Kafka / none] |
| Client | [e.g. @golevelup/nestjs-rabbitmq] |
| Event bus | [e.g. @nestjs/cqrs] |

## Testing

| Type | Tool |
|------|------|
| Unit / Integration | [e.g. Jest / Vitest] |
| Component (UI) | [e.g. Vitest + Testing Library / none — backend-only project] |
| E2E | [API: e.g. Supertest / browser: e.g. Playwright] |
| Coverage | [e.g. c8 / built-in] |

## Infrastructure

- Containerization: [e.g. Docker + docker-compose]
- CI/CD: [e.g. GitHub Actions]
- Environments: [dev / staging / prod]

## TypeScript Config (if TS — excerpt of relevant options)

```json
{
  "module": "[e.g. commonjs]",
  "target": "[e.g. ES2023]",
  "strict": "[true/false]",
  "strictNullChecks": "[true/false]"
}
```

## Ports (if applicable)

| Port | Purpose |
|------|---------|
| [e.g. 80] | [REST API] |
| [e.g. 8081] | [health] |
| [e.g. 5001] | [metrics] |

## Key dependencies

| Package | Version | What for |
|---------|---------|----------|
| [e.g. nestjs-pino] | [1.x] | [logging] |
