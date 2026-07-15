# Kirenz Mobile Implementation Ledger

This is the project status source of truth. Read this file before scanning the repository. Detailed behavior remains authoritative in `docs/architecture/mobile-features/`.

## Status Vocabulary

| Status | Meaning |
| --- | --- |
| `Not started` | No production implementation exists beyond shell placeholders. |
| `In progress` | Some production behavior exists, but one or more required spec behaviors are missing. |
| `Review pending` | Implementation and local verification are complete; independent spec review is still required. |
| `Acceptance pending` | Independent review passed; product-owner manual acceptance is still required. |
| `Done` | Implementation, verification, independent review, and product-owner acceptance all passed. |
| `Blocked` | An explicit external/backend/integration gate prevents further work and is recorded below. |

Checkboxes in feature specs describe the contract, not implementation progress. Only this ledger records implementation status.

## Current Handoff

- Updated: 2026-07-15.
- Current feature: Feature 02 - Profile, Avatar, and Cover.
- Completed slices: canonical profile/edit and native avatar/cover flow; profile posts/photos/friends use canonical backend lists; other-profile relationship/privacy/block gates and actions; staged Privacy form and Blocked Users list.
- CX-01 complete: account-scoped SQLite cache, explicit stale/offline states, safe access fallback, reconciliation, verification, and independent review all pass.
- Profile render bugfix verified: global Filled/Outlined button minimum widths are intrinsic-safe; narrow/large-text Profile widget coverage passes without layout exceptions.
- Feature 02 is `Acceptance pending`; product-owner device acceptance remains. `TN-02` is now ready to start.
- Next command: begin `TN-02` Feature 06 Conversations and Groups; keep Feature 02 device acceptance recorded separately.
- Run command: `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080/api`.
- Do not start Feature 03 until Feature 02 reaches at least `Acceptance pending`, unless a dependency is explicitly recorded.

## Ownership And Parallel Work

This board is the assignment source of truth from 2026-07-15. Owners must update their row and the session log before handing work off. Do not edit another owner's active files without recording a coordination note here first.

### Completed Implementation Slices

| ID | Owner | Task | Status | Verification |
| --- | --- | --- | --- | --- |
| DONE-01 | Codex | Feature 02 canonical profile/edit, avatar/cover picker-crop-upload, posts/photos/friends tabs, media viewer, and other-profile access actions | Done | Analyze pass; Android debug build pass; covered in full suite 19/19; device acceptance remains a feature-level gate |
| DONE-02 | Codex | Feature 05 Friends search/requests/suggestions/list plus Privacy and Blocks contracts, screens, actions, and projection invalidation | Done | Analyze pass; 9 focused tests; full suite 19/19; Explore and chat propagation remain separate tasks |
| DONE-03 | Codex | Progress ledger, UI conformance gate, and independent-review workflow in project rules | Done | Documentation reviewed against current implementation flow |

`Done` above applies only to the named implementation slice. No whole feature currently satisfies the feature-level `Done` definition because review, acceptance, or remaining spec work is still open.

### Codex Queue

| Order | ID | Task | Status | Primary file ownership | Completion gate |
| --- | --- | --- | --- | --- | --- |
| 1 | CX-01 | Add cached/offline profile posts, photos, and opened-profile state; finish locally implementable Feature 02 and run independent review | Done | Product-owner coordination override on 2026-07-15: current session owns `features/profile/**` and profile cache/storage additions until handoff | Account-isolated cache and stale/reconciliation tests pass; analyze/full tests pass; independent reviewer found no Blocking/Major issue |
| 2 | CX-02 | Implement Feature 03 Feed/Post CRUD/Post Media after Feature 02 reaches `Acceptance pending` | Waiting | `features/feed/**`, `features/posts/**`, shared post UI | Feature 03 checklist, tests, and independent review pass; backend gaps remain hidden |
| 3 | CX-03 | Implement Feature 04 Comments/Replies/Reactions | Waiting | `features/comments/**`, reaction widgets/controllers | Feature 04 checklist, tests, and independent review pass |
| 4 | CX-04 | Complete Feature 05 Explore composition and cached/offline Explore, then run Feature 05 review | Waiting | `features/explore/**`; reuse shared post contracts from CX-02 | Explore states/query/scroll/cache contract and Feature 05 independent review pass |
| 5 | CX-05 | Close global UI foundation gaps owned outside Auth/Chat | Waiting | `app/theme.dart`, shared non-chat widgets | Quicksand decision, reusable states, accessibility and device visual check recorded |

