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

### 4.1 Implementation Readiness Audit

The feature names above are not sufficient by themselves to start implementation. The table below is the required traceability baseline as of this review. `Backend available` means a Gateway-routed contract exists in the current repository; it does not mean the Flutter screen has been implemented.

| Capability | Backend available now | Required mobile implementation | Remaining gap / decision |
| --- | --- | --- | --- |
| Send and verify email OTP | Yes: `POST /verification/send-otp`, `POST /verification/verify-otp`; registration also returns `otpSent`. OTP is six digits, valid for five minutes, and resend is rate-limited for 60 seconds. | Six-cell input, paste/autofill, countdown, resend, expired/invalid/rate-limit states, and verified success routing. | Mobile must not claim an OTP was sent when registration returns `otpSent=false`; email delivery still needs operational monitoring. |
| Avatar create/replace | Yes: multipart `POST /users/me/avatar`, image only, maximum 10 MB. | Pick/camera, crop square, preview, upload progress, retry, cache invalidation across profile/feed/chat. | Current endpoint replaces the avatar but there is no explicit delete endpoint. |
| Avatar delete/reset | No. | Show `Remove photo` only after the backend contract exists; use generated initials/default avatar after success. | Add `DELETE /users/me/avatar` and delete/retire the old Cloudinary asset safely. This is required before calling avatar support full CRUD. |
| Cover/banner create/replace | Yes: multipart `POST /users/me/cover`, image only, maximum 10 MB. `cover` is the backend name; `cover photo/banner` may be used in UI copy. | Pick, wide crop, preview, upload progress, retry, invalidate profile header cache. | No explicit delete/reset endpoint. |
| Cover/banner delete/reset | No. | Show `Remove cover` only after backend support exists; restore themed placeholder. | Add `DELETE /users/me/cover` with old asset cleanup. |
| Post CRUD | Yes: create, detail, edit, delete, share. | Composer/detail/action sheets, optimistic-safe mutations, confirmation, error recovery. | Current feed/user lists are unpaginated; add cursor/page contract before large-scale use. |
| Post media | Partly: upload image only through `/media/posts`, maximum 10 MB; post create/update stores media metadata. | Multi-select, preview grid, per-item X/remove, reorder if supported, progress/retry, gallery viewer. | Video post upload is not currently supported. Define max media count and orphan-upload cleanup. |
| Comments and replies | Yes: list/create/edit/delete; `parentCommentId` supports replies. | Detail screen or large sheet, reply target, edit/delete menus, nested rendering, composer focus behavior. | Current list is unpaginated and no dedicated single-comment endpoint exists. |
| Post/comment reactions | Yes: `LIKE`, `LOVE`, `HAHA`, `WOW`, `SAD`, `ANGRY`; summary, breakdown, current reaction, and reacting-user list are returned. | Long-press picker, tap current/default reaction, animated selection, breakdown sheet with filter tabs and user rows. | Reaction asset/emoji mapping and localized labels must be fixed in the design system. |
| Conversation CRUD/group actions | Mostly: create/list/detail, get-or-create direct, rename group, delete group, add/kick/leave, make admin, nickname. | Conversation list/detail/settings, role-aware actions, dialogs, cache updates, empty/error/loading states. | No generic rename/delete for direct conversations by design; no group avatar endpoint; clarify admin transfer when the last admin leaves. |
| Chat message/media | Yes: paged history, mark read, STOMP send, image/video/PDF/DOCX upload. | Draft preview tray, remove X, upload states, image grid in bubbles, fullscreen viewer, file tile/download, retry. | No REST fallback/idempotency/client message id, delivery/read receipt, edit/delete message endpoint, or upload cancellation contract. |
| Typing | Yes through conversation typing topic. | Debounce start, send stop after idle/submit/leave, hide self, timeout stale indicators. | Treat as ephemeral; never persist. |
| Presence/last seen | Yes: bulk REST snapshot plus `/topic/presence`; Redis tracks multiple sessions. | Initial batch fetch, realtime merge, online dot/last-seen text, lifecycle-aware reconnect. | Product privacy policy for exposing last seen is not defined; mobile should follow backend visibility when added. |
| Realtime social notifications | Yes: notification queue and unread-count queue plus REST list/read/read-all. | Realtime insert/dedupe, badge update, foreground presentation, target routing, cache reconciliation. | REST list is unpaginated. `MESSAGE` exists in the enum, but product rule says chat alerts must not create duplicate social-notification rows. |
| Background push notifications | No. | Post-MVP FCM/APNs registration, preferences, background handlers, deep links. | Requires device-token/preferences endpoints and push provider integration. |

