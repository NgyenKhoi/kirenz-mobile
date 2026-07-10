# Kirenz Mobile App Planning, Architecture, and Design

## 1. Purpose

This document defines the current plan for adding a Flutter + Dart mobile app to the Kirenz Platform.

The mobile app should reuse the existing microservice platform and API Gateway instead of introducing a separate mobile backend or separate mobile-owned database. The current web application already covers the main product surface: authentication, Google login, OTP verification, feed, explore, posts, comments, reactions, profiles, cover photos, friends, blocking, privacy, realtime chat, group chat management, media/file sharing, and in-app notifications.

Success means the mobile app reaches practical feature parity with the current web product while demonstrating Flutter/Dart mobile development fundamentals:

- Flutter widgets, layout, navigation, forms, and animations.
- Dart async programming with `Future`, `Stream`, `async`, and `await`.
- REST API integration through the API Gateway.
- JWT session handling with refresh tokens.
- Secure token storage and lightweight device-local cache.
- Realtime WebSocket/STOMP chat and notification subscriptions.
- Local notifications and a future push notification path.

## 2. Current Platform Baseline

The mobile app must call the API Gateway only. It must not connect directly to PostgreSQL, MongoDB, Redis, Eureka, Kafka, or individual backend service ports.

```text
Flutter app -> API Gateway -> backend services -> owned databases
```

Current backend services:

| Service | Current mobile role |
| --- | --- |
| API Gateway | Single mobile entry point for REST and WebSocket routes. |
| Identity Service | Email auth, Google auth, refresh token, OTP, profile, avatar, cover photo. |
| User Service | Friends, search, privacy settings, blocks, direct message permissions. |
| Social Service | Feed, explore, posts, comments, reactions, media upload for posts/chat. |
| Chat Service | Conversations, direct chat, group chat, nicknames, admins, presence, typing, chat media/files. |
| Notification Service | In-app social notifications and realtime notification delivery. |
| Discovery Service | Internal service discovery only. Mobile does not call it directly. |

Current backend database ownership:

| Service | Source-of-truth database | Mobile data access rule |
| --- | --- | --- |
| Identity Service | PostgreSQL `identity_db` | Mobile reads/writes identity and profile data through Gateway auth/user endpoints only. |
| User Service | PostgreSQL `user_db` | Mobile reads/writes friends, privacy, and blocks through Gateway user endpoints only. |
| Social Service | MongoDB `kirenz_social` | Mobile reads/writes posts, comments, reactions, and post media through Gateway social endpoints only. |
| Chat Service | MongoDB `kirenz_chat`; Redis for presence/typing | Mobile reads/writes conversations/messages through Gateway REST and `/ws/chat` only. |
| Notification Service | PostgreSQL `notification_db` | Mobile reads/writes notification state through Gateway notification endpoints and `/ws/notifications` only. |

Data sync principle:

- Web and mobile stay in sync because both clients use the same Gateway routes and the same backend services.
- PostgreSQL and MongoDB remain backend-owned sources of truth.
- The Flutter app may keep only a device-local cache for performance/offline display. That cache is not a separate source of truth and must be reconciled from backend API/WebSocket responses.

Current integration conventions:

| Concern | Current contract |
| --- | --- |
| REST base URL | `http://localhost:8080/api` in local web/dev flows. |
| Chat WebSocket | Gateway path `/ws/chat`. |
| Notification WebSocket | Gateway path `/ws/notifications`. |
| Auth | Kirenz JWT access token + refresh token. |
| Google login | Client gets Google `id_token`, backend verifies it through `/api/auth/google`. |
| API response | `ApiResponse<T>` with `success`, `message`, and `data`. |
| Uploads | Multipart uploads for post media, chat media/files, avatar, and cover photo. |
| Source of truth | Backend-owned PostgreSQL/MongoDB per service boundary; mobile uses Gateway APIs only. |

## 3. Current Product State To Mirror

The mobile app should mirror the current web behavior rather than an older planning snapshot.

