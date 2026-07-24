# Sequence Diagram: Booking & Payment Flow — ConnectLocal

## 1. Introduction
Depicts the end-to-end sequence for a customer creating a booking, the provider accepting it, and the customer completing payment via PayFast.

## 2. Purpose
To document the interaction order across client, backend, database, and the PayFast gateway, ensuring shared understanding of the transactional flow prior to implementation.

## 3. Scope
Covers booking creation through payment confirmation. Messaging that may occur alongside this flow is documented separately.

## 4. Diagram

```mermaid
sequenceDiagram
    actor C as Customer
    actor P as Provider
    participant App as Flutter App
    participant API as Express API
    participant DB as PostgreSQL
    participant PF as PayFast
    participant Notif as Notification Service

    C->>App: Select service + time slot
    App->>API: POST /bookings
    API->>DB: Check for scheduling conflicts
    DB-->>API: No conflict
    API->>DB: INSERT booking (status=pending)
    API->>Notif: Notify provider of new request
    API-->>App: 201 Created {bookingId, status: pending}

    Notif-->>P: Push notification: "New booking request"
    P->>App: Opens booking, taps Accept
    App->>API: PATCH /bookings/:id/respond {action: accept}
    API->>DB: UPDATE booking SET status = confirmed
    API->>Notif: Notify customer of confirmation
    API-->>App: 200 OK {status: confirmed}
    Notif-->>C: Push notification: "Booking confirmed"

    C->>App: Tap "Pay Now"
    App->>API: POST /payments/initiate {bookingId}
    API->>DB: INSERT payment (status=pending)
    API-->>App: 200 OK {redirectUrl}
    App->>PF: Redirect to PayFast hosted page
    C->>PF: Completes payment
    PF-->>API: POST /payments/payfast/itn (server-to-server)
    API->>API: Verify ITN signature
    API->>DB: UPDATE payment SET status = paid
    API->>DB: UPDATE booking payment_status = paid
    API->>Notif: Notify customer + provider of payment received
    API-->>PF: 200 "OK"
```

## 5. Assumptions
- PayFast's ITN callback reaches the API reliably; retry/reconciliation handling is documented as a future enhancement.

## 6. Constraints
- Diagram assumes a single service per booking (no multi-service cart in current scope).

## 7. Future Enhancements
- Add a reconciliation sequence for missed/delayed ITN notifications (scheduled job polling PayFast's query API).