### 4.2 Cross-Feature Delivery Contract

Every MVP feature in the audit must be delivered as a complete vertical slice. A checkbox such as “avatar upload” or “media chat” is not complete until all applicable layers below exist:

1. Typed request/response DTO and repository method matching the Gateway contract.
2. Controller/provider state for initial load, refresh, mutation, success, empty, validation error, transport error, and retry.
3. Screen/widget states for loading, content, no data, offline/cache, permission denied, and destructive confirmation.
4. Cache invalidation or realtime merge so the same avatar, post, message, count, or notification does not disagree across screens.
5. Accessibility: semantic labels, logical focus order, minimum 48x48 touch targets, scalable text, and non-color-only status cues.
6. Analytics/logging hooks without tokens, OTP values, message content, or private media URLs in production logs.
7. A runnable handoff that follows the relevant feature behavior checklist and is ready for product-owner manual acceptance.

The feature status vocabulary is:

| Status | Meaning |
| --- | --- |
| `Backend gap` | Flutter cannot complete the promised behavior with current APIs. |
| `Ready for mobile` | Required REST/WebSocket contract exists and has been validated. |
| `In progress` | Some layers of the vertical slice exist, but Definition of Done is not met. |
| `Done` | Functional, UI, state, accessibility, and cache/realtime behavior match the feature spec and the product owner has accepted the runnable result. |

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

### Identity, Profile, And OTP Contracts

#### OTP state machine

```text
register
  -> otpSent=true  -> enter OTP
  -> otpSent=false -> enter OTP with delivery error + enabled retry

enter OTP -> validating -> verified -> login/home according to auth response
          -> invalid    -> preserve email, clear/select code, show field error
          -> expired    -> show expired state and enable resend

resend -> sending -> sent + start 60-second countdown
       -> 429     -> use server message/countdown, do not start parallel timers
       -> failure -> keep screen actionable and show retry
```

OTP implementation requirements:

- Render six numeric positions but keep one logical text input for reliable paste, backspace, accessibility, and platform OTP autofill.
- Use `AutofillHints.oneTimeCode`, numeric keyboard, and accept a pasted six-digit code.
- Mask the destination email in explanatory copy; never log the OTP.
- Disable Verify until six digits exist and while the request is pending.
- The client countdown is presentation only. The backend remains authoritative for the 60-second resend limit and five-minute validity.
- On successful verification, clear OTP state and prevent back navigation to a stale verification screen.
- Map invalid format, invalid/expired OTP, already verified, rate limit, and email-delivery failure to distinct user-visible states.

#### Avatar and cover workflow

```text
tap camera/edit badge
-> action sheet: Take photo | Choose photo | View current | Remove (only when API exists)
-> permission check
-> picker
-> crop (avatar 1:1, cover recommended 16:9 or profile-header aspect)
-> local preview
-> confirm upload
-> multipart upload with progress
-> replace canonical UserProfileDTO
-> invalidate every user/profile/avatar projection
```

Rules:

- Reject non-images and files larger than 10 MB before upload, using the same message as the backend.
- Correct image orientation from EXIF and avoid decoding a full-resolution bitmap into memory for the preview.
- Do not overwrite the visible current image until upload succeeds; use a local preview overlay with progress.
- On failure, keep the selected crop available for Retry or Cancel.
- Append a cache-busting version only when necessary; canonical URLs still come from the backend response.
- After success, update session/current-user state, profile header, feed author avatars, comments, conversations, and notification actor projections where those are live references. Cached historical snapshots reconcile on their next fetch.
- Delete/reset controls are feature-gated until the DELETE contracts listed in Section 17 exist.

