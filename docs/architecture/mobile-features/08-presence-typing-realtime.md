# Feature 08: Presence, Typing, and Realtime Lifecycle

## Scope And Dependencies

Defines authenticated STOMP connection, chat subscriptions, presence snapshot/events, typing events, reconnect, token/session changes, app lifecycle, and state reconciliation.

## Contract Readiness

Status: destinations and event semantics are source-validated, but mobile release remains behind a `Transport gate` until SockJS/native STOMP, CONNECT authorization, heartbeat, reconnect, and token replacement pass through Gateway on Android and iOS.


Depends on Features 01 and 06. It provides the connection interface required by Feature 07, removing the previous circular dependency.

## Current Web Behavior To Preserve

- Chat connects using SockJS + STOMP through `/ws/chat` with Bearer token in CONNECT headers.
- Subscriptions are restored after reconnect.
- User queue updates conversation last message/unread/order.
- Open conversation subscribes to full message and typing topics.
- Presence first loads a bulk REST snapshot for conversation participants, then merges global topic events.
- Presence format:
  - Online.
  - Offline when unknown.
  - Active just now.
  - Active Nm ago.
  - Active Nh ago.
  - Active Nd ago.
- Web sends typing true while non-empty input changes, false after 1.5 seconds idle.
- Remote typing state has a three-second stale timeout.
- Multiple sessions keep a user online until the final active socket disconnects.

## Transport Contract

Gateway paths:

- Chat SockJS/STOMP: `/ws/chat`.
- Notification SockJS/STOMP: `/ws/notifications`.

Chat subscriptions:

- `/user/queue/messages`
- `/topic/presence`
- `/topic/conversation.{conversationId}`
- `/topic/conversation.{conversationId}.typing`

Chat publishes:

- `/app/chat.send`
- `/app/chat.typing`

Exact wire shapes that must be normalized into separate DTOs:

```text
GET /api/presence/status?userIds=...
data = Map<UUID, UserPresenceDto>
UserPresenceDto { isOnline, lastSeen }

/topic/presence
PresenceEvent { userId, status, lastSeen }
status = ONLINE | OFFLINE

/app/chat.typing publish
TypingRequest { conversationId, isTyping }

/topic/conversation.{conversationId}.typing
TypingEvent { userId, isTyping }
```

The typing event conversation id is derived from the subscribed topic, not from its payload. `lastSeen` is epoch milliseconds and nullable in the REST snapshot. Do not deserialize the REST boolean shape and the realtime string-status shape into the same wire DTO; normalize both into one domain presence state after validation. Unknown presence statuses must trigger reconciliation, not an optimistic online value.

## Required Transport Decision

Before feature implementation is considered usable:

1. Verify the selected Dart STOMP package supports the server's SockJS endpoint through Gateway.
2. If it requires native WebSocket, backend must expose a native STOMP endpoint. Do not point a raw WebSocket client at a SockJS base URL and assume compatibility.
3. Verify Bearer CONNECT headers, Gateway rewrite, heartbeat, reconnect, and token replacement on Android/iOS.
4. Store the final HTTP/HTTPS and WS/WSS construction in environment config.

This is a backend/integration decision, not a visual client workaround.

## Connection Lifecycle

```text
session authenticated
-> connect chat
-> subscribe user queue + presence
-> open conversation: subscribe message + typing

disconnect
-> mark connection degraded
-> bounded exponential backoff + jitter
-> reconnect
-> restore subscriptions
-> REST reconcile conversations/history/presence

logout/account change
-> unsubscribe all
-> disconnect chat + notifications
-> clear ephemeral state
```

- Only one connection manager instance per authenticated account.
- Prevent concurrent connect attempts.
- Use heartbeat values supported by server/client.
- Backoff is bounded; foreground manual Retry is available after repeated failure.
- Refresh token must update CONNECT token on the next connection.

## Conversation User Queue

On update:

- Find conversation by id.
- Replace lastMessage, updatedAt, unreadCount.
- Resort descending.
- If absent, refetch conversation list.
- Deduplicate event handling if multiple widgets observe the manager.
- Shell chat badge sums current map; it never uses Notification Service count.

## Open Conversation Subscription

- Subscribe after conversation authorization/detail succeeds.
- Unsubscribe when route changes.
- After reconnect, restore only the currently relevant conversation subscriptions.
- Merge topic message by id.
- Reconcile REST history after missed-connection window before assuming no messages were missed.

## Presence

Initial:

- Collect unique participant ids.
- Fetch `GET /api/presence/status?userIds=...` in bounded batches.
- Store by user id.

Realtime:

- Merge `{ userId, status, lastSeen }`.
- ONLINE clears stale last-seen display.
- OFFLINE stores provided epoch milliseconds.
- Direct rows/app bar update without rebuilding unrelated history.

Visibility:

- Respect `showOnlineStatus`/backend privacy response when enforcement exists.
- A dot must have semantic Online text.
- Group online-member count appears only when all needed statuses are loaded.

App lifecycle:

- On resume, refetch presence because background sockets may be suspended.
- Do not mark someone offline solely because the mobile client missed heartbeat/event.

## Typing

Local:

- Send true only after meaningful input begins and no more often than the chosen debounce/throttle.
- Send false after 1.5 seconds idle, send, clear input, lose focus, switch conversation, background, and disconnect when possible.
- Attach conversation id to every event.

Remote:

- Ignore current user.
- Key by conversation id + user id.
- Resolve nickname/display name from conversation participant.
- Clear false immediately.
- Clear true after three seconds without renewal.
- One user: `<name> is typing…`; multiple: concise names/Several people are typing.
- Never persist/cache typing.

## Connection UI

- Normal connected state has no banner.
- Connecting/reconnecting may show a quiet app-bar indicator.
- Disconnected shows Reconnecting and disables network send while preserving draft.
- Persistent failure exposes Retry; cached reading remains available.
- Do not show raw STOMP frames/errors.

## Behavior Completion Checklist

- [ ] Dart transport decision is explicit and proven through Gateway.
- [ ] Only one account-scoped connection manager exists.
- [ ] Subscriptions restore without duplicate callbacks.
- [ ] User queue and open topic merge by stable ids.
- [ ] Reconnect performs REST reconciliation for missed state.
- [ ] Presence combines snapshot/events and respects lifecycle/privacy.
- [ ] Typing start/stop/stale timeout cannot leak across conversations.
- [ ] Logout/account change clears sockets and ephemeral state.
