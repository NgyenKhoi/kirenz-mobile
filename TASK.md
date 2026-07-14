# Kirenz Mobile Task Tracker

This file tracks implementation progress against `MOBILE_APP_PLANNING.md` and `MOBILE_UI_UX_SYNC_GUIDE.md`.

## Current Focus

- Current phase: Phase 3 - Profile, Friends, Privacy, Blocks.
- Goal: finish authenticated profile and relationship workflows on top of the completed session foundation.
- Quality gate for now: app must analyze/build/run cleanly and pass manual smoke checks. Do not add new automated tests unless they become necessary.
- Local Android command: `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080/api`

## Phase Progress

| Phase | Status | Notes |
| --- | --- | --- |
| Phase 0 - Planning Baseline | Done | Planning document covers current feature parity, Gateway-only access, backend DB ownership, realtime, storage, and notification direction. |
| Phase 1 - Flutter Foundation | Mostly done | `mobile/` app exists with Material theme, `go_router`, Riverpod bootstrap, authenticated shell tabs, placeholder screens, app ids, lint config, and feature-first folders. |
| Phase 2 - Auth and Session | Mostly done | Core auth/session infrastructure is implemented. Remaining work is backend endpoint contract verification and Google login setup. |
| Phase 3 - Profile, Friends, Privacy, Blocks | In progress | Current user profile loads through `/users/me` with session fallback, edit profile is wired to `PATCH /users/me`, and other user profile route/repository support exists. Next work is avatar/cover upload, friends, privacy, and blocks. |
| Phase 4 - Feed, Explore, and Social Content | Not started | Depends on authenticated HTTP client, shared API response parsing, and post DTO/entity contracts. |
| Phase 5 - Chat and Presence | Not started | Depends on authenticated session, websocket token handling, and chat DTO/entity contracts. |
| Phase 6 - Notifications | Not started | Depends on authenticated session and notification websocket path. |
| Phase 7 - Push Notifications | Later | Requires backend device token endpoints, Firebase/APNs setup, and deep link contracts. |
| Phase 8 - Stabilization and Release | Later | Manual QA, build polish, signing, icon/splash, performance checks, and critical tests. |

## Phase 0 Checklist - Planning Baseline

- [x] Confirm mobile calls only the API Gateway.
- [x] Document backend-owned PostgreSQL, MongoDB, and Redis boundaries.
- [x] Document current web feature parity target.
- [x] Document REST, WebSocket, storage, realtime, and notification direction.
- [x] Define MVP and post-MVP scope.
- [x] Define two-person implementation ownership.
- [x] Add UI/UX sync guide for Kirenz/Moments mobile identity.

## Phase 1 Checklist - Flutter Foundation

- [x] Create `mobile/` Flutter project.
- [x] Configure Android/iOS app identifiers.
- [x] Add `--dart-define` API environment config.
- [x] Add Material 3 app bootstrap.
- [x] Add Riverpod provider scope.
- [x] Add `go_router` with auth-aware redirect.
- [x] Add authenticated shell route with bottom tabs.
- [x] Add placeholder screens for Home, Explore, Friends, Chat, Alerts, and Profile.
- [x] Add linting config.
- [x] Add feature-first folder structure.
- [x] Replace default blue seed theme with Kirenz/Moments color tokens.
- [ ] Bundle Quicksand font assets or document fallback decision.
- [ ] Add shared loading, empty, and error state widgets.
- [ ] Add shared avatar/media fallback widgets.

## Phase 2 Checklist - Auth and Session