### Media Upload Transaction Rules

Post and chat media use a two-step transaction: upload the binary first, then submit returned attachment/media metadata with the post or STOMP message.

Each selected item must have a client-side state:

| State | Required UI and behavior |
| --- | --- |
| `local` | Thumbnail/file tile with remove X; no network call yet. |
| `uploading` | Per-item progress and disabled duplicate submit; X means cancel if supported, otherwise remove after request settles. |
| `uploaded` | Preview remains; retain returned URL, public id, type, dimensions, format, and byte size. |
| `failed` | Error badge plus Retry and Remove; successful siblings are not re-uploaded. |
| `committing` | Composer submit is locked while post/message metadata is sent. |
| `committed` | Clear local previews only after canonical post/message state is accepted. |

Additional rules:

- Revoke temporary object/file handles when an item is removed or the composer is disposed.
- Preserve the original chat filename in attachment metadata as `name`; preserve `bytes`, width, and height where available.
- A textless post or message is allowed only when at least one valid media item/attachment exists and the relevant backend accepts it.
- Never send partially uploaded attachment arrays silently. Make failed items explicit and require Retry or Remove.
- The backend needs an orphan cleanup policy for uploaded assets when the user cancels before commit or the commit fails permanently.
- Post upload currently accepts images only, maximum 10 MB each. Chat accepts images up to 50 MB, videos up to 500 MB, and PDF/DOCX up to 50 MB. UI copy and picker filters must match these actual limits.

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

### 9.1 Post, Comment, Reaction, And Media Interaction Contract

#### Opening post detail

- Tapping post body, timestamp, comment count, or Comment opens `/post/:postId`.
- Tapping an author/avatar opens the profile and must not also open post detail.
- Tapping media opens the fullscreen gallery at that media index and must not also open detail.
- Tapping overflow, reaction controls, links, hashtags, or Share performs that control's action and stops parent-card navigation.
- On phones, post detail is a full screen. A large draggable sheet is acceptable only for a quick comment view if it preserves a route/deep-link and expands to at least 90% height.
- The detail screen loads canonical post data and comments independently; a feed-card snapshot may render immediately while refreshing.
- Deleted, private, blocked, or unavailable posts use a dedicated unavailable state with Back, not a raw 404 message.

#### Post composer and edit

- Use a full-screen composer or tall modal sheet with author, privacy selector, multiline text, media picker, preview grid, and sticky submit action.
- Create is disabled while empty, during upload/submit, or when any selected media is failed.
- Edit initializes existing content/media. Existing media can be marked for removal; new media follows the upload states in Section 7.
- Every selected preview has a top-right circular X with semantic label `Remove <filename>`, at least a 44x44 visual/touch region, and sufficient contrast.
- Removing a local item is immediate. Removing an existing persisted item is staged until Save; Cancel restores it.
- Delete Post uses a destructive confirmation that names the consequence. Disable repeat taps and remove the post from feed/profile/detail only after success or through rollback-safe optimistic state.
- Share opens a sheet for optional share text/privacy if supported. Shared-post unavailable states must remain renderable.

#### Post gallery layout

| Count | Feed/detail layout |
| --- | --- |
| 1 | One aspect-ratio-aware tile, maximum display height; use contain/crop rules consistently. |
| 2 | Two equal columns. |
| 3 | One large tile plus two stacked tiles. |
| 4 | 2x2 grid. |
| 5+ | 2x2 visible grid; last visible tile shows `+N`. Full viewer contains all items. |

Gallery requirements:

- Use clipped 12-20 radius and 2-4 px gaps; reserve dimensions from metadata to avoid layout jumps.
- Fullscreen viewer uses a black background, page swipe, `index / total`, close X inside the safe area, and optional download/share action.
- Single tap toggles chrome. Pinch zoom applies to images; double tap toggles zoom; horizontal page change is disabled while zoomed.
- Back gesture/button closes viewer before leaving the underlying post. The viewer restores the original scroll position on close.
- Broken media renders a stable placeholder with Retry/Open externally where appropriate.

