# ConnectLocal — Backend (Node.js / Express)

## Overview
This directory contains the ConnectLocal REST API, implementing the endpoints documented in `docs/api-specs/`.

## Folder Structure
See [`docs/architecture/Backend-Architecture.md`](../docs/architecture/Backend-Architecture.md) Section 4.2 for the full annotated folder structure and layering rationale.

```
backend/
├── src/
│   ├── config/
│   ├── routes/
│   ├── controllers/
│   ├── services/
│   ├── repositories/
│   ├── middleware/
│   ├── integrations/
│   ├── utils/
│   ├── validators/
│   └── app.js
├── tests/
│   ├── unit/
│   └── integration/
├── migrations/
├── server.js
├── package.json
└── .env.example
```

## Getting Started
See the root [README.md](../README.md) Getting Started section and [`docs/deployment/Environment-Setup.md`](../docs/deployment/Environment-Setup.md) for full setup instructions.

## Key Dependencies
- `express` — HTTP framework
- `@supabase/supabase-js` — Supabase client (Auth, DB, Storage, Realtime)
- `zod` — request validation
- `jsonwebtoken` — JWT verification (Supabase-issued tokens)
- `pino` — structured logging
- `pg` — versioned SQL migrations
- `jest` + `supertest` — testing

Nearby search uses PostGIS and the Flutter client supplies coordinates; the backend has no map vendor or geocoding API key.

## API Documentation
All endpoints are documented in [`docs/api-specs/`](../docs/api-specs/). Any new or changed endpoint must be reflected there in the same pull request per [CONTRIBUTING.md](../CONTRIBUTING.md).

## Testing
Run `npm test` for unit and integration suites. Set `DATABASE_URL` and run `npm run migrate` to apply pending SQL migrations. See [`docs/testing/Unit-Testing.md`](../docs/testing/Unit-Testing.md) and [`docs/testing/Integration-Testing.md`](../docs/testing/Integration-Testing.md) for conventions.