| Area | Current platform behavior |
| --- | --- |
| Auth | Email login/register, OTP verification, refresh token, Google login/linking, logout. |
| Profile | My profile, other profiles, edit profile, avatar upload, cover photo upload, privacy-aware viewing. |
| Feed | Home feed, create/edit/delete/share posts, media galleries, comments, reactions. |
| Explore | Discover public/social content and users. |
| Friends | Search users, suggestions, requests, friend status, friend list. |
| Privacy/Blocks | Privacy settings, block/unblock, blocked user warning in group chat. |
| Chat | Direct and group conversations, text/media/file messages, PDF/DOCX support, typing, presence. |
| Group chat | Rename group, add users, kick users, leave group, delete group, make admin, nicknames. |
| Chat history | Messages remain attributed to kicked users by resolving sender profiles from message sender IDs. |
| Chat system events | Nickname changes and users leaving groups appear as in-conversation system messages. |
| Message notifications | Chat updates are handled by realtime conversation/user queue badges, not notification-service social notifications. |
| Notifications | Social notifications list, unread count, mark read/read all, realtime drawer updates. |

## 4. Mobile MVP Scope

The first mobile release should include:

| Area | Screens / capabilities |
| --- | --- |
| Auth | Splash, login, register, OTP verification, Google login, refresh session, logout. |
| Home Feed | Feed list, create post, media upload, post actions, comments, reactions. |
| Explore | Explore content/users with search and post cards. |
| Profile | My profile, edit profile, avatar/cover upload, other user profile, photos/friends tabs. |
| Friends | Search, suggestions, requests, accept/decline/cancel, friend list. |
| Privacy and Blocks | Privacy settings, block/unblock, blocked users list. |
| Chat | Conversation list, direct chat, group chat, message history, send text/images/videos/PDF/DOCX. |
| Group Chat Management | Add members, kick members, leave/delete group with confirm dialogs, admin and nickname actions. |
| Notifications | Notification list, unread count, mark read/read all, realtime in-app updates. |
| Local Data | Secure token storage, preferences, lightweight feed/chat/notification cache. |

Post-MVP scope:

- Push notifications through FCM/APNs.
- Deep links from notifications.
- Offline drafts and background sync.
- Media compression before upload.
- Rich delivery/read status UI.
- Biometric app lock.
- Stories only if the product brings that feature back.

## 5. Recommended Flutter Architecture

Use feature-first Clean Architecture with Riverpod.

```text
mobile/
|-- lib/
|   |-- main.dart
|   |-- app/
|   |   |-- kirenz_app.dart
|   |   |-- router.dart
|   |   |-- theme.dart
|   |   `-- bootstrap.dart
|   |-- core/
|   |   |-- config/
|   |   |-- constants/
|   |   |-- errors/
|   |   |-- network/
|   |   |-- storage/
|   |   |-- local_cache/
|   |   |-- websocket/
|   |   `-- notifications/
|   |-- features/
|   |   |-- auth/
|   |   |-- feed/
|   |   |-- explore/
|   |   |-- post/
|   |   |-- profile/
|   |   |-- friends/
|   |   |-- privacy/
|   |   |-- chat/
|   |   `-- notifications/
|   `-- shared/
|       |-- widgets/
|       |-- models/
|       |-- utils/
|       `-- validators/
|-- test/
|-- integration_test/
`-- pubspec.yaml
```

Each feature should use:

```text
feature_name/
|-- data/
|   |-- datasources/
|   |-- dto/
|   `-- repositories/
|-- domain/
|   |-- entities/
|   |-- repositories/
|   `-- usecases/
`-- presentation/
    |-- controllers/
    |-- screens/
    `-- widgets/
```

## 6. Recommended Flutter/Dart Stack

| Concern | Recommendation |
| --- | --- |
| State management | `flutter_riverpod`. |
| Navigation | `go_router` with auth guards and shell navigation. |
| HTTP | `dio` with token interceptors, refresh retry, and multipart support. |
| Models | `freezed` + `json_serializable`. |
| Secure storage | `flutter_secure_storage` for access/refresh tokens. |
| Preferences | `shared_preferences` for theme, locale, onboarding, last tab. |
| Device-local cache | Prefer `drift` for typed SQLite cache used only for offline reads and UI performance. |
| WebSocket/STOMP | Mobile-compatible STOMP client. |
| Media picking | `image_picker` or platform media picker. |
| Image cache | `cached_network_image`. |
| Local notifications | `flutter_local_notifications`. |
| Push notifications | Firebase Cloud Messaging after backend device token endpoints exist. |
| Logging | `talker` or a small environment-aware logger. |