- [x] Keep dev sign-in available as fallback for UI smoke testing.
- [x] Add shared API response/error parsing.
- [x] Add Dio client with base URL and JSON headers.
- [x] Add access-token attachment for protected requests.
- [x] Add refresh-token retry flow for `401`.
- [x] Add secure token storage for access token, refresh token, and current user id.
- [x] Add auth DTOs and repository for login/register/refresh.
- [x] Restore session on app startup.
- [x] Wire login screen to backend login.
- [x] Wire register screen to backend register.
- [x] Wire OTP screen to backend verification endpoint.
- [x] Add logout that clears secure storage and returns to login.
- [x] Leave Google login button disabled or stubbed until mobile Google client ids are configured.
- [ ] Verify login/register/refresh/OTP endpoint payloads against backend.
- [ ] Add Google Sign-In mobile dependency and configure Android/iOS client ids.
- [ ] Wire Google `idToken` to `POST /auth/google`.
- [ ] Disconnect realtime services during logout after websocket services exist.

## Phase 3 Checklist - Profile, Friends, Privacy, Blocks

- [x] Add current user profile repository through `/users/me`.
- [x] Show current user profile data in Profile tab with loading/error/refresh states.
- [x] Add edit profile form.
- [x] Add other user profile repository through `/users/{id}`.
- [x] Add other user profile route `/profile/:userId`.
- [ ] Extend `AppUser`/profile model with username, bio, avatar URL, cover URL, friend status, and counts when backend contract is confirmed.
- [ ] Polish profile screen to cover-photo + overlapping avatar + tabs structure.
- [ ] Add profile posts/photos/friends tabs.
- [ ] Add avatar upload repository through `/users/me/avatar`.
- [ ] Add cover photo upload repository through `/users/me/cover`.
- [ ] Add media picker bottom sheet for avatar and cover photo.
- [ ] Add upload loading/error states and refresh profile after upload.
- [ ] Add friends repository for `/friends/**`.
- [ ] Add friend request lifecycle: send, accept, decline, cancel, unfriend.
- [ ] Add friend status actions on other user profile.
- [ ] Add user search through `/users/search`.
- [ ] Add user suggestions.
- [ ] Add mutual friends through `/users/{id}/mutual-friends`.
- [ ] Add privacy settings repository through `/privacy/**`.
- [ ] Add privacy settings screen wiring.
- [ ] Add block repository through `/blocks/**`.
- [ ] Add block/unblock actions.
- [ ] Add blocked users list screen `/blocked-users`.
- [ ] Add blocked-user warning affordance for future group chat flows.

## Phase 4 Checklist - Feed, Explore, and Social Content

- [ ] Add post DTOs/entities shared by feed, explore, profile, and post detail.
- [ ] Add post repository for `/posts/**`, `/comments/**`, and `/media/posts`.
- [ ] Add feed pagination.
- [ ] Add feed pull-to-refresh.
- [ ] Replace placeholder feed with Kirenz-style feed scaffold.
- [ ] Add post card with author row, metadata, body, media, counts, and action row.
- [ ] Add skeleton loaders for feed/post cards.
- [ ] Add create post composer.
- [ ] Add post media upload.
- [ ] Add edit post.
- [ ] Add delete post with confirmation.
- [ ] Add share post.
- [ ] Add post detail route `/post/:postId`.
- [ ] Add comments list.
- [ ] Add comment composer.
- [ ] Add replies if backend route is available.
- [ ] Add reactions for posts.
- [ ] Add reactions for comments.
- [ ] Add Explore content/user discovery screen.
- [ ] Add Explore search.
- [ ] Add device-local cache for feed/explore/opened post details.

## Phase 5 Checklist - Chat and Presence

- [ ] Add chat DTOs/entities for conversations, members, messages, attachments, presence, and typing.
- [ ] Add chat repository for `/conversations/**`, `/messages/**`, `/presence/**`, and `/media/chat`.
- [ ] Add STOMP/WebSocket client using Gateway `/ws/chat`.
- [ ] Attach auth token in WebSocket headers.
- [ ] Add reconnect lifecycle.
- [ ] Add `/user/queue/messages` subscription.
- [ ] Add `/topic/presence` subscription.
- [ ] Add `/topic/conversation.{conversationId}` subscription.
- [ ] Add `/topic/conversation.{conversationId}.typing` subscription.
- [ ] Add conversation list with unread badges and presence indicator.
- [ ] Add direct conversation creation.
- [ ] Add chat detail route `/chat/:conversationId`.
- [ ] Add message history pagination.
- [ ] Add stable message composer.
- [ ] Send text messages.
- [ ] Send image/video/PDF/DOCX attachments.
- [ ] Add typing indicator publish/listen flow.
- [ ] Add group rename.
- [ ] Add group add members.
- [ ] Add group kick members with confirmation.
- [ ] Add group leave/delete with confirmation.
- [ ] Add make admin action.
- [ ] Add nickname actions.
- [ ] Render nickname/leave system messages.
- [ ] Preserve sender profile display for kicked users.
- [ ] Add device-local cache for conversations/messages.

