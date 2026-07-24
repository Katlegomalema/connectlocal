# Definition of Done — ConnectLocal

## 1. Introduction
Establishes the shared, objective criteria the team uses to determine when a user story, task, or bug fix is genuinely complete.

## 2. Purpose
To prevent ambiguity around "done" status, ensuring consistent quality across all delivered work and reliable sprint reporting.

## 3. Scope
Applies to all work items tracked on the GitHub Projects board, regardless of type (feature, bug, chore, documentation).

## 4. Detailed Content

### 4.1 Definition of Done Checklist
A work item is **Done** only when all of the following are true:

- [ ] Code implements all acceptance criteria stated on the linked user story/issue.
- [ ] Code is merged into `develop` via an approved pull request (see CONTRIBUTING.md).
- [ ] All CI checks (lint, unit tests, integration tests, build) pass.
- [ ] Unit tests cover new/changed business logic (service-layer functions).
- [ ] No known critical or high-severity defects remain open against the item.
- [ ] Relevant documentation updated (API spec, README, architecture doc) in the same PR.
- [ ] Database migrations included and tested if schema changed.
- [ ] Manually verified against acceptance criteria on at least one target platform (Android/iOS/Web as applicable).
- [ ] Peer-reviewed and approved by at least one other team member.
- [ ] No secrets or credentials committed.

### 4.2 Definition of Ready (complementary)
Before a story enters a sprint, it must have: a clear description, acceptance criteria, an estimate, and no unresolved blocking dependencies.

## 5. Assumptions
- The team applies this Definition of Done uniformly regardless of perceived task size or deadline pressure.

## 6. Constraints
- Given the academic timeline, "Done" does not require production-scale load testing or formal security certification (see Non-Functional-Requirements.md Constraints).

## 7. Future Enhancements
- Add automated Definition-of-Done verification via a GitHub Actions status check bot.