#### Comments and replies

- Initial detail shows the comment list and a safe-area-aware sticky composer. Focusing it keeps the target field above the keyboard.
- Tap Reply sets `Replying to <name>`, focuses the composer, and shows an X to cancel the reply target.
- Render one nested reply level directly. Deeper chains are visually flattened under their root while retaining `parentCommentId` semantics to avoid unusable indentation.
- Long-press or overflow opens owner-authorized Edit/Delete and general actions. Inline edit has Save/Cancel and preserves text if saving fails.
- Delete uses confirmation. After success, update counts and remove the item; if replies require context, render a deleted placeholder rather than orphaning the thread.
- Comment submission shows an in-place pending state. On failure, preserve text and expose Retry.

#### Reactions and reaction detail

- A normal tap on an unreacted React action sends `LIKE`. A normal tap on the current reaction removes it. Long-press opens all six types.
- Selecting a different reaction uses create/update semantics and immediately changes the label/icon with rollback on failure.
- The picker order is fixed: LIKE, LOVE, HAHA, WOW, SAD, ANGRY. Each item needs an icon/emoji, localized text, and semantic label.
- Animate picker entrance with fade + scale and each selection with a short spring/pop; do not block input during decorative animation.
- Tapping the reaction summary opens a modal sheet showing total and filter chips: All plus only types whose count is greater than zero.
- Each filter shows its count. Rows show avatar, display name, username when available, and the user's reaction icon. Tapping a row opens that profile.
- The same interaction is required for post and comment reactions. Empty/loading/error/retry states exist inside the sheet.
- Counts and breakdown update from `ReactionSummaryResponse`; the reacting-user list is fetched only when the detail sheet opens.

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

### Chat Screen And Conversation Behavior

#### Conversation list

- Sort by `updatedAt` descending after REST load and after every user-queue event.
- A row contains direct/group avatar, title, last-message preview, timestamp, unread badge, and presence dot for direct chat.
- Last-message preview distinguishes own messages (`You:`), image, video, file, and system event. Never show a blank row for attachment-only messages.
- Realtime `/user/queue/messages` updates last message and unread count. If the conversation is unknown, refetch the list.
- Opening a conversation marks it read after the screen is active, updates the badge locally, calls `POST /messages/{conversationId}/read`, and reconciles the user-queue response.
- Creating a direct conversation must use get-or-create so repeated taps cannot create duplicates.

#### Message history and realtime merge

- REST history is page-based with default size 50 and arrives newest-page semantics; normalize to chronological display.
- Load older history when the user scrolls near the top. Preserve the visible anchor so inserting older messages does not jump the viewport.
- Subscribe to the conversation topic only while relevant; unsubscribe on route change and restore it after reconnect.
- Deduplicate by server message id across REST, cache, reconnect, and topic events.
- Auto-scroll when the user is already near the bottom or sent the message. Otherwise preserve position and show a `New messages` pill.
- Group consecutive messages by sender/time for bubble/avatar density. Center system events and never render them as user bubbles.
- Messages from removed members continue to use the response sender fields/profile snapshot.

#### Composer and attachment preview

- Composer is pinned above the safe area/keyboard and contains attachment, expanding text field, optional media tray, and send button.
- Typing start is debounced; send `isTyping=false` after 1.5 seconds idle, on submit, when focus is lost, and before leaving.
- The draft preview is a horizontally scrollable tray or compact grid above the text field. Images/videos use square thumbnails; documents use a file tile.
- Every draft item has a visible top-right X. Removal must work before, during, and after individual upload according to the upload state table.
- The current product allows up to 10 images in one chat message on web; mobile should use the same limit until a backend-owned limit is defined. Mixed attachment rules must be verified before implementation.
- Keep the draft and successful uploaded metadata if another attachment fails. Keep the text and failed items if send/commit fails.

#### Attachment grid inside message bubbles

| Previewable attachment count | Bubble grid |
| --- | --- |
| 1 | One tile, max width about 260 logical px; preserve aspect where practical. |
| 2 | Two equal square columns, max width about 320. |
| 3+ | Three-column square grid, max width about 360; wrap additional items. |

