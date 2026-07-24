# Use Case Diagram — ConnectLocal

## 1. Introduction
This document presents the system-level use case diagram for ConnectLocal, visualizing the interactions between the Customer, Provider, and Administrator actors and the system's core functions.

## 2. Purpose
To provide a high-level, visual complement to the detailed use case descriptions in `docs/requirements/Use-Cases.md`.

## 3. Scope
Covers all primary use cases across the three actors. Shared/included use cases (e.g., Authentication) are modeled using `<<include>>` relationships.

## 4. Diagram

```mermaid
flowchart LR
    Customer((Customer))
    Provider((Provider))
    Admin((Administrator))

    subgraph ConnectLocal["ConnectLocal System"]
        UC1([Register / Login])
        UC2([Search Nearby Providers])
        UC3([View Provider Profile])
        UC4([Create Booking])
        UC5([Manage Bookings])
        UC6([Send / Receive Messages])
        UC7([Make Payment])
        UC8([Submit Review])
        UC9([Manage Business Profile])
        UC10([Submit Verification Documents])
        UC11([Manage Services])
        UC12([Set Availability])
        UC13([Accept / Decline Booking])
        UC14([Respond to Review])
        UC15([Approve Provider Verification])
        UC16([Manage User Accounts])
        UC17([Moderate Reviews])
        UC18([Resolve Disputes])
        UC19([View Analytics])
        UC20([Configure Platform Settings])
    end

    Customer --> UC1
    Customer --> UC2
    Customer --> UC3
    Customer --> UC4
    Customer --> UC5
    Customer --> UC6
    Customer --> UC7
    Customer --> UC8

    Provider --> UC1
    Provider --> UC9
    Provider --> UC10
    Provider --> UC11
    Provider --> UC12
    Provider --> UC13
    Provider --> UC6
    Provider --> UC14

    Admin --> UC1
    Admin --> UC15
    Admin --> UC16
    Admin --> UC17
    Admin --> UC18
    Admin --> UC19
    Admin --> UC20

    UC4 -.include.-> UC1
    UC9 -.include.-> UC1
    UC7 -.include.-> UC4
```

## 5. Assumptions
- All actor interactions with the system require successful authentication (`UC1`), modeled via `<<include>>` on dependent use cases.

## 6. Constraints
- Diagram scope is limited to primary use cases; exception/error flows are detailed in the corresponding use case descriptions rather than the diagram itself.

## 7. Future Enhancements
- Addition of a "Dispute Escalation" actor interaction as the dispute-resolution process matures.
