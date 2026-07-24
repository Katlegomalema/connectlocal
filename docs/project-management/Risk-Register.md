# Risk Register — ConnectLocal

## 1. Introduction
Documents identified risks to the successful delivery of ConnectLocal, their likelihood, impact, and mitigation strategies.

## 2. Purpose
To proactively manage threats to project scope, schedule, quality, and academic outcomes, and to provide an auditable record of risk management practice for assessment purposes.

## 3. Scope
Covers technical, schedule, resource, and third-party dependency risks relevant to the academic project timeline.

## 4. Detailed Content

| ID | Risk | Category | Likelihood | Impact | Risk Score | Mitigation | Owner |
|---|---|---|---|---|---|---|---|
| R-01 | Team member unavailability (illness, competing coursework) | Resource | Medium | High | High | Cross-train on modules; maintain up-to-date documentation so any member can pick up a task | Project Lead |
| R-02 | Third-party API quota/rate limits exceeded (Google Maps, Supabase free tier) | Technical | Medium | Medium | Medium | Monitor usage dashboards weekly; implement client-side caching to reduce call volume | Backend Developer |
| R-03 | PayFast sandbox integration issues delaying payment module | Technical | Medium | Medium | Medium | Begin PayFast integration early (Sprint 7 buffer); maintain a mocked payment fallback for demo purposes | Backend Developer |
| R-04 | Scope creep beyond academic timeline | Schedule | Medium | High | High | Enforce Scope Statement; new requests logged to Future Enhancements, not current sprint | Project Lead |
| R-05 | Real-time messaging (Supabase Realtime) connection limits under free tier | Technical | Low | Medium | Low-Medium | Implement polling fallback; monitor connection count during testing | Backend Developer |
| R-06 | Insufficient test coverage due to time pressure late in the semester | Quality | Medium | High | High | Allocate a dedicated hardening sprint (Sprint 9-10); track coverage metrics from Sprint 3 onward | QA Engineer |
| R-07 | Flutter platform-specific bugs (iOS vs Android vs Web rendering differences) | Technical | Medium | Medium | Medium | Test on all three targets each sprint, not only at the end | Frontend Developer |
| R-08 | Data privacy/compliance gaps (POPIA — South African data protection) | Compliance | Low | High | Medium | Restrict PII collection to what's necessary; document data handling in Security-Architecture.md | Project Lead |
| R-09 | Database schema rework mid-project due to design oversight | Technical | Low | High | Medium | Front-load database design review in Sprint 1-2 before dependent feature work begins | Backend Developer |
| R-10 | Academic assessment criteria misunderstood/misaligned | Schedule | Low | High | Medium | Fortnightly supervisor check-ins to validate direction against rubric | Project Lead |

**Risk Score Legend:** Likelihood × Impact, qualitatively rated Low / Medium / High.

## 5. Assumptions
- Risk likelihood/impact ratings are reassessed at each sprint retrospective rather than fixed for the project's duration.

## 6. Constraints
- No formal risk management tooling; the register is maintained manually as a markdown document within version control.

## 7. Future Enhancements
- Introduce a quantitative risk scoring model (e.g., 1–5 scale with numeric risk score) if the project extends beyond the academic timeline.
