# Activity Diagram: Booking Lifecycle — ConnectLocal

## 1. Introduction
Depicts the flow of activities and decision points a booking passes through from creation to completion or cancellation.

## 2. Purpose
To visualize the booking state machine and its branching logic for developers implementing the Booking Service, and for testers deriving test cases covering each path.

## 3. Scope
Covers the customer- and provider-driven activities governing a single booking's lifecycle.

## 4. Diagram

```mermaid
flowchart TD
    Start([Customer selects service & slot]) --> CheckAvail{Slot available?}
    CheckAvail -- No --> ShowConflict[Show conflict, prompt new slot]
    ShowConflict --> Start
    CheckAvail -- Yes --> CreateBooking[Create booking: status = pending]
    CreateBooking --> NotifyProvider[Notify provider]
    NotifyProvider --> ProviderDecision{Provider response}

    ProviderDecision -- Accept --> Confirmed[status = confirmed]
    ProviderDecision -- Decline --> Declined[status = declined]
    ProviderDecision -- No response in time --> AutoExpire[status = declined - auto-expired]

    Confirmed --> PaymentStep{Customer pays?}
    PaymentStep -- Yes --> PaymentProcessing[Process payment via PayFast]
    PaymentProcessing --> PaymentResult{Payment successful?}
    PaymentResult -- Yes --> InProgress[status = in_progress on appointment day]
    PaymentResult -- No --> RetryPay[Notify customer, allow retry]
    RetryPay --> PaymentStep
    PaymentStep -- Cancel before paying --> Cancelled[status = cancelled]

    InProgress --> ServiceDelivered{Provider marks complete?}
    ServiceDelivered -- Yes --> Completed[status = completed]
    Completed --> ReviewPrompt[Prompt customer for review]
    ReviewPrompt --> End([End])

    Confirmed --> CancelOption{Either party cancels?}
    CancelOption -- Yes --> Cancelled
    Cancelled --> End
    Declined --> End
    AutoExpire --> End
```

## 5. Assumptions
- Providers who do not respond to a booking request within a configurable window (e.g., 24 hours) result in an automatic decline to avoid indefinitely pending requests.

## 6. Constraints
- Cancellation activity does not model partial refunds; refund policy application is handled by the Payment Service and Admin dispute process where applicable.

## 7. Future Enhancements
- Add a "Reschedule" branch showing the loop back to `pending` for re-confirmation.
