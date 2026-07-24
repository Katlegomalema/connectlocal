# ConnectLocal — Database

## Overview
This directory is reserved for database migration scripts and seed data supporting the schema documented in [`diagrams/erd/ERD.md`](../diagrams/erd/ERD.md).

## Structure (planned)
```
database/
├── migrations/          # versioned, timestamped SQL migration files
├── seeds/                 # development/demo seed data scripts
└── policies/               # Row-Level Security policy definitions
```

## Related Documentation
- [`diagrams/erd/ERD.md`](../diagrams/erd/ERD.md) — full entity relationship diagram and table specifications
- [`docs/architecture/Database-Architecture.md`](../docs/architecture/Database-Architecture.md) — architectural rationale, access control, and indexing strategy

## Migration Convention
Migrations follow the naming pattern `YYYYMMDDHHMM_description.sql` (e.g., `202602101000_create_users_table.sql`) and are applied via the Supabase CLI as described in [`docs/deployment/Deployment-Guide.md`](../docs/deployment/Deployment-Guide.md).
