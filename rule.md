# Kirenz Mobile Development Rules

## Agent Workflow

1. Read this `rule.md` and the files directly related to the task before changing code.
2. Follow existing Flutter project patterns before introducing new abstractions.
3. Keep changes scoped to the requested feature, phase, or bug.
4. Do not revert or overwrite user changes unless explicitly requested.
5. Prefer implementation plus verification over proposal-only answers when the request is actionable.
6. Run the smallest relevant Flutter verification command after code changes and report the result.

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

1. Show user-visible errors in the UI instead of only logging them.
2. Field validation errors must appear under the matching input.
3. Form-level errors are only for errors that cannot be mapped to a specific field.
4. Clear a field error when the user edits that field.
5. Disable submit controls while requests are pending.
6. Keep loading, empty, and error states polished on every screen.
7. Prefer native Flutter Material widgets and platform permission flows.
8. Do not add visible instructional text unless the workflow genuinely needs it.

## Testing And Verification

1. Run `flutter analyze` after Dart changes when possible.
2. Run targeted widget or unit tests for changed behavior.
3. Run `flutter test` before finishing broad UI or controller changes.
4. If verification fails because of missing SDK, emulator, backend, or network, report the exact blocker and command needed to continue.

## Documentation

1. Update docs when behavior, architecture, use cases, or API expectations change.
2. Keep docs concise and aligned with the current implementation.
3. User-facing feature names may differ from internal technical names when that improves clarity.
