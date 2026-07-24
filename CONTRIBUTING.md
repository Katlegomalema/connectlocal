# Contributing to ConnectLocal

Thank you for contributing to ConnectLocal. This document defines the standards all contributors (including academic team members and external reviewers) must follow to keep the codebase and documentation consistent, auditable, and production-quality.

## 1. Branch Naming Convention

All branches must be created from `develop` (except hotfixes, from `main`) and follow this pattern:

```
<type>/<ticket-id>-<short-description>
```

| Type | Use Case | Example |
|---|---|---|
| `feature/` | New functionality | `feature/CL-101-provider-search` |
| `bugfix/` | Non-critical bug fix | `bugfix/CL-118-booking-date-validation` |
| `hotfix/` | Urgent production fix | `hotfix/CL-140-payment-callback-error` |
| `chore/` | Tooling, config, dependencies | `chore/CL-102-eslint-setup` |
| `docs/` | Documentation-only changes | `docs/CL-105-api-spec-update` |
| `test/` | Test additions or fixes | `test/CL-130-booking-unit-tests` |

## 2. Commit Convention

ConnectLocal follows **Conventional Commits**:

```
<type>(<scope>): <short summary>

[optional body]

[optional footer: Closes #<issue-number>]
```

**Types:** `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `chore`

**Examples:**
```
feat(booking): add booking cancellation endpoint
fix(auth): correct refresh token expiry calculation
docs(api): update Provider API response schema
test(payment): add unit tests for PayFast signature validation
```

## 3. Pull Request Process

1. Ensure your branch is up to date with `develop` (`git pull --rebase origin develop`).
2. Ensure all CI checks (lint, unit tests, build) pass locally before pushing.
3. Open a PR against `develop` using the [Pull Request Template](.github/PULL_REQUEST_TEMPLATE.md).
4. Fill in **Description, Changes Made, Testing Done, Screenshots (if UI), and Checklist** in full — incomplete PRs will be returned without review.
5. Link the related issue using `Closes #<issue-number>`.
6. Request review from at least **one** other contributor (two for changes touching authentication, payments, or database migrations).
7. Address all review comments; re-request review after changes.
8. Once approved and CI is green, the PR is merged using **Squash and Merge** to keep history linear.
9. Delete the feature branch after merge.

## 4. Code Review Process

Reviewers evaluate PRs against the following checklist:

- **Correctness** — does the change do what it claims, without regressions?
- **Standards compliance** — does it follow the coding standards below?
- **Test coverage** — are new code paths covered by unit/integration tests?
- **Security** — no secrets committed, inputs validated, authorization checked?
- **Documentation** — are API specs / README / relevant docs updated if behavior changed?
- **Readability** — is the code self-explanatory, appropriately commented, and consistently named?

Reviewers must respond within **48 hours**. Approvals require an explicit "Approve" review; comments alone do not constitute approval.

## 5. Coding Standards

### Backend (Node.js / Express)
- Use ESLint (Airbnb base config) and Prettier; run `npm run lint` before committing.
- Controllers must remain thin — business logic belongs in service modules.
- All routes validate input using `express-validator` or `zod` schemas.
- All database access goes through the repository/service layer — no raw queries in controllers.
- Environment variables are never hardcoded; always read from `process.env` via a config module.
- Use `async/await`; avoid unhandled promise rejections.
- Errors are passed to centralized error-handling middleware, never swallowed silently.

### Frontend (Flutter)
- Follow the [Effective Dart](https://dart.dev/effective-dart) style guide; run `flutter analyze` before committing.
- Use a feature-first folder structure (`lib/features/<feature>/...`).
- State management via Riverpod (or the project-approved provider pattern) — no direct `setState` for shared/business state.
- Widgets are kept small and composable; extract reusable UI into shared widgets.
- No hardcoded strings for user-facing text where localization is planned; use constants files in the interim.

### General
- Naming: `camelCase` for variables/functions, `PascalCase` for classes/components, `UPPER_SNAKE_CASE` for constants.
- No commented-out dead code in merged PRs.
- Every new API endpoint must be documented in `docs/api-specs/` in the same PR.
- Every schema change must include a corresponding migration file in `database/migrations/`.

## 6. Issue Workflow

Issues move through the following states, tracked via GitHub Projects:

```
Backlog → To Do → In Progress → In Review → Done
```

- **Backlog**: Captured but not yet prioritized for a sprint.
- **To Do**: Committed to the current sprint.
- **In Progress**: Actively being worked on; assignee required.
- **In Review**: PR open, awaiting review/QA.
- **Done**: Merged, verified against acceptance criteria, and closed.

All issues must use one of the templates in `.github/ISSUE_TEMPLATE/` (Bug Report, Feature Request, or Documentation Task) and be labeled with a **type**, **priority**, and **module** label (see label list in `docs/project-management/Work-Breakdown-Structure.md`).

## 7. Definition of Done

A task is only marked **Done** when:
- Code is merged to `develop` via an approved PR.
- Automated tests pass in CI.
- Relevant documentation is updated.
- Acceptance criteria on the linked issue are verified.
- No known critical or high-severity defects remain open against it.