- PDF/DOCX items span the full bubble width and show file icon, original filename, formatted size, and Download/Open action.
- Tapping image/video opens the shared fullscreen viewer at the tapped index. The viewer has close X, download, swipe navigation, image zoom, and video controls.
- Show per-item placeholder, upload/download progress, failure, retry, and unavailable states without collapsing the bubble.
- Request storage/media permission only when the platform/API level actually requires it; otherwise use the system save/share flow.

#### Presence, typing, and lifecycle

- Fetch initial presence in batches with `GET /presence/status?userIds=...`; then merge `/topic/presence` events by user id.
- Direct-chat app bar shows Online or formatted last seen. Conversation rows use a dot plus semantic label, not color alone.
- Group header may show online-member count only if all required presence ids were loaded; otherwise omit rather than guess.
- Ignore the current user's typing events. Clear a remote typing state after three seconds without renewal.
- Connect chat STOMP after authenticated session restore. Reconnect with bounded exponential backoff and jitter, restore subscriptions, refetch conversation/presence snapshots, and dedupe events.
- Moving to background may disconnect or retain the socket according to platform limits. On resume, always reconcile REST snapshots before trusting missed realtime state.
- Logout must unsubscribe, disconnect both sockets, clear presence/typing memory, and remove user-specific cached data.

#### WebSocket transport validation

The current server registers a SockJS endpoint and the web uses SockJS. Before selecting a Dart STOMP package, run a spike through the Gateway for Android and iOS:

1. Validate whether the client can use the SockJS transport at `/ws/chat` and `/ws/notifications`.
2. If the package requires native WebSocket, expose and validate a native STOMP endpoint in addition to SockJS; do not assume the base SockJS URL is a raw WebSocket URL.
3. Verify the `Authorization: Bearer <token>` STOMP CONNECT header survives the Gateway rewrite.
4. Validate reconnect, heartbeat, token refresh, and simultaneous chat/notification connections on a physical device.
5. Record the final HTTP(S)/WS(S) URL construction in environment configuration.

## 11. Notification Design

### In-App Notifications

MVP:

- Load notification list from `/api/notifications`.
- Load canonical badge count from `GET /api/notifications/unread-count`.
- Show unread badge in the notifications tab.
- Mark one notification as read.
- Mark all as read.
- Subscribe to `/user/queue/notifications` for new/updated notification rows.
- Subscribe to `/user/queue/notifications/unread-count` for the canonical `{ count }` badge payload.
- Keep chat message updates in chat realtime state, not notification-service social notification rows.

Realtime merge rules:

- On connect/resume, fetch the REST list and unread count before applying subsequent socket events.
- Insert a socket notification at the top only if its notification id is not already present; replace the matching row if it is.
- Use the unread-count queue as authoritative. A temporary local decrement after mark-read must reconcile to the pushed count or a REST refetch.
- Do not increment unread count merely because a duplicate socket event arrived.
- Mark-one optimistically only with rollback; Mark all must disable while pending and restore unread rows if the request fails.
- A foreground banner and the notification-list row are two presentations of the same id, not two notifications.

Target routing:

| Notification type | Tap destination |
| --- | --- |
| `FRIEND_REQUEST` | Friend requests screen or actor profile. |
| `FRIEND_ACCEPT` | Actor profile. |
| `POST_COMMENT`, `POST_LIKE`, `COMMENT_REPLY`, `POST_MENTION`, `COMMENT_MENTION` | `/post/{targetId}`; scroll/highlight a comment only when the payload can identify it. |
| `BIRTHDAY` | Actor profile when actor exists; otherwise notifications screen. |
| `WELCOME` | Profile/onboarding target defined by product copy. |
| `MESSAGE` | Conversation only if a valid conversation target exists; do not create or display this row when the same chat alert is already handled by chat realtime policy. |

If a target is missing/deleted/private, mark the row read and show a friendly unavailable state without losing the notification-list position.

### Local Notifications

Use local notifications for foreground/background user-visible alerts after mobile permissions are implemented. Prioritize:

- Friend request received/accepted.
- Comment/reaction alerts.
- Mention alerts if backend emits mention events.
- Chat alerts only when the user is not currently viewing the relevant conversation.

Foreground presentation rules:

- In-app banner: compact actor avatar, one-line message, time/type icon, and tap target; auto-dismiss after 4-6 seconds with swipe dismissal.
- Suppress the banner when the user is already viewing the exact target and the information is visibly updated.
- Chat foreground alert uses conversation/message data and chat unread state, not a duplicated social-notification record.
- Respect system notification permission. Denial must not block in-app notification list/realtime badges.
- Deduplicate local/push display using a stable notification or message id.

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

Detailed UI/UX synchronization rules live in `docs/architecture/MOBILE_UI_UX_SYNC_GUIDE.md`. Agents should read that guide before implementing or reviewing mobile screens so Flutter stays aligned with the current web visual identity and interaction patterns.

Feature-sized behavior specifications live in `docs/architecture/mobile-features/`. Start from its `README.md` and implement the numbered documents in dependency order. Those files are authoritative for current-web behavior, mobile interactions, state/error handling, and feature handoff checklists.

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

Status: current document updated to match current web/backend progress.

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
- Product-owner walkthrough of every completed feature specification.
- Performance checks for feed, explore, profile, and chat.

### Phase Exit Gates

| Phase | Must pass before moving on |
| --- | --- |
| 1 | App launches on Android/iOS target, environment switching works, theme/router/shell render, and `flutter analyze` has no blocking issue. |
| 2 | Session restore/refresh race/logout pass; OTP delivery failure/cooldown/expiry/autofill pass; tokens never enter logs or insecure storage. |
| 3 | Avatar/cover replace workflow and cross-screen cache propagation pass; delete/reset stays explicitly blocked until APIs exist; relationship/privacy/block flows reconcile across profile and chat. |
| 4 | Post image transaction, X/remove/retry, all gallery layouts, viewer, detail/dialog, comment/reply CRUD, and all six reaction types/detail filters pass. |
| 5 | Gateway transport spike passes on a physical device; history paging/dedupe/read, grids/viewer/files, group actions, reconnect, typing, presence, background/resume, and logout cleanup pass. |
| 6 | REST plus both notification queues reconcile; target routing, dedupe, badges, foreground suppression, permissions, offline/cache, and no duplicate chat notification rows pass. |
| 7 | Device token lifecycle, permission states, foreground/background/terminated delivery, dedupe, preferences, and deep links pass on Android and iOS. |
| 8 | Every numbered feature spec has a runnable handoff accepted by the product owner; accessibility/reduced motion, performance, signing, and release configuration are complete with no unresolved release-blocking backend gap. |

## 15. Two-Person Implementation Plan

This project should be implemented by two people with clear ownership boundaries. Both people should use the same feature-first architecture and open small PRs by phase.

| Phase | Person A ownership | Person B ownership | Shared handoff / merge point |
| --- | --- | --- | --- |
| Phase 0 - Planning Baseline | Keep mobile requirements aligned with auth, profile, friends, privacy, feed, and explore APIs. | Keep mobile requirements aligned with chat, notification, storage, and release needs. | Update planning docs before implementation starts. |
| Phase 1 - Flutter Foundation | App bootstrap, theme, router, auth guard, bottom navigation, lint rules. | Feature folder structure, placeholder screens, app ids, and app labels. | App runs and analyzes before Phase 2. |
| Phase 2 - Auth and Session | Auth UI, validation, login, register, OTP screens, Google login entry. | Dio client, token interceptor, refresh queue, secure storage, session restore/logout. | Auth controller exposes one stable session state consumed by router and UI. |
| Phase 3 - Profile, Friends, Privacy, Blocks | Profile screens, edit profile, avatar/cover upload, profile tabs. | Friends, requests, search, privacy settings, block/unblock workflows. | Relationship status and privacy state are reusable across profile, friends, and chat. |
| Phase 4 - Feed, Explore, and Social Content | Feed list, pagination, post cards, post composer, media upload. | Explore, post detail, comments, replies, reactions, share/edit/delete actions. | Post DTOs/entities and cache models are shared between feed, explore, profile, and detail. |
| Phase 5 - Chat and Presence | Conversation list, direct/group chat UI, message composer, attachments UI. | STOMP lifecycle, message history, typing, presence, group management actions, chat cache. | Chat state updates conversation badges and active conversation without social notification rows. |
| Phase 6 - Notifications | Notification list, unread badge, mark read/read all UI. | Notification WebSocket, local notification permission/display, foreground alert rules. | Notification state integrates with shell badges and avoids duplicating chat message alerts. |
| Phase 7 - Push Notifications | Device permission UX, deep link destinations, notification preferences UI. | FCM/APNs setup, device token registration client, backend contract validation. | Push payloads route to post, profile, conversation, or notification list. |
| Phase 8 - Stabilization and Release | UI polish plus error/empty/loading states for auth/feed/profile. | Media compression, app icon/splash, release signing, and chat/notification stabilization. | Release candidate is handed to the product owner for manual acceptance on available Android/iOS targets. |