### Thảo Nguyên Queue

Start with `TN-01` on 2026-07-16. Read `rule.md`, this ledger, the whole assigned feature spec, its dependencies, and `MOBILE_UI_UX_SYNC_GUIDE.md` before editing.

| Order | ID | Task | Status | Primary file ownership | Completion gate |
| --- | --- | --- | --- | --- | --- |
| 1 | TN-01 | Close Feature 01 Auth/Session/Email OTP gaps: Google login contract, unverified-login routing, backend field errors, intended destination, single-flight refresh queue, refresh-failure session notification, OTP controller state, and cleanup hooks | Done | Complete in `features/auth/**`, coordinated `app/router.dart` and `core/network/dio_provider.dart`; reviewer found no remaining Blocking/Major issue; product owner accepted on 2026-07-15. | Passed implementation, verification, independent review, and product-owner acceptance |
| 2 | TN-02 | Implement Feature 06 Conversations and Groups | Ready | `features/chat` conversation/group data, domain, controllers, list/management screens | Feature 06 checklist and tests pass; no message/realtime success is simulated |
| 3 | TN-03 | Implement Feature 08 presence/typing/realtime connection interface after Feature 06 | Blocked by TN-02 and physical transport gate | realtime transport and chat realtime state | Native STOMP/SockJS behavior tested; physical Gateway validation remains explicitly recorded until passed |
| 4 | TN-04 | Implement Feature 07 Chat Messages and Media against the Feature 08 connection interface | Waiting for TN-03 interface | chat message/media repositories, controllers, detail UI | Feature 07 checklist, attachment states, tests, and independent review pass |
| 5 | TN-05 | Implement Feature 09 in-app Notifications and deep links; do not expose push settings until backend contracts exist | Waiting for route targets | `features/notifications/**`, notification deep-link integration | In-app notification checklist/tests pass; FCM/APNs remains hidden and recorded as a backend gap |

### Coordination Boundaries

- Thảo Nguyên owns Auth, Chat, Realtime, and Notifications while her task is active. Codex owns Profile, Feed, Posts, Comments, Friends, Explore, and shared non-chat UI.
- `app/router.dart`, `core/network/dio_provider.dart`, session state, and shared post entities are coordination files. Rebase or pull before editing them and record the required cross-owner change in the session log.
- One owner implements a feature; a different agent performs its independent spec review. The reviewer reports findings without editing production code.
- Never mark a whole feature `Done` until implementation, verification, independent review, and explicit product-owner manual acceptance all pass.

## UI/UX Conformance Gate

- Source: `MOBILE_UI_UX_SYNC_GUIDE.md`; matching web components are supporting references.
- Passed by code inspection: explicit Kirenz light/dark colors, Material 3, warm surfaces, rounded cards/inputs/actions, native six-destination shell, auth branding, and cover/avatar/profile tabs.
- Open before global UI approval: bundle Quicksand or explicitly retain the documented system fallback; add independent Chat/Alerts badges when their state sources exist; replace feature placeholders with their specified loading/content/empty/error states; complete device-level visual/accessibility acceptance.
- Current verdict: partially aligned. Never claim that all UI has passed until these open checks are closed and recorded here.

## Feature Progress