## Phase 6 Checklist - Notifications

- [ ] Add notification DTOs/entities.
- [ ] Add notification repository for `/notifications/**`.
- [ ] Add notification list screen data loading.
- [ ] Add unread badge in Alerts tab.
- [ ] Add mark one notification read.
- [ ] Add mark all notifications read.
- [ ] Add notification deep link handling to profile/post/settings/list destinations.
- [ ] Add WebSocket client using Gateway `/ws/notifications`.
- [ ] Add realtime notification subscription.
- [ ] Keep chat message alerts in chat realtime state, not social notification rows.
- [ ] Add local notification permission flow.
- [ ] Add foreground local notification display rules.

## Phase 7 Checklist - Push Notifications

- [ ] Add Firebase project setup.
- [ ] Add FCM dependency and Android/iOS native configuration.
- [ ] Add APNs setup for iOS.
- [ ] Add backend device token registration contract: `POST /notifications/devices`.
- [ ] Add backend device token deletion contract: `DELETE /notifications/devices/{deviceToken}`.
- [ ] Add mobile client device token registration after login.
- [ ] Add token unregister on logout.
- [ ] Add notification preferences contract: `PATCH /notifications/preferences`.
- [ ] Add per-device notification preferences UI.
- [ ] Add push payload deep link routing.

## Phase 8 Checklist - Stabilization and Release

- [ ] Polish loading, empty, error, and permission states across implemented screens.
- [ ] Add media compression before upload.
- [ ] Add app icon.
- [ ] Add splash screen.
- [ ] Configure Android release signing.
- [ ] Configure iOS signing profile.
- [ ] Add unit tests for validators, DTO parsing, and key repositories.
- [ ] Add provider/controller tests for auth, profile, feed, chat, and notifications.
- [ ] Add widget tests for login form, feed card, post composer, chat composer, and notification item.
- [ ] Add integration tests for critical auth/feed/profile/chat/notification flows.
- [ ] Run performance checks for feed, explore, profile, and chat.
- [ ] Complete Android emulator/device manual QA.
- [ ] Complete iOS simulator/device manual QA where available.

## Backend Gaps For Full Mobile Support

- [ ] Add push notification device token endpoints.
- [ ] Add push provider integration.
- [ ] Add mobile notification preferences.
- [ ] Add notification payload deep link target type/id contract.
- [ ] Add optional idempotency keys for offline create post/comment/message actions.
- [ ] Add optional media compression/thumbnail variants and clearer upload validation errors.

## Manual Smoke Checks

- [x] `flutter analyze`
- [ ] `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080/api`
- [ ] App opens to login when there is no saved session.
- [ ] Development sign-in path can still reach the main tabs.
- [ ] Login with backend credentials reaches `/home`.
- [ ] Restarting the app restores a valid saved session.
- [ ] Logout clears saved session.
- [ ] Profile tab loads `/users/me`.
- [ ] Edit profile saves through `PATCH /users/me`.
- [ ] Other user profile route `/profile/:userId` loads `/users/{id}`.

## Decisions

- Mobile calls only the API Gateway.
- PostgreSQL, MongoDB, and Redis remain backend-owned. Mobile only keeps device-local cache copies later.
- Automated tests are not a current requirement; prioritize stable run/analyze/manual QA.
- Add dependencies only when the related feature is implemented enough to keep `pubspec.yaml` and `pubspec.lock` in sync.
