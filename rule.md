# Kirenz Mobile Development Rules

## Agent Workflow

1. Read this `rule.md`, `TASK.md`, the current feature spec, and only its declared dependencies before changing code. For every UI change, also read `MOBILE_UI_UX_SYNC_GUIDE.md` and inspect the matching web screen/component when available.
2. Treat `TASK.md` as the implementation status source of truth and `docs/architecture/mobile-features/` as the behavior/contract source of truth.
3. Inspect only the files listed as evidence/current scope in `TASK.md` first. Expand repository reading only when imports, dependencies, or a finding require it.
4. Implement one feature specification at a time in the order from `docs/architecture/mobile-features/README.md`.
5. Follow existing Flutter project patterns before introducing new abstractions.
6. Keep changes scoped to the current feature or explicitly recorded dependency.
7. Do not revert or overwrite user changes unless explicitly requested.
8. Prefer implementation plus verification over proposal-only answers when the request is actionable.
9. Run the smallest relevant Flutter verification command after code changes and report the result.
10. Before ending every coding session, update `TASK.md` current handoff, affected feature evidence/missing work, verification result, and one concise session-log row.

## Feature Completion Flow

1. Read the whole current feature spec and every dependency named at its top.
2. Record the exact implementation slice and expected files in `TASK.md` before coding.
3. Implement models/repositories first, then controllers/providers, then screens/widgets and navigation.
4. Implement applicable loading, content, empty, cached/offline, permission, validation, unavailable, pending, failure, retry, and accessibility states.
5. Keep documented backend gaps hidden or disabled and record them in `TASK.md`; never simulate backend success.
6. Run formatting, `flutter analyze`, targeted tests, and `flutter test` in proportion to the change.
7. Walk the feature behavior checklist manually where the local environment allows and record unexecuted device/backend checks.
8. Set the feature to `Review pending` only when the entire spec is implemented and local verification passes.
9. Create a separate review subagent after full feature implementation. Give it the feature spec, changed-file list, diff, and verification results; ask it to report contract deviations, bugs, missing states, and test gaps without editing code.
10. The implementing agent fixes every valid review finding, reruns verification, and requests another independent review when blocking findings existed.
11. Set `Acceptance pending` only after the reviewer reports no blocking findings.
12. Set `Done` only after product-owner manual acceptance. The implementing agent and review subagent must never self-approve product acceptance.

## Review Severity

1. `Blocking`: contract mismatch, broken core path, security/privacy issue, data loss, missing required state, analyzer/test failure, or unsupported behavior presented as working.
2. `Major`: important edge case, accessibility failure, stale cross-screen state, or missing targeted coverage that makes regression likely.
3. `Minor`: polish or maintainability issue that does not invalidate the behavior checklist.
4. Review output must cite file and line, the violated spec section, severity, and a concrete correction.

## Flutter Architecture

1. Use feature-first Clean Architecture under `lib/features`.
2. Keep each feature split into `data`, `domain`, and `presentation` when it owns API or business logic.
3. Keep shared UI, validators, and small utilities under `lib/shared`.
4. Keep app bootstrap, router, and theme under `lib/app`.
5. Keep cross-cutting services under `lib/core`.
6. UI must not call `Dio`, secure storage, SQLite, or WebSocket clients directly.
7. Repositories own network, cache, and DTO mapping decisions.
8. Domain entities must not depend on Flutter widgets or API DTOs.

## Dart And Code Style

1. Do not add code comments.
2. Prefer clear names over clever names.
3. Keep widgets small and focused.
4. Extract reusable widgets only when reuse or readability is real.
5. Use immutable models where practical.
6. Keep DTOs separate from domain entities and persistence models.
7. Avoid unrelated refactors in feature or bugfix work.
8. Use `const` constructors where useful.
9. Do not store access tokens or refresh tokens in `SharedPreferences`.

## State Management

1. Use Riverpod for app state and dependency wiring.
2. Represent server state with `AsyncValue<T>` when loading, refreshing, or failing can happen.
3. Controllers coordinate use cases and repositories; screens render state and dispatch user intent.
4. Keep local widget state only for input values, focus, animation, selection, and transient UI state.
5. Dispose streams, text controllers, subscriptions, and realtime connections intentionally.

## Navigation

1. Use `go_router` for app routing.
2. Keep auth guards in the router layer.
3. Primary authenticated destinations must live behind bottom navigation.
4. Destructive flows must use confirm dialogs.
5. Route names and paths must stay stable once linked from notifications or deep links.

## API And Storage

1. Mobile calls the API Gateway only.
2. Configure API URLs with `--dart-define`.
3. Use `Dio` interceptors for auth headers, refresh retry, and normalized errors.
4. Refresh tokens once per failed request group, then retry queued requests.
5. Clear the local session and route to login when refresh fails.
6. Use `flutter_secure_storage` for tokens and current user id.
7. Use `SharedPreferences` only for non-sensitive preferences.
8. Use typed SQLite cache for feed, chat, notifications, and opened details when offline support is added.

## UI And Error UX

1. Treat `MOBILE_UI_UX_SYNC_GUIDE.md` as the visual and interaction contract; record the UI conformance result in `TASK.md` before claiming a screen is aligned.
2. Show user-visible errors in the UI instead of only logging them.
3. Field validation errors must appear under the matching input.
4. Form-level errors are only for errors that cannot be mapped to a specific field.
5. Clear a field error when the user edits that field.
6. Disable submit controls while requests are pending.
7. Keep loading, empty, and error states polished on every screen.
8. Prefer native Flutter Material widgets and platform permission flows.
9. Do not add visible instructional text unless the workflow genuinely needs it.

## Testing And Verification

1. Run `flutter analyze` after Dart changes when possible.
2. Run targeted widget or unit tests for changed behavior.
3. Run `flutter test` before finishing broad UI or controller changes.
4. If verification fails because of missing SDK, emulator, backend, or network, report the exact blocker and command needed to continue.

## Documentation

1. Update docs when behavior, architecture, use cases, or API expectations change.
2. Keep docs concise and aligned with the current implementation.
3. User-facing feature names may differ from internal technical names when that improves clarity.