| Order | Feature | Status | Evidence in code | Missing before review |
| --- | --- | --- | --- | --- |
| 00 | Flutter foundation | In progress | Material 3 app, Riverpod, `go_router`, authenticated shell, secure storage, Dio, feature folders | Quicksand asset/fallback decision; shared loading/empty/error/avatar/media widgets; shell accessibility/polish |
| 01 | Auth, Session, Email OTP | Done | Complete auth UI/controller/repository flow; Google v7 native acquisition and Kirenz token exchange; controller-owned OTP lifecycle; inline backend errors; optional registration fields and discard guard; intended routing; JWT-aware restore; concurrent single-flight refresh/stale-session guard; best-effort account cleanup hooks | Environment-specific Google OAuth credentials, Android package/SHA registration, and iOS reversed-client URL scheme remain deployment configuration documented in `mobile/README.md` |
| 02 | Profile, Avatar, Cover | Acceptance pending | Canonical profile/edit/media flow; native avatar/cover picker-crop-upload; account-scoped SQLite opened-profile/posts/photos cache; explicit stale states and safe access fallback; canonical reconciliation; posts/photos/friends states; relationship/privacy/block gates and actions; stable grids; shared viewer; Android native build passes | Product-owner physical Android/iOS permission/camera/library and offline-state acceptance; feed author propagation follows Feature 03 |
| 03 | Feed, Post CRUD, Post Media | Not started | Home route is a placeholder | Entire Feature 03 spec |
| 04 | Comments, Replies, Reactions | Not started | No production implementation | Entire Feature 04 spec |
| 05 | Friends, Explore, Privacy, Blocks | In progress | Exact friend/search/privacy/block DTOs and enums; debounced stale-safe people search; Requests/Suggestions/Friends segments and actions; privacy-aware profile fetch gate; named relationship/block confirmations; staged Privacy form with unsaved-back guard; Blocked Users list/unblock; inaccessible profile content invalidation; full UI states | Explore composition and cached/offline Explore; direct-chat/shared-group block effects after Features 06-07 exist; widget coverage and backend/device acceptance |
| 06 | Conversations, Groups | Not started | Chat route is a placeholder | Entire Feature 06 spec |
| 08 | Presence, Typing, Realtime | Blocked | WebSocket paths only in config | Implement after Feature 06; physical Android/iOS Gateway transport gate must pass before release |
| 07 | Chat Messages, Media | Not started | No production implementation | Entire Feature 07 spec; depends on Feature 08 connection interface |
| 09 | Notifications | Not started | Alerts route is a placeholder | Entire Feature 09 spec; push/FCM remains an explicit backend gap |

## Review And Acceptance Ledger

| Feature | Analyze | Tests | Manual checklist | Independent reviewer | Product owner | Final status |
| --- | --- | --- | --- | --- | --- | --- |
| Foundation | Pass, 2026-07-14 | 4 tests pass | Pending | Pending | Pending | In progress |
| 01 Auth | Pass, 2026-07-15 | 17 focused auth/network tests; full suite 36/36 pass | Accepted by product owner, 2026-07-15 | Pass: no Blocking/Major findings after two fix rounds | Pass, 2026-07-15 | Done |
| 02 Profile | Pass, 2026-07-15 | 21 focused profile tests; full suite 47/47 pass, including narrow/light/dark/large-text Profile layout regression | Android emulator `/profile/me` render, Edit cover, Edit profile, and Posts/Photos/Friends switching pass after fix; physical iOS/Android media acceptance pending | Pass: no Blocking/Major findings after final fix round | Pending | Acceptance pending |
| 05 Friends | Pass, 2026-07-15 | 9 focused relationship/privacy/block model, repository, and access tests; full suite 19/19 | Pending | Must run after full Feature 05 implementation | Pending | In progress |

## Known Backend And Integration Gates

- Feature 01: production Google OAuth identifiers are not stored in this repo. Configure Android package/SHA and `GOOGLE_SERVER_CLIENT_ID`; configure iOS client/reversed-client URL scheme, then validate cancellation and id-token-to-Kirenz exchange on physical Android/iOS.
- Feature 02: avatar and cover delete endpoints do not exist; Remove controls must stay hidden.
- Feature 03: feed pagination, post video upload, canonical media-count validation, and orphan cleanup are backend gaps.
- Feature 08: SockJS/native STOMP, CONNECT auth, heartbeat, reconnect, and token replacement require physical Android/iOS validation through the Gateway.
- Feature 09: FCM/APNs device-token and notification-preference contracts do not exist; push controls stay absent.

## Session Log

Add one concise row per implementation session. Never paste large diffs or command logs here.

