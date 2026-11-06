# Scope Statement — ConnectLocal

## 1. Introduction
This Scope Statement defines the boundaries of the ConnectLocal project as delivered for the final-year BSc Information Technology software engineering project, establishing what is and is not included in the delivered system.

## 2. Purpose
To provide a single point of reference for the project team, academic supervisor, and assessors on the agreed deliverables, preventing scope creep and clarifying deferred functionality.

## 3. Scope

### 3.1 In Scope
- Customer, Provider, and Administrator user roles with role-based access control.
- Authentication via email/password, Google OAuth, email verification, and phone OTP verification.
- Provider business profile creation and identity/business document verification workflow.
- Location-based provider search and discovery using client-supplied coordinates and PostGIS radius queries.
- Service listing management by providers.
- End-to-end booking workflow (request, accept/decline, reschedule, cancel, complete).
- In-app real-time messaging between customers and providers.
- Ratings and written reviews tied to completed bookings.
- Payment processing via PayFast (sandbox/test mode for the academic delivery; production credentials out of scope).
- Push and in-app notifications for key lifecycle events.
- Administrator dashboard for user/provider management, verification approval, review moderation, dispute handling, and basic analytics.
- Full documentation suite: requirements, architecture, database design, API specification, project management artifacts, testing strategy, and deployment guide.

### 3.2 Out of Scope
- Native iOS/Android modules beyond what Flutter provides out of the box.
- Multi-language/internationalization support.
- Provider payout automation to bank accounts (manual/simulated payout tracking only).
- Advanced AI-based recommendation or fraud-detection systems.
- Video calling/consultation features.
- Full penetration testing / formal security certification.
- Production-scale load testing beyond what is feasible within Supabase/Render free-tier limits.
- Marketing website and SEO optimization.

## 4. Detailed Content

### 4.1 Deliverables
1. Source code for the Flutter frontend and Node.js/Express backend.
2. PostgreSQL database schema, migrations, and seed data.
3. Complete documentation set (this repository).
4. CI pipelines for automated linting and testing.
5. Deployed staging environment (Supabase + Render) for demonstration purposes.
6. Final academic report derived from this documentation set.

### 4.2 Success Criteria
- All "Must Have" user stories implemented and passing acceptance tests.
- System deployed and demonstrable in a staging environment.
- Test coverage targets met per the Test Strategy document.
- Documentation complete and internally consistent, suitable for supervisor and external assessor review.

## 5. Assumptions
- The project team has continuous access to Supabase, Render, and PayFast sandbox accounts throughout the semester.
- Scope reflects requirements as understood at project inception; material changes will be documented via the Risk Register and Change Log.

## 6. Constraints
- Fixed academic semester timeline (~12–14 weeks) with fixed team size (see Team Structure in README.md).
- Zero/low budget project — reliant on free/trial tiers of third-party services.

## 7. Future Enhancements
See Section 3.2 (Out of Scope) — these items constitute the candidate roadmap for a post-academic, production-grade release.
