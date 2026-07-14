# Feature 05: Friends, Explore, Privacy, and Blocks

## Scope And Dependencies

Includes user discovery, friend search/suggestions/list, incoming/outgoing requests, relationship actions, privacy settings, block/unblock, and the effect of those states on profile/chat/content.

## Contract Readiness

Status: friends, user search, privacy, blocks, and current composed Explore behavior are `Ready for mobile`. A dedicated server-side Explore/search API and pagination remain `Backend gap`.


Depends on Features 01-02.

## Current Web Behavior To Preserve

- Friends page exposes user search, suggestions, current friends, incoming requests, and outgoing requests.
- Search starts after at least two characters and shows searching/no-result/result states.
- Result cards show avatar, display name, username, optional bio, relationship state, and action.
- Incoming request supports Accept and Decline.
- Outgoing request supports Cancel.
- Friend list supports profile navigation and Remove.
- Suggestions support Send request.
- Privacy settings contain profile visibility, post visibility, allow direct messages, and show online status.
- Blocked Users lists blocked ids/date and confirms Unblock.
- Blocking prevents the target from finding/viewing/interacting according to backend policy; group chat can still need a blocked-user warning because both users may remain in a shared group.

Mobile improvement:

- Do not copy the web's “block by raw UUID” as the primary flow. Block should start from profile/user actions. The blocked list may retain a debug/manual id entry only in development builds if required.

## Backend Contracts

| Area | Contract |
| --- | --- |
| Search users | `GET /api/users/search?q=...`. |
| Mutual friends | `GET /api/users/{id}/mutual-friends`. |
| Send request | `POST /api/friends/requests`. |
| Incoming/outgoing | `GET /api/friends/requests/incoming|outgoing`. |
| Accept/decline | `POST /api/friends/requests/{id}/accept|decline`. |
| Cancel request | `DELETE /api/friends/requests/{id}`. |
| Friend list | `GET /api/friends` or `/friends/user/{userId}`. |
| Suggestions | `GET /api/friends/suggestions`. |
| Remove friend | `DELETE /api/friends/{friendId}`. |
| Relationship status | `GET /api/friends/status/{targetUserId}`. |
| Privacy | `GET/PUT /api/privacy/me`; `GET /api/privacy/user/{userId}`. |
| Block/unblock/list/status | `POST/DELETE /api/blocks/{userId}`, `GET /api/blocks`, `GET /api/blocks/status/{userId}`. |

Exact request/response `data` shapes and enums:

```text
SendFriendRequest { receiverId }
FriendRequestResponse { id, requesterId, receiverId, status, createdAt, updatedAt,
  respondedAt, username, displayName, avatarUrl, bio }
FriendResponse { friendshipId, friendId, username, displayName, avatarUrl, bio, createdAt }
FriendStatusResponse { userId, targetUserId, status }
FriendSuggestionResponse { id, username, displayName, avatarUrl, bio, mutualFriendCount }
MutualFriendResponse { id, username, displayName, avatarUrl, bio }
UserSearchResponse { id, username, displayName, avatarUrl, bio, relationshipStatus }
BlockResponse { id, blockedUserId, createdAt }
BlockStatusResponse { viewerId, targetUserId, blockedByViewer, blockedViewer }
UpdatePrivacyRequest { profileVisibility, postVisibility, allowDirectMessages, showOnlineStatus }
PrivacySettingsResponse { userId, profileVisibility, postVisibility, allowDirectMessages,
  showOnlineStatus, updatedAt }
RelationshipStatus = SELF | FRIENDS | OUTGOING_REQUEST | INCOMING_REQUEST |
  BLOCKED | BLOCKED_BY_TARGET | NONE
PrivacyVisibility = PUBLIC | FRIENDS_ONLY | PRIVATE
```

The friend-request `status` remains a backend string/enum projection; controllers must preserve unknown future values as an unsupported state rather than mapping them to `NONE`. Block direction is determined only by `blockedByViewer` and `blockedViewer`.

## Routes And Screen Structure

- `/explore`: combined content/user discovery with persistent query state.
- `/friends`: segmented Requests, Suggestions, Friends; search entry remains easy to reach.
- `/privacy`: privacy settings form.
- `/blocked-users`: blocked list.

