# Non-Functional Requirements Specification — ConnectLocal

## 1. Introduction
This document specifies the quality attributes and operational constraints ConnectLocal must satisfy, complementing the Functional Requirements Specification. Non-functional requirements (NFRs) govern *how well* the system performs its functions rather than *what* it does.

## 2. Purpose
To define measurable quality targets for performance, security, usability, reliability, scalability, and maintainability that will be validated during system testing and used to assess production readiness.

## 3. Scope
Applies to the Flutter client applications, the Node.js/Express backend, the Supabase-managed database and authentication layer, and integrations with Google Maps and PayFast.

## 4. Detailed Content

### 4.1 Performance
| ID | Requirement | Target |
|---|---|---|
| NFR-PERF-01 | API response time for standard CRUD endpoints | ≤ 500ms at the 95th percentile under normal load |
| NFR-PERF-02 | Provider search query response time | ≤ 1.5s for a 10km radius search |
| NFR-PERF-03 | Mobile app cold start time | ≤ 3s on a mid-range device |
| NFR-PERF-04 | Real-time message delivery latency | ≤ 1s under normal network conditions |

### 4.2 Scalability
| ID | Requirement |
|---|---|
| NFR-SCAL-01 | The backend shall be stateless to support horizontal scaling across multiple Render instances. |
| NFR-SCAL-02 | The database schema shall support at least 50,000 provider records and 500,000 booking records without significant query degradation, assuming appropriate indexing. |

### 4.3 Security
| ID | Requirement |
|---|---|
| NFR-SEC-01 | All data in transit shall be encrypted using TLS 1.2 or higher. |
| NFR-SEC-02 | Passwords shall never be stored in plaintext; authentication is delegated to Supabase Auth, which uses bcrypt/argon2 hashing. |
| NFR-SEC-03 | All API endpoints (except public search/browse) shall require a valid JWT bearer token. |
| NFR-SEC-04 | Row-Level Security (RLS) policies shall be enforced in PostgreSQL to prevent cross-tenant data access. |
| NFR-SEC-05 | The system shall validate and sanitize all user input server-side to mitigate SQL injection and XSS. |
| NFR-SEC-06 | Payment credentials and webhooks shall be validated using PayFast signature verification. |
| NFR-SEC-07 | The system shall log authentication failures and flag repeated failed attempts for rate limiting. |

### 4.4 Usability
| ID | Requirement |
|---|---|
| NFR-USE-01 | The mobile application shall conform to Material Design (Android) and Cupertino (iOS) interaction patterns via Flutter's adaptive widgets. |
| NFR-USE-02 | Core user flows (search, book, pay) shall be completable within 5 taps/screens from the home screen. |
| NFR-USE-03 | The system shall provide clear, actionable error messages for all failed operations. |

### 4.5 Reliability & Availability
| ID | Requirement |
|---|---|
| NFR-REL-01 | The production backend shall target 99.5% uptime, measured monthly. |
| NFR-REL-02 | The system shall gracefully degrade (e.g., show cached data) when the Google Maps API is unavailable. |
| NFR-REL-03 | All booking and payment transactions shall be atomic; partial writes are not permitted. |

### 4.6 Maintainability
| ID | Requirement |
|---|---|
| NFR-MAINT-01 | Backend code shall maintain a minimum of 70% unit test coverage on service-layer logic. |
| NFR-MAINT-02 | All public API endpoints shall be documented in `docs/api-specs/` and kept in sync with implementation. |
| NFR-MAINT-03 | Database schema changes shall be managed exclusively through versioned migration scripts. |

### 4.7 Compatibility
| ID | Requirement |
|---|---|
| NFR-COMP-01 | The Flutter client shall support Android 8.0+ and iOS 13+. |
| NFR-COMP-02 | The Flutter Web build shall support the latest two major versions of Chrome, Safari, and Edge. |

## 5. Assumptions
- Load testing will be performed against representative, not full-scale production, traffic volumes given the academic project timeframe.
- Supabase and Render's managed infrastructure SLAs are inherited as the practical ceiling for platform availability.

## 6. Constraints
- Free/trial tiers of Supabase, Render, Google Maps, and PayFast sandbox impose rate limits that bound load testing scope.
- No dedicated security penetration testing budget; security validation relies on standard tooling (OWASP ZAP, npm audit, `flutter analyze`).

## 7. Future Enhancements
- Introduction of a CDN and edge caching layer for static assets and map tiles.
- Formal penetration testing and SOC 2-aligned security review prior to commercial launch.
- Multi-region database replication for improved availability.
