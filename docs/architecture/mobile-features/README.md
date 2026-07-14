# Kirenz Mobile Feature Implementation Specs

## Purpose

This directory splits the mobile plan into feature-sized implementation specifications. Implement one document at a time. Each specification records:

- Current web behavior that mobile must preserve.
- Mobile-native interaction decisions.
- Existing REST/WebSocket contracts.
- Screen, component, state, cache, and error behavior.
- Backend gaps that must not be faked in the client.
- A behavior checklist for implementation handoff.

These are implementation documents, not automated test plans. The product owner will run the app and accept behavior manually.

Contract-readiness target is at least 95% before Flutter feature implementation starts. Readiness means the documented enums, DTO shapes, errors, cache/realtime behavior, and backend gaps match validated source behavior.

Current source-audited documentation readiness is **97% (44/45 checks)** as of 2026-07-13. The audit checks endpoint/action mapping, DTO/enums, error/gap classification, cache/realtime reconciliation, and manual handoff behavior across the nine specifications. The only unchecked release-integration item is the physical-device SockJS/native STOMP transport gate in Feature 08; it is explicit and does not require Flutter code to guess a wire contract.

The remediation decisions and verification gates are recorded in [WEB_MOBILE_CONTRACT_REMEDIATION_PLAN.md](../WEB_MOBILE_CONTRACT_REMEDIATION_PLAN.md).


## Recommended Implementation Order

| Order | Feature specification | Depends on |
| --- | --- | --- |
| 1 | [Auth, Session, and Email OTP](01-auth-session-otp.md) | App shell, HTTP client, secure storage. |
| 2 | [Profile, Avatar, and Cover](02-profile-avatar-cover.md) | Authenticated session/current user. |
| 3 | [Feed, Post CRUD, and Post Media](03-feed-post-media.md) | Profile identity, social API client. |
| 4 | [Comments, Replies, and Reactions](04-comments-reactions.md) | Post card/detail. |
| 5 | [Friends, Explore, Privacy, and Blocks](05-friends-explore-privacy-blocks.md) | Profile and authenticated shell. |
| 6 | [Conversations and Group Management](06-conversations-groups.md) | Friends/search/profile projections. |
| 7 | [Presence, Typing, and Realtime Lifecycle](08-presence-typing-realtime.md) | Auth session and conversation state; transport spike precedes message publish. |
| 8 | [Chat Messages and Attachments](07-chat-messages-media.md) | Conversation detail and validated chat connection manager. |
| 9 | [Notifications](09-notifications.md) | Auth session, post/profile routes. |

## Shared Rules

- Mobile calls the API Gateway only.
- Backend responses are canonical. Local cache exists for fast/offline display, not as a second source of truth.
- A feature is not complete when only its happy-path screen exists. Loading, empty, pending, failure, retry, permission, offline/cache, and unavailable states belong to the feature.
- Do not expose a control when the backend action does not exist. Example: avatar/cover Remove stays hidden until DELETE endpoints exist.
- Preserve web product behavior, labels, permissions, and data meaning. Adapt layout and gestures for mobile.
- Use the shared visual and motion rules in [MOBILE_UI_UX_SYNC_GUIDE.md](../MOBILE_UI_UX_SYNC_GUIDE.md).
- Backend gaps and cross-feature architecture remain authoritative in [MOBILE_APP_PLANNING.md](../MOBILE_APP_PLANNING.md).

## Shared Contract Baseline

Every REST call returns `ApiResponse<T>`:

```text
success: boolean
message: string
data: T | null
```

Repositories unwrap `data` only after checking the HTTP result and response envelope. Validation errors must retain backend field errors where supplied; authentication, authorization, not-found/unavailable, rate-limit, validation, transport, and server failures must remain distinguishable in controller state.

Every feature document declares a contract status:

| Status | Meaning in these specifications |
| --- | --- |
| `Ready for mobile` | The current contract is source-validated and can be implemented without guessing. |
| `Backend gap` | The named behavior cannot be completed with current APIs and stays hidden/disabled. |
| `Transport gate` | DTOs exist, but physical-device Gateway transport validation must pass before release. |

Shared accessibility requirements apply to every feature: logical focus order, scalable text, semantic labels, non-color-only state, keyboard/screen-reader-safe forms, and minimum 48x48 logical-pixel interactive targets. Decorative motion honors reduced-motion settings.

Shared logging requirements apply to every feature: log operation name, sanitized failure category, request correlation id when supplied, and timing in debug/observability builds. Never log tokens, passwords, OTP values, message/comment drafts, private media URLs, raw WebSocket frames, or full private payloads in production.

Shared acceptance evidence for marking a feature `Done`:

- Contract status contains no unrecorded assumption.
- Loading, content, empty, cached/offline, permission, validation, unavailable, pending, failure, and retry states applicable to the feature are demonstrated.
- Cross-screen cache/realtime projections reconcile by stable id.
- Accessibility and reduced-motion behavior are walked through.
- `flutter analyze` passes and the runnable feature is accepted by the product owner.

## Per-Feature Workflow


1. Read the feature document and every dependency listed at its top.
2. Implement its models/repository, controller/provider, screens, reusable widgets, cache/realtime merge, and error states.
3. Run the app and walk through the document's behavior checklist.
4. Leave backend-gap items disabled/hidden and record them; do not simulate success locally.
5. Hand the runnable feature to the product owner for manual acceptance.
