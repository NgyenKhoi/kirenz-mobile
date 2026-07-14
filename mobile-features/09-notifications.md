# Feature 09: Notifications

## Scope And Dependencies

Includes social notification list, unread badge, mark one/all read, realtime insertion/count, foreground in-app banner, target routing, cache/offline display, and separation from chat unread.

## Contract Readiness

Status: social REST/realtime list, canonical count, read actions, routing, and foreground/local presentation are `Ready for mobile`. Push delivery, device tokens, and preferences remain `Backend gap`.


Depends on Feature 01 and routes from Features 02-04. Push/FCM remains post-MVP.

## Current Web Behavior To Preserve

- Web loads notification rows and unread count independently.
- Notification drawer shows actor avatar, message, time, unread tint/dot, Mark read, and Close.
- Realtime uses a dedicated SockJS/STOMP connection.
- `/user/queue/notifications` prepends a new row.
- `/user/queue/notifications/unread-count` replaces the badge count.
- Tapping unread notification marks it read, closes drawer, and routes:
  - FRIEND_REQUEST -> friends/profile friends surface.
  - FRIEND_ACCEPT/BIRTHDAY -> target profile.
  - POST_COMMENT/POST_LIKE/COMMENT_REPLY/POST_MENTION/COMMENT_MENTION -> target post.
  - WELCOME -> settings.
- Mark all read changes every row and count.
- Chat badge is calculated from conversation unread counts, separate from social notification count.

Web and mobile both merge topic rows by notification id and sort by `createdAt`; a duplicate event replaces its row instead of incrementing count or creating another presentation.

## Backend Contracts

| Action | Contract |
| --- | --- |
| List | `GET /api/notifications`. |
| Count | `GET /api/notifications/unread-count`. |
| Mark one | `PATCH /api/notifications/{id}/read`. |
| Mark all | `PATCH /api/notifications/read-all`. |
| New/update row | `/user/queue/notifications`. |
| Canonical count | `/user/queue/notifications/unread-count` -> `{ count }`. |

Validated separation rule:

- Notification Service no longer consumes `message-sent` into social rows.
- REST list, unread count, and mark-all exclude legacy `MESSAGE` rows already stored in the database.
- The `MESSAGE` enum remains only for backward compatibility and is not part of the mobile social-notification union.
- Chat unread and foreground chat alerts come from Chat Service conversation/user-queue state.


Exact social row and count payloads:

```text
NotificationResponse
{ id, receiverId, actorId, actorName, actorAvatar, type, targetId, message, isRead, createdAt }

UnreadCountQueuePayload
{ count }
```

Mobile social `type` union is `FRIEND_REQUEST`, `FRIEND_ACCEPT`, `POST_COMMENT`, `POST_LIKE`, `COMMENT_REPLY`, `POST_MENTION`, `COMMENT_MENTION`, `BIRTHDAY`, and `WELCOME`.

REST unread-count `data` is a number. The WebSocket unread-count queue sends `{ count }`; do not deserialize both through one DTO shape.

Notification list is currently unpaginated.

## Route And Screen

- `/notifications` is a full mobile list screen, not only a drawer.
- App bar: Alerts, unread count/Mark all read.
- Rows grouped by Today/Earlier only if grouping remains stable and simple.
- Pull refresh keeps content.
- Notification shell badge uses Notification Service count only.

## Notification Row

- Actor avatar/fallback.
- Actor name emphasized inside message where data supports it.
- Human-readable message.
- Relative timestamp.
- Type icon where helpful.
- Unread background tint plus dot/text semantics.
- Entire row taps target; actor avatar may route profile only if it does not make tap behavior confusing.

## Initial Load And Realtime Merge

1. After session restore, fetch list and count.
2. Connect notification socket.
3. Subscribe to row and count queues.
4. Row event:
   - If id absent, insert at top.
   - If id present, replace in place and move only if timestamp/order requires.
5. Count event replaces local count; never increment blindly.
6. On reconnect/resume, fetch list/count before relying on new events.

Cache last rows for offline display with stale label.

## Read Behavior

Tap row:

