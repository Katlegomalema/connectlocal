# Notification API — ConnectLocal

All endpoints are prefixed `/api/v1/notifications`. Notification listing and device registration require a valid authenticated user token.

## Device registration

### Register or refresh a device token
- **Method:** `POST /devices`
- **Body:**

```json
{
  "token": "<Firebase Cloud Messaging device token>",
  "platform": "android"
}
```

`platform` must be `android`, `ios`, or `web`. Re-registering a token updates its user and platform association.

### Remove a device token
- **Method:** `DELETE /devices/:id`

The token is removed only if it belongs to the authenticated user.

## In-app notification center

- `GET /` lists the authenticated user's notifications. Use `unreadOnly=true`, `page`, and `limit` to filter and paginate.
- `PATCH /read-all` marks all of the user's notifications as read.
- `PATCH /:id/read` marks one of the user's notifications as read.
- `DELETE /:id` removes one of the user's notifications.

When server code creates an in-app notification, it also attempts FCM delivery to registered devices. The notification remains available in-app if no devices are registered. `is_pushed` is set when at least one device receives the push; invalid/expired FCM tokens are removed.

## Database and configuration

Apply `backend/migrations/202611030002_device_tokens.sql` before using device registration. Configure `FIREBASE_PROJECT_ID`, `FIREBASE_CLIENT_EMAIL`, and `FIREBASE_PRIVATE_KEY` to enable push delivery. Firebase delivery failures are surfaced to the caller; in-app notifications are persisted before the external push request.
