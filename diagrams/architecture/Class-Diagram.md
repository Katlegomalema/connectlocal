# Class Diagram — ConnectLocal Backend Domain Model

## 1. Introduction
Presents the core domain classes of the ConnectLocal backend service layer and their relationships, independent of persistence or transport concerns.

## 2. Purpose
To guide object-oriented/module design of the service layer described in `Backend-Architecture.md`, ensuring consistent modeling of domain concepts across the codebase.

## 3. Scope
Covers primary domain entities and key service classes. Utility/infrastructure classes (loggers, config loaders) are omitted for clarity.

## 4. Diagram

```mermaid
classDiagram
    class User {
        +UUID id
        +String email
        +String fullName
        +Role role
        +Boolean isEmailVerified
        +Boolean isPhoneVerified
        +AccountStatus status
        +verify()
        +suspend()
    }

    class Provider {
        +UUID id
        +UUID userId
        +String businessName
        +String category
        +GeoPoint location
        +VerificationStatus verificationStatus
        +Float averageRating
        +submitVerification(doc)
        +addService(service)
        +updateAvailability(schedule)
    }

    class Service {
        +UUID id
        +UUID providerId
        +String title
        +Decimal price
        +Int durationMinutes
        +Boolean isActive
        +deactivate()
    }

    class Booking {
        +UUID id
        +UUID customerId
        +UUID providerId
        +UUID serviceId
        +DateTime scheduledStart
        +BookingStatus status
        +Decimal totalPrice
        +accept()
        +decline(reason)
        +cancel(reason)
        +reschedule(newTime)
        +markComplete()
    }

    class Payment {
        +UUID id
        +UUID bookingId
        +Decimal amount
        +PaymentStatus status
        +initiate()
        +confirmFromITN(payload)
    }

    class Review {
        +UUID id
        +UUID bookingId
        +Int rating
        +String comment
        +ModerationStatus moderationStatus
        +respond(text)
        +moderate(action)
    }

    class Conversation {
        +UUID id
        +UUID userAId
        +UUID userBId
        +sendMessage(senderId, text)
    }

    class Message {
        +UUID id
        +UUID conversationId
        +UUID senderId
        +String body
        +MessageStatus status
        +markRead()
    }

    class Notification {
        +UUID id
        +UUID userId
        +String type
        +Boolean isRead
        +markRead()
    }

    class BookingService {
        +createBooking(customerId, serviceId, time)
        +respondToBooking(bookingId, action)
        +checkAvailability(providerId, time)
    }

    class PaymentService {
        +initiatePayment(bookingId)
        +handleITN(payload)
    }

    User "1" --> "0..1" Provider : becomes
    Provider "1" --> "*" Service : offers
    User "1" --> "*" Booking : places
    Provider "1" --> "*" Booking : receives
    Service "1" --> "*" Booking : bookedAs
    Booking "1" --> "0..1" Payment : settledBy
    Booking "1" --> "0..1" Review : reviewedVia
    User "1" --> "*" Conversation : participates
    Conversation "1" --> "*" Message : contains
    User "1" --> "*" Notification : receives
    BookingService ..> Booking : manages
    PaymentService ..> Payment : manages
```

## 5. Assumptions
- The domain model favors composition and explicit state transitions (methods like `accept()`, `cancel()`) over anemic data classes, aligning with the service-layer pattern in the backend architecture.

## 6. Constraints
- Diagram represents logical domain classes; actual JavaScript implementation uses plain objects and service functions rather than formal classes, per the project's pragmatic Node.js conventions.

## 7. Future Enhancements
- Introduction of a `Dispute` domain class as dispute-handling logic matures beyond simple admin-recorded resolutions.