Keep request/suggestion/friend badge counts if available. Preserve selected segment and scroll when returning from profile.


## Explore Composed Contract

There is no dedicated Explore endpoint today. Mobile mirrors the validated web composition:

1. Load privacy-filtered visible posts from `GET /api/posts`.
2. Build trending hashtags from unique hashtags per returned post, sort by descending post count then ascending tag, and keep the first ten.
3. Require a submitted trimmed query of at least two characters.
4. Search people with `GET /api/users/search?q=<query>&limit=12`.
5. Filter the already-loaded post list case-insensitively by content or hashtag after removing one leading `#` from the query.
6. Render People and Related posts as independent result sections.

Explore state must distinguish:

- Initial feed/trending loading or failure.
- No hashtags yet.
- Query shorter than two characters.
- People loading/empty/failure.
- Related-post empty state.
- Cached/stale posts while offline; user search is network-only.

A post mutation from Explore updates the shared post entity by id exactly like Home/Profile/Detail. Pull refresh reloads the post source and recomputes trending. Preserve query and scroll across profile/post round-trips.

This composition is correct for current parity but does not scale because `GET /api/posts` is unpaginated and post search is client-side. A dedicated paginated discovery/search API remains a recorded backend gap.
## User Search

- Debounce 400-500 ms after at least two trimmed characters.
- Cancel/ignore stale queries when text changes.
- Result row navigates to profile; action button must not trigger navigation.
- Relationship action mapping:
  - NONE -> Add friend.
  - SELF -> no relationship mutation; route to `/profile/me` where applicable.
  - OUTGOING_REQUEST -> Requested/Cancel.
  - INCOMING_REQUEST -> Accept with secondary Decline.
  - FRIENDS -> Friends/Unfriend action.
  - BLOCKED -> no friend action; offer Unblock only in appropriate menu.
  - BLOCKED_BY_TARGET -> no relationship or message action; render the backend-authorized restricted state without offering Unblock.
- Action pending is per user id, not a screen-wide lock.
- Success updates matching rows in search, suggestions, requests, friend list, and profile state.

## Requests, Suggestions, And Friends

- Incoming and outgoing are visually distinct.
- Accept removes request and adds friend.
- Decline/cancel removes request.
- Remove friend requires confirmation and removes friend only after success or rollback-safe optimistic behavior.
- Suggestions disappearing after a request must update without full navigation reload.
- Empty states explain the active segment, not a generic “no data”.

## Privacy Settings

Fields:

- Profile visibility: PUBLIC, FRIENDS_ONLY, PRIVATE.
- Post visibility default: PUBLIC, FRIENDS_ONLY, PRIVATE.
- Allow direct messages: boolean.
- Show online status: boolean.

Behavior:

- Load canonical settings before editing.
- Changes are staged until Save unless product explicitly chooses individual toggles with immediate save.
- Save pending disables repeated submit.
- Failure preserves staged values and shows a form-level recovery.
- Success replaces canonical settings and updates privacy-aware profile/chat/presence behavior.
- Unsaved Back opens Discard/Keep editing.

Do not locally reveal data hidden by backend privacy. The server response is authoritative.

## Block/Unblock

Block from profile:

1. Open user actions.
2. Confirm with target name and consequences.
3. Submit block.
4. Remove target's inaccessible posts/relationship actions and prevent new direct chat according to backend.
5. Existing shared group remains renderable; show a warning when backend signals/relationship state indicates a blocked participant.

Unblock:

- Available from blocked list and appropriate profile state.
- Confirm that visibility/interactions will again depend on privacy settings.
- Success removes blocked row and refreshes relationship/profile state.

## Behavior Completion Checklist

- [ ] Search is debounced, stale-safe, and maps every relationship status.
- [ ] Incoming/outgoing/suggestion/friend actions update all matching projections.
- [ ] Remove friend, block, and unblock use named confirmation.
- [ ] Privacy fields preserve backend enum meanings.
- [ ] Block effects propagate to profile/feed/direct chat without breaking shared groups.
- [ ] Segment, query, and scroll state survive profile round-trips.