1. If unread, mark locally only with rollback snapshot or wait for response.
2. Call mark one.
3. Reconcile pushed/REST count.
4. Navigate after success; if marking fails, user may still navigate but error/read state must remain truthful.

Mark all:

- Visible only when unread count > 0.
- Disable while pending.
- Preserve row/read/count snapshot.
- Success marks rows and accepts canonical count.
- Failure restores snapshot and shows error.

Do not allow duplicate realtime events to re-mark a row unread incorrectly.

## Target Routing

| Type | Mobile route |
| --- | --- |
| FRIEND_REQUEST | `/friends` incoming requests; actor profile fallback. |
| FRIEND_ACCEPT | `/profile/{actorId}`; current `targetId` is a friendship id and must not be used as a profile id. |
| POST_COMMENT, POST_LIKE, POST_MENTION | `/post/{targetId}`. |
| COMMENT_REPLY, COMMENT_MENTION | `/post/{targetId}`; highlight/scroll only if payload later includes comment id. |
| BIRTHDAY | `/profile/{actorId}`; `targetId` currently contains the same birthday user id as fallback. |
| WELCOME | Settings/profile onboarding destination. |

The current payload has one `targetId`, so route according to current producer semantics. A future `targetType`/comment id is a backend gap.

Deleted/private/blocked target:

- Keep notification row.
- Show friendly unavailable target.
- Do not loop/retry navigation.

## Foreground In-App Banner

- Show compact overlay for a new social notification while user is elsewhere.
- Avatar, one-line message, type/time, tap target.
- Swipe or auto-dismiss in 4-6 seconds.
- Deduplicate by notification id.
- Suppress when user is already viewing the exact target and the UI visibly updates.
- System notification permission does not affect this in-app banner/list.

Chat:

- Use chat user queue/local chat banner.
- Suppress chat banner in the active conversation.
- Never add a duplicate Notification Service social row just to create a chat alert.

## OS Local Notification And Permission Contract

This section covers device-local display driven by foreground/realtime events. It does not claim terminated/background remote delivery before FCM/APNs exists.

Permission flow:

1. Do not request system notification permission during splash or before the user understands the benefit.
2. Ask from an authenticated contextual prompt or Settings notification control.
3. On iOS, handle not-determined, provisional, authorized, denied, and restricted states.
4. On Android, request runtime permission only on API levels that require it and create versioned notification channels before display.
5. Denial never blocks the in-app list, badges, realtime updates, or foreground in-app banner.
6. After denial, explain how to open system settings; do not repeatedly prompt when the OS will not show a dialog.

Display and dedupe:

- Use stable social notification id or chat message id as the local notification identity.
- Social local alerts use Notification Service rows; chat local alerts use Chat Service message/conversation events.
- Suppress display while the exact target is active and visibly updated.
- A repeated socket/reconnect event updates/replaces the same local presentation rather than showing another alert.
- Never include access tokens, message body beyond approved preview, or private media URLs in local payload/logs.

Routing:

- Tapping a local alert uses the same target-routing table as the in-app row.
- Chat alerts route directly to `/chat/{conversationId}` using the chat event target.
- Missing/deleted/private targets open the friendly unavailable state.
- If app navigation is not ready, queue one sanitized pending destination until authenticated router bootstrap completes.

Manual acceptance covers permission granted, denied, provisional where available, system-settings return, exact-target suppression, duplicate-id replacement, and tap routing on supported Android/iOS targets.

## Push Boundary


FCM/APNs, device tokens, terminated delivery, and push deep links are not implemented by current backend. Keep these outside this feature until device-token/preferences endpoints exist.

## Behavior Completion Checklist

- [ ] List/count REST loads independently and recovers independently.
- [ ] Both socket queues merge by id and canonical count.
- [ ] Mark one/all preserve truthful state on failure.
- [ ] Every current notification type has a route or explicit fallback.
- [ ] Deleted/private targets produce unavailable state.
- [ ] Foreground banner deduplicates and suppresses exact active target.
- [ ] Chat and social unread/banners remain separate.
- [ ] OS permission grant/deny/settings-return and duplicate local-id behavior are accepted on available targets.
- [ ] Social local alerts and chat local alerts use separate canonical ids/sources.
- [ ] Push controls are absent until backend support exists.
