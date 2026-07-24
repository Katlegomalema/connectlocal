# Messaging API — ConnectLocal

## 1. Introduction
Specifies endpoints and real-time channels for in-app messaging between customers and providers. All REST endpoints are prefixed `/api/v1/messages`; real-time delivery uses Supabase Realtime channels.

## 2. Purpose
To define how conversations and messages are created, retrieved, and delivered in near real-time.

## 3. Scope
Covers conversation listing, message history retrieval, and message sending. Real-time subscription mechanics are documented at the architecture level (see Sequence Diagrams).

## 4. Detailed Content

### 4.1 List Conversations
- **URL:** `/api/v1/conversations`
- **Method:** `GET`
- **Auth Required:** Yes

**Response Body (200 OK)**
```json
{
  "success": true,
  "data": {
    "results": [
      {
        "conversationId": "conv-4471",
        "participant": { "id": "c3e1a9f0-...", "name": "Mokoena Plumbing Services" },
        "lastMessage": { "text": "Sure, I can be there at 9am.", "sentAt": "2026-08-01T14:22:00Z" },
        "unreadCount": 2
      }
    ]
  },
  "error": null
}
```

**Status Codes**
| Code | Meaning |
|---|---|
| 200 | Conversations returned |
| 401 | Not authenticated |

---

### 4.2 Get/Create Conversation
- **URL:** `/api/v1/conversations`
- **Method:** `POST`
- **Auth Required:** Yes
- **Description:** Returns an existing conversation between the current user and the target, or creates one if none exists.

**Request Body**
```json
{ "participantId": "c3e1a9f0-...", "bookingId": "bk-2026-00892" }
```

**Response Body (200 OK / 201 Created)**
```json
{ "success": true, "data": { "conversationId": "conv-4471" }, "error": null }
```

**Status Codes**
| Code | Meaning |
|---|---|
| 200 | Existing conversation returned |
| 201 | New conversation created |
| 400 | Invalid participant |

---

### 4.3 Get Message History
- **URL:** `/api/v1/conversations/:conversationId/messages`
- **Method:** `GET`
- **Auth Required:** Yes (participant only)
- **Query Parameters:** `before` (cursor timestamp), `limit` (default 50)

**Response Body (200 OK)**
```json
{
  "success": true,
  "data": {
    "results": [
      { "messageId": "msg-9001", "senderId": "8b1b6f2e-...", "text": "Hi, are you available on Wednesday?", "sentAt": "2026-08-01T14:20:00Z", "status": "read" },
      { "messageId": "msg-9002", "senderId": "c3e1a9f0-...", "text": "Sure, I can be there at 9am.", "sentAt": "2026-08-01T14:22:00Z", "status": "delivered" }
    ],
    "hasMore": false
  },
  "error": null
}
```

**Status Codes**
| Code | Meaning |
|---|---|
| 200 | Message history returned |
| 403 | Not a participant in this conversation |

---

### 4.4 Send Message
- **URL:** `/api/v1/conversations/:conversationId/messages`
- **Method:** `POST`
- **Auth Required:** Yes (participant only)

**Request Body**
```json
{ "text": "Great, see you then!" }
```

**Response Body (201 Created)**
```json
{
  "success": true,
  "data": { "messageId": "msg-9003", "sentAt": "2026-08-01T14:25:00Z", "status": "sent" },
  "error": null
}
```

**Status Codes**
| Code | Meaning |
|---|---|
| 201 | Message persisted and broadcast via Realtime |
| 400 | Empty/invalid message |
| 403 | Not a participant |

---

### 4.5 Mark Messages as Read
- **URL:** `/api/v1/conversations/:conversationId/read`
- **Method:** `PATCH`
- **Auth Required:** Yes (participant only)

**Response Body (200 OK)**
```json
{ "success": true, "data": { "markedRead": 2 }, "error": null }
```

**Status Codes**
| Code | Meaning |
|---|---|
| 200 | Unread messages marked as read |

### 4.6 Real-Time Delivery
New messages are broadcast on a Supabase Realtime channel scoped to the conversation (`realtime:conversation:{conversationId}`). Clients subscribe on entering the conversation screen and unsubscribe on exit, falling back to polling `GET /messages` if the Realtime connection is unavailable.

## 5. Assumptions
- Message text is limited to plain text in the current scope; media attachments are a future enhancement.

## 6. Constraints
- Message length capped at 2,000 characters server-side.

## 7. Future Enhancements
- Image/document attachments in messages.
- Typing indicators and read receipts at the individual-message granularity.
