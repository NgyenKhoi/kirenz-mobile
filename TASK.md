# Kirenz Mobile Task Tracker

This file tracks implementation progress against `MOBILE_APP_PLANNING.md`.

## Current Focus

- Current phase: Phase 3 - Profile, Friends, Privacy, Blocks.
- Goal: start authenticated profile and relationship workflows on top of the completed session foundation.
- Quality gate for now: app must analyze/build/run cleanly and pass manual smoke checks. Do not add new automated tests unless they become necessary.

## Phase Progress

| Phase | Status | Notes |
| --- | --- | --- |
| Phase 0 - Planning Baseline | Done | Planning document covers current feature parity, Gateway-only access, backend DB ownership, realtime, storage, and notification direction. |
| Phase 1 - Flutter Foundation | Mostly done | `mobile/` app exists with Material theme, `go_router`, Riverpod bootstrap, authenticated shell tabs, placeholder screens, app ids, lint config, and feature-first folders. |
| Phase 2 - Auth and Session | Mostly done | Core auth/session infrastructure is implemented. Remaining work is backend endpoint contract verification and Google login setup. |
| Phase 3 - Profile, Friends, Privacy, Blocks | In progress | Current user profile loads through `/users/me` with session fallback, and edit profile is wired to `PATCH /users/me`. Next work is avatar/cover upload, friends, privacy, and blocks. |
| Phase 4 - Feed, Explore, and Social Content | Not started | Depends on authenticated HTTP client and shared API response parsing. |
| Phase 5 - Chat and Presence | Not started | Depends on authenticated session and websocket token handling. |
| Phase 6 - Notifications | Not started | Depends on authenticated session and notification websocket path. |
| Phase 7 - Push Notifications | Later | Requires backend device token endpoints and Firebase/APNs setup. |
| Phase 8 - Stabilization and Release | Later | Manual QA, build polish, signing, icon/splash, and performance checks. |

## Phase 2 Checklist

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


## Phase 3 Checklist

- [x] Add current user profile repository through `/users/me`.
- [x] Show current user profile data in Profile tab with loading/error/refresh states.
- [x] Add edit profile form.
- [ ] Add avatar upload.
- [ ] Add cover photo upload.
- [ ] Add other user profile route `/profile/:userId`.
- [ ] Add friends repository and friend request lifecycle.
- [ ] Add user search/suggestions.
- [ ] Add privacy settings repository and screen wiring.
- [ ] Add block/unblock and blocked users list.
## Manual Smoke Checks

- [x] `flutter analyze`
- [ ] `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080/api`
- [ ] App opens to login when there is no saved session.
- [ ] Development sign-in path can still reach the main tabs.
- [ ] Login with backend credentials reaches `/home`.
- [ ] Restarting the app restores a valid saved session.
- [ ] Logout clears saved session.

## Decisions

- Mobile calls only the API Gateway.
- PostgreSQL, MongoDB, and Redis remain backend-owned. Mobile only keeps device-local cache copies later.
- Automated tests are not a current requirement; prioritize stable run/analyze/manual QA.