## 7. API Integration Design

### Base Configuration

| Environment | API base |
| --- | --- |
| Local Android emulator | `http://10.0.2.2:8080/api` |
| Local iOS simulator | `http://localhost:8080/api` |
| LAN device testing | `http://<developer-machine-ip>:8080/api` |
| Production | `https://api.kirenz.example/api` |

Use Dart compile-time variables:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080/api
```

### Endpoint Groups

| Mobile repository | Gateway endpoints |
| --- | --- |
| `AuthRepository` | `/auth/register`, `/auth/login`, `/auth/google`, `/auth/refresh`, `/verification/**` |
| `ProfileRepository` | `/users/me`, `/users/{id}`, `/users/me/avatar`, `/users/me/cover` |
| `FriendRepository` | `/friends/**`, `/users/search`, `/users/{id}/mutual-friends` |
| `PrivacyRepository` | `/privacy/**` |
| `BlockRepository` | `/blocks/**` |
| `PostRepository` | `/posts/**`, `/comments/**`, `/media/posts` |
| `ExploreRepository` | Current explore/search/feed discovery endpoints exposed through gateway. |
| `ChatRepository` | `/conversations/**`, `/messages/**`, `/presence/**`, `/media/chat` |
| `NotificationRepository` | `/notifications/**` |

### Google Login Flow

```text
Flutter Google Sign-In
-> receive Google idToken
-> POST /api/auth/google { idToken }
-> Identity Service verifies token and audience
-> Identity Service links or creates user by google_id/email
-> backend returns Kirenz accessToken + refreshToken
```

Rules:

- Flutter stores Kirenz tokens, not Google tokens.
- Email/password and OTP remain supported.
- If Google email matches an existing account, backend links `google_id` when allowed.

### HTTP Client Rules

- Attach `Authorization: Bearer <accessToken>` for protected APIs.
- Refresh token once on `401`.
- Queue concurrent failed requests while refresh is in progress.
- Clear session and navigate to login if refresh fails.
- Normalize `ApiResponse<T>` and backend error responses.
- Support multipart upload for avatar, cover, post media, and chat media/files.

## 8. State Management Design

Use Riverpod providers by responsibility:

| Provider | Responsibility |
| --- | --- |
| `authControllerProvider` | Login, register, OTP, Google login, refresh, logout, bootstrap current user. |
| `sessionProvider` | Tokens and authenticated user state. |
| `feedControllerProvider` | Feed pagination, create/edit/delete/share posts. |
| `exploreControllerProvider` | Explore content and user discovery. |
| `postDetailControllerProvider` | Comments, reactions, post detail actions. |
| `profileControllerProvider` | Profile load/update and avatar/cover upload. |
| `friendControllerProvider` | Requests, suggestions, friend status. |
| `privacyControllerProvider` | Privacy settings and block workflows. |
| `chatControllerProvider` | Conversations, selected conversation, messages, group actions. |
| `webSocketProvider` | STOMP connection lifecycle and subscriptions. |
| `notificationControllerProvider` | Notification list, unread count, realtime updates. |
| `appSettingsProvider` | Theme, locale, preferences. |

Rules:

- Server state should be represented as `AsyncValue<T>`.
- UI screens should not call `Dio` directly.
- Repositories own network/cache decisions.
- Realtime events update in-memory state and local cache where useful.

## 9. Navigation Design

Use `go_router`.

```text
/splash
/login
/register
/verify-otp

/home
/explore
/post/:postId
/profile/me
/profile/:userId
/friends
/privacy
/blocked-users
/chat
/chat/:conversationId
/notifications
/settings
```

Authenticated shell tabs:

| Tab | Route | Purpose |
| --- | --- | --- |
| Home | `/home` | Feed and composer entry. |
| Explore | `/explore` | Discovery and search. |
| Friends | `/friends` | Social graph workflows. |
| Chat | `/chat` | Conversation list and messages. |
| Notifications | `/notifications` | In-app notifications. |
| Profile | `/profile/me` | Current user profile. |

## 10. Chat Design

Mobile should connect to:

```text
ws://<gateway-host>/ws/chat
```

STOMP headers:

```text
Authorization: Bearer <accessToken>
```

Subscriptions:

| Destination | Use |
| --- | --- |
| `/user/queue/messages` | Conversation list updates and unread badges. |
| `/topic/presence` | Online/offline presence. |
| `/topic/conversation.{conversationId}` | Full messages for the open conversation. |
| `/topic/conversation.{conversationId}.typing` | Typing indicator. |

Publish destinations:

| Destination | Body |
| --- | --- |
| `/app/chat.send` | `conversationId`, `content`, `attachments`. |
| `/app/chat.typing` | `conversationId`, `isTyping`. |

Chat implementation notes:

- Chat media supports image, video, PDF, and DOCX attachments.
- Downloads should preserve original file names from attachment metadata where available.
- Group management must support add, kick, leave, delete, make admin, and nicknames.
- Destructive actions must use confirm dialogs.
- Nickname changes and leave events should render as system messages in the conversation.
- Message history must display sender profile from `senderId`, even if the sender has been kicked from the group.
- Message alerts should be handled by chat realtime badges/popup state rather than social notification records.

## 11. Notification Design

### In-App Notifications

MVP:

- Load notification list from `/api/notifications`.
- Show unread badge in the notifications tab.
- Mark one notification as read.
- Mark all as read.
- Listen to notification WebSocket updates.
- Keep chat message updates in chat realtime state, not notification-service social notification rows.

### Local Notifications

Use local notifications for foreground/background user-visible alerts after mobile permissions are implemented. Prioritize:

- Friend request received/accepted.
- Comment/reaction alerts.
- Mention alerts if backend emits mention events.
- Chat alerts only when the user is not currently viewing the relevant conversation.

### Push Notifications

Post-MVP:

- Add Firebase Cloud Messaging.
- Register device token after login.
- Add backend device token endpoints.
- Store per-device notification preferences.
- Send push only when user is offline/backgrounded where possible.
- Deep link to post, profile, conversation, or notification list.

Backend additions required for full push:

```text
POST /api/notifications/devices
DELETE /api/notifications/devices/{deviceToken}
PATCH /api/notifications/preferences
```

## 12. Local Storage and Offline Design

### Secure Storage

Store:

- Access token.
- Refresh token.
- Current user id.

Do not store tokens in `SharedPreferences`.

### SharedPreferences

Store:

- Theme mode.
- Locale.
- First-run/onboarding flag.
- Last selected tab.
- Last successful API environment for debug builds.

### Device-Local SQLite Cache

The mobile cache is not a backend database and must not replace PostgreSQL or MongoDB. Backend data remains owned by the existing microservices:

- PostgreSQL: identity, profile/account fields, friendships, privacy, blocks, notifications.
- MongoDB: posts, comments, reactions, conversations, messages.
- Redis: short-lived chat presence and typing state.

The cache stores copies of selected API/WebSocket responses for fast rendering and limited offline display.

| Table | Purpose |
| --- | --- |
| `cached_posts` | Feed, explore, and profile post previews. |
| `cached_comments` | Recent comments for opened posts. |
| `cached_conversations` | Conversation list and unread state. |
| `cached_messages` | Recent messages per conversation, including sender profile snapshot. |
| `cached_notifications` | Notification list and read state. |
| `outbox_actions` | Optional future queue for offline posts/comments/messages. |

MVP offline behavior:

- Show cached conversations/messages when offline.
- Show cached feed/profile/explore if available.
- Disable network-only actions except local drafts.
- Retry failed actions manually from UI.
- Refresh cached data from the Gateway after reconnect so web and mobile converge on the same PostgreSQL/MongoDB-backed state.

## 13. UI/UX Direction

Kirenz mobile should feel like a social app, not a direct web port.

Design principles:

- Bottom tab navigation for primary screens.
- Feed optimized for one-handed scrolling.
- Stable composer pinned to the bottom in chat.
- Clean cards, clear spacing, and polished empty/loading/error states.
- Confirm dialogs for destructive actions.
- Media thumbnails with full-screen preview and download actions.
- Pull-to-refresh on feed, explore, notifications, conversations, friends, and profile tabs.
- Skeleton loaders for feed/profile/chat list.
- Native platform permission flows for photos, camera, and notifications.

Core widgets:

| Widget | Use |
| --- | --- |
| `Scaffold` | Screen structure. |
| `CustomScrollView` / `SliverList` | Feed, explore, profile tabs. |
| `RefreshIndicator` | Pull-to-refresh. |
| `ListView.builder` | Conversations, friends, notifications. |
| `Form` / `TextFormField` | Auth/profile/post/comment/message forms. |
| `NavigationBar` | Main app tabs. |
| `ModalBottomSheet` | Post actions, media picker, privacy selector, reactions, group actions. |
| `Hero` | Media/profile image transitions. |
| `AnimatedSwitcher` | Empty/loading/content transitions. |

## 14. Implementation Roadmap

### Phase 0 - Planning Baseline

Status: done. Current document updated to match current web/backend progress.

Deliverables:

- Current feature parity target documented.
- API Gateway-only rule confirmed.
- Backend PostgreSQL/MongoDB ownership confirmed; mobile uses these databases indirectly through existing services.
- Realtime chat and notification behavior clarified.
- Mobile architecture and stack selected.

### Phase 1 - Flutter Foundation

Goal: create runnable Flutter app shell.

Tasks:

- Create `mobile/` Flutter project.
- Configure Android/iOS app ids.
- Add `--dart-define` environment config.
- Add theme, router, auth guard, and bottom tabs.
- Add linting/code generation setup.
- Add feature-first folder structure.

### Phase 2 - Auth and Session

Goal: complete authentication flow.

Tasks:

- Dio client with token interceptor and refresh queue.
- Login/register/refresh.
- OTP send/verify.
- Google login through `/api/auth/google`.
- Secure token storage.
- Session restore on app start.
- Logout clears tokens and disconnects realtime services.

### Phase 3 - Profile, Friends, Privacy, Blocks

Goal: complete relationship and profile workflows.

Tasks:

- Current and other user profile screens.
- Edit profile.
- Avatar and cover upload.
- Friend request lifecycle.
- Search and suggestions.
- Privacy settings.
- Block/unblock and blocked users list.

### Phase 4 - Feed, Explore, and Social Content

Goal: complete social content core.

Tasks:

- Feed pagination and pull-to-refresh.
- Explore screen.
- Create/edit/delete/share post.
- Upload post media.
- Post detail.
- Comments and replies.
- Reactions for posts and comments.
- Device-local cache for feed/explore/opened post details.

### Phase 5 - Chat and Presence

Goal: complete realtime messaging.

Tasks:

- Conversation list.
- Direct conversation creation.
- Group conversation management.
- Message history pagination.
- Send text/image/video/PDF/DOCX.
- STOMP connection and reconnect.
- Conversation, typing, user queue, and presence subscriptions.
- Device-local cache for conversations/messages.

### Phase 6 - Notifications

Goal: complete in-app and local notification flow.

Tasks:

- Notification list.
- Unread badge.
- Mark read/read all.
- Realtime notification subscription.
- Local notification display while foregrounded.
- Notification permission flow.

### Phase 7 - Push Notifications

Goal: enable background notifications.

Tasks:

- Add Firebase project setup.
- Add FCM/APNs integration.
- Add backend device token registration endpoints.
- Store per-device notification preferences.
- Send push notification from Notification Service.
- Add deep link routing.

### Phase 8 - Stabilization and Release

Goal: prepare for demo or production-like release.

Tasks:

- Error and loading polish.
- Media compression.
- App icon and splash screen.
- Android release signing.
- iOS signing profile.
- Integration tests for critical flows.
- Performance checks for feed, explore, profile, and chat.

## 15. Two-Person Implementation Plan

This project should be implemented by two people with clear ownership boundaries. Both people should use the same feature-first architecture and open small PRs by phase.

| Phase | Person A ownership | Person B ownership | Shared handoff / merge point |
| --- | --- | --- | --- |
| Phase 0 - Planning Baseline | Keep mobile requirements aligned with auth, profile, friends, privacy, feed, and explore APIs. | Keep mobile requirements aligned with chat, notification, storage, and release needs. | Update planning docs before implementation starts. |
| Phase 1 - Flutter Foundation | App bootstrap, theme, router, auth guard, bottom navigation, lint rules. | Feature folder structure, placeholder screens, app ids, app labels, first widget tests. | App runs, analyzes, and tests pass before Phase 2. |
| Phase 2 - Auth and Session | Auth UI, validation, login, register, OTP screens, Google login entry. | Dio client, token interceptor, refresh queue, secure storage, session restore/logout. | Auth controller exposes one stable session state consumed by router and UI. |
| Phase 3 - Profile, Friends, Privacy, Blocks | Profile screens, edit profile, avatar/cover upload, profile tabs. | Friends, requests, search, privacy settings, block/unblock workflows. | Relationship status and privacy state are reusable across profile, friends, and chat. |
| Phase 4 - Feed, Explore, and Social Content | Feed list, pagination, post cards, post composer, media upload. | Explore, post detail, comments, replies, reactions, share/edit/delete actions. | Post DTOs/entities and cache models are shared between feed, explore, profile, and detail. |
| Phase 5 - Chat and Presence | Conversation list, direct/group chat UI, message composer, attachments UI. | STOMP lifecycle, message history, typing, presence, group management actions, chat cache. | Chat state updates conversation badges and active conversation without social notification rows. |
| Phase 6 - Notifications | Notification list, unread badge, mark read/read all UI. | Notification WebSocket, local notification permission/display, foreground alert rules. | Notification state integrates with shell badges and avoids duplicating chat message alerts. |
| Phase 7 - Push Notifications | Device permission UX, deep link destinations, notification preferences UI. | FCM/APNs setup, device token registration client, backend contract validation. | Push payloads route to post, profile, conversation, or notification list. |
| Phase 8 - Stabilization and Release | UI polish, error/empty/loading states, integration tests for auth/feed/profile. | Media compression, app icon/splash, release signing, integration tests for chat/notifications. | Release candidate passes manual QA on Android emulator/device and iOS simulator/device where available. |

Recommended parallel workflow:

- Person A starts with user-facing screens and controller boundaries.
- Person B starts with infrastructure, API clients, device-local cache, and realtime.
- Shared models and route names must be agreed before each phase begins.
- Each phase should end with `flutter analyze`, a successful local run/build, and manual smoke checks. Automated tests are optional for now and should only be added when they remove real risk.
- If both people touch the same feature, Person A owns `presentation` and Person B owns `data` plus `domain` unless agreed otherwise.
- PRs should be phase-scoped and avoid mixing unrelated UI polish with API infrastructure.

## 16. Testing Strategy

| Test type | Scope |
| --- | --- |
| Unit tests | Validators, use cases, DTO parsing, repositories with mocked clients. |
| Provider/controller tests | Auth state, feed pagination, profile, chat state, notification state. |
| Widget tests | Login form, feed card, post composer, chat composer, notification item. |
| Integration tests | Login, create post, comment, send message, group action, receive notification. |
| Manual QA | Media permissions, downloads, notification permissions, background/foreground transitions. |

## 17. Backend Gaps For Full Mobile Support

Most current web flows can be reused. Remaining mobile-specific backend work:

| Gap | Required backend work |
| --- | --- |
| Push notifications | Device token registration and push provider integration. |
| Mobile notification preferences | Per-user/per-device preferences. |
| Deep links | Notification payload contract with target type and target id. |
| Offline sync | Optional idempotency keys for create post/comment/message. |
| Media optimization | Optional server-side compression/thumbnail variants and clear validation responses. |

## 18. Definition of Done

Planning is successful when:

- The mobile architecture is documented and approved.
- Feature parity matches current web/backend progress.
- Mobile data sync strategy uses the existing backend-owned PostgreSQL and MongoDB databases through API Gateway/microservices.
- REST, WebSocket, storage, and notification designs are clear.
- The team can start Phase 1 without re-deciding structure.

Implementation is complete when:

- Flutter app supports auth, profile, explore, feed, friends, privacy, chat, and notifications.
- Web and mobile users interact with the same backend data.
- Mobile handles token refresh, local cache, realtime reconnects, and notification permissions.
- Core tests and manual QA pass on Android and iOS.