Recommended parallel workflow:

- Person A starts with user-facing screens and controller boundaries.
- Person B starts with infrastructure, API clients, device-local cache, and realtime.
- Shared models and route names must be agreed before each phase begins.
- Each phase should end with `flutter analyze`, a runnable build, and a walkthrough against the related feature document.
- If both people touch the same feature, Person A owns `presentation` and Person B owns `data` plus `domain` unless agreed otherwise.
- PRs should be phase-scoped and avoid mixing unrelated UI polish with API infrastructure.

## 16. Feature Implementation And Manual Acceptance

Automated tests are not a required deliverable for the current mobile implementation plan. The implementation workflow is:

1. Select the next numbered document in `docs/architecture/mobile-features/`.
2. Implement its repository/models, controller/provider, screens/widgets, cache/realtime merge, and all documented states.
3. Run `flutter analyze` and launch the app on the available emulator/device.
4. Walk through the document's Behavior Completion Checklist and fix visible behavior gaps.
5. Hand the runnable feature to the product owner.
6. The product owner performs manual acceptance and decides whether the feature can be marked `Done`.

The feature documents define expected behavior, not automated test cases. Future contributors may add tests independently, but tests do not replace product-owner acceptance.

## 17. Backend Gaps For Full Mobile Support

Most current web flows can be reused. Remaining mobile-specific backend work:

| Gap | Required backend work |
| --- | --- |
| Avatar full CRUD | Add authenticated `DELETE /api/users/me/avatar`; clear profile URL and safely clean up the old Cloudinary asset. |
| Cover/banner full CRUD | Add authenticated `DELETE /api/users/me/cover`; clear profile URL and safely clean up the old Cloudinary asset. |
| Group avatar | Decide whether group image is in scope; if yes, add upload/replace/delete contract and conversation update event. |
| List pagination | Add cursor/page contracts for feed, user posts/images, comments, conversations where needed, and notifications; return stable ordering and has-more metadata. |
| Post media limits | Define maximum image count; return machine-readable validation fields. Add video only if product scope explicitly requires it. |
| Orphan media cleanup | Delete uploads not attached to a committed post/message after a safe TTL; never delete an asset referenced by canonical data. |
| Reliable message send | Add client message/idempotency id and acknowledgement/error destination or REST fallback so mobile can distinguish pending, sent, and failed. |
| Message lifecycle | Add edit/delete/delivery/read receipts only if those states will be shown; otherwise keep them out of MVP UI copy. |
| Native mobile STOMP | Validate SockJS support in chosen Dart client or expose a native WebSocket STOMP endpoint through Gateway. |
| Presence privacy | Define who may see online/last-seen and enforce it in REST and realtime payloads. |
| Notification navigation | Make `targetType` and target identifiers explicit enough to route post/comment/profile/conversation without guessing from enum and one `targetId`. |
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
- Every numbered feature document has a runnable implementation matching its behavior checklist.
- The product owner has manually accepted each feature on the available target devices.