| Date | Scope | Result | Verification | Next |
| --- | --- | --- | --- | --- |
| 2026-07-14 | Re-audit repo against Features 01-09; replace phase-based tracker with spec ledger | Features 01 and 02 corrected to `In progress`; Features 03-09 are placeholders/not started; explicit gates recorded | Baseline analyze/test rerun started | Implement Feature 02 canonical profile slice |
| 2026-07-14 | Feature 02 canonical profile slice | Added canonical DTO-shaped entity, strict envelope parsing, complete edit form/payload, multipart repository methods, stable cover/avatar header, tab shell, and focused tests | `flutter analyze --no-pub`: pass; `flutter test --no-pub`: 4 pass | Implement picker/crop/upload controller and UI; do not request review yet |
| 2026-07-14 | Feature 02 avatar/cover media slice | Added native source sheets, permission declarations, 1:1/16:9 crop, type/10 MB validation, local composition preview, upload progress, Retry/Cancel, cache eviction, canonical profile/session propagation, and cover route | Analyze pass; full tests 7/7; Android debug APK build pass | Implement posts/photos data states and fullscreen viewer; device-test picker/crop/upload |
| 2026-07-14 | Feature 02 posts/photos slice | Source-validated and documented `PostImageResponse`; added shared canonical Post entity, strict list repositories, tab loading/empty/error/retry/refresh/content, post cards/media grids, photo grid, and swipe/zoom/index viewer with keep-alive | Analyze pass; targeted tests 3/3; full tests 10/10 | Implement Feature 05-backed friends and other-user actions; add cached/offline content state |
| 2026-07-14 | UI guide audit and Feature 05 friends slice | Recorded partial UI conformance gate; added canonical friend models/repository, debounced user search, request/suggestion/friend actions and full-state Friends/Profile tabs | Analyze pass; 3 focused model tests; full suite 13/13 | Implement other-profile relationship/privacy/block behavior, then privacy and blocked-user screens |
| 2026-07-15 | Feature 05 relationship, privacy, and blocks slice | Added privacy-first other-profile access gate, all relationship actions, named block/unblock/remove confirmations, canonical staged Privacy form, Blocked Users list, and cross-projection invalidation | Analyze pass; 6 new focused tests; full suite 19/19 | Add cached/offline profile content, then complete Feature 02 independent review flow |
| 2026-07-15 | Ownership handoff | Marked three verified implementation slices done and split all remaining work by domain: Codex owns Profile/Feed/Friends-Explore; Thảo Nguyên owns Auth/Chat/Realtime/Notifications | Assignment and file-conflict boundaries recorded | Codex starts CX-01; Thảo Nguyên starts TN-01 on 2026-07-16 |
| 2026-07-15 | TN-01 Auth/Session/OTP completion | Completed OTP edge states, inline field errors, discard guard, intended/unverified routing, Google v7 flow, JWT restore, concurrent refresh/stale guard, and isolated account cleanup; independent review passed after two fix rounds | Format/diff check pass; analyze pass; 17 focused tests; full 36/36; Android debug APK pass; physical OAuth/backend pending | Product-owner physical acceptance; TN-02 remains gated by Feature 02 acceptance |
| 2026-07-15 | TN-01 product acceptance | Product owner marked TN-01 and Feature 01 Done after implementation, verification, and clean independent review | Acceptance recorded; no production code changed | Keep TN-02 waiting until Feature 02 reaches `Acceptance pending` |
| 2026-07-15 | CX-01 cached/offline Profile completion | Added owner-isolated SQLite cache for opened profile/posts/photos, stale-state UI, canonical reconciliation, logout/mutation invalidation, and fail-closed access snapshots; independent review passed after fixes | Analyze pass; 18/18 focused profile tests; full suite 44/44; reviewer found no Blocking/Major issue | Product-owner device acceptance for Feature 02; TN-02 is ready |
| 2026-07-15 | Profile infinite-width button render bugfix | Made global Filled/Outlined button minimum widths intrinsic-safe while retaining 52px height/pill styling; made long Profile details flex responsively; added current/other/restricted Profile widget regressions with tab switching and large text | Format/analyze pass; Profile 21/21; full 47/47; Android emulator `/profile/me`, edit routes, and all tabs pass without Flutter layout/null logs | Physical iOS/Android media acceptance remains pending |

## Rules For Updating This File

1. Update `Current Handoff` before ending every coding session.
2. Update only the affected feature row and add one `Session Log` row.
3. Record exact verification results; never mark a gate passed based only on code inspection.
4. Move a feature to `Review pending` only after its complete spec checklist is implemented and local verification passes.
5. A separate subagent reviews code against the feature spec. The implementing agent fixes every valid finding and reruns verification.
6. Move to `Acceptance pending` only after the independent reviewer reports no blocking findings.
7. Move to `Done` only after product-owner manual acceptance. Never let the implementing agent self-approve `Done`.
