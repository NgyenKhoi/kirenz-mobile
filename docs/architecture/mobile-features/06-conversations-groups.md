# Feature 06: Conversations and Group Management

## Scope And Dependencies

Includes conversation list, direct get-or-create, group creation, group settings, rename, add/kick/leave/delete, admins, and nicknames.

## Contract Readiness

Status: conversation list/direct/group and current group-management actions are `Ready for mobile`. Group avatar remains `Backend gap`; last-admin promotion is source-validated and documented below.


Depends on Features 02 and 05 plus authenticated chat REST client.

## Current Web Behavior To Preserve

- Conversation list shows avatar, title, last message, time, unread count, and direct-user presence.
- Direct title prefers participant nickname, then display name, username, and Unknown fallback.
- Group title uses group name or Group Chat; group avatar currently uses generated fallback.
- User search is debounced after two characters.
- Starting direct chat uses get-or-create and avoids inserting duplicate conversation rows.
- A disabled direct-message permission is a forbidden state; dependency verification failure is a separate backend error and must not be presented as a privacy choice.
- Creating a group requires a non-blank name and at least two selected other users.
- Group settings support rename, add member, make admin, nickname, kick, leave, and delete according to current user role.
- Kick/delete/leave use confirmations.
- A participant nickname overrides display name within that conversation.
- Users removed from a group remain identifiable in history.

## Backend Contracts

| Action | Contract |
| --- | --- |
| List/detail | `GET /api/conversations`, `GET /api/conversations/{id}`. |
| Direct | `POST /api/conversations/direct/{otherUserId}`. |
| Create group | `POST /api/conversations`. |
| Rename group | `PATCH /api/conversations/{id}`. |
| Delete group | `DELETE /api/conversations/{id}`. |
| Add member | `POST /api/conversations/{id}/participants?userId=...`. |
| Kick member | `DELETE /api/conversations/{id}/participants/{userId}`. |
| Leave | `POST /api/conversations/{id}/leave`. |
| Make admin | `POST /api/conversations/{id}/admins/{userId}`. |
| Nickname | `PATCH /api/conversations/{id}/nicknames/{userId}`. |

Exact request/response `data` shapes:

```text
CreateConversationRequest { name, type, participantIds }
UpdateConversationRequest { name }
UpdateNicknameRequest { nickname }
ConversationType = DIRECT | GROUP
ConversationResponse { id, type, name, participants, adminIds, currentUserAdmin,
  lastMessage, createdAt, updatedAt, unreadCount }
ParticipantInfo { userId, username, displayName, avatarUrl, allowDirectMessages,
  nickname, admin }
LastMessage { messageId, content, senderId, senderName, type, sentAt }
```

Return contracts are not uniform:

| Operation | `ApiResponse.data` |
| --- | --- |
| Create/direct/detail/rename/add/kick/make-admin/nickname | Canonical `ConversationResponse`. |
| List | `List<ConversationResponse>`. |
| Delete group/leave group | `null` (`ApiResponse<Void>`). Remove/exit locally only after success; do not deserialize a conversation. |

Group creation requires a nonblank name and at least three unique participants including the creator. Duplicate ids do not count toward the minimum. Direct creation must resolve to exactly two unique participants and uses get-or-create semantics.

Backend gaps/decisions:

- No group-avatar upload contract.
- No direct-conversation delete/rename by design.
- When the last admin leaves or is removed, backend promotes the first remaining participant. Mobile reconciles from the next canonical conversation/list event and must not choose an admin itself.

## Conversation List

- Sort canonical rows by `updatedAt` descending.
- Direct avatar is the other participant; group uses generated multi/avatar fallback.
- Last-message preview:
  - Own -> prefix You.
  - Text -> truncated text.
  - Image/video/file -> explicit Sent an image/video/file.
  - System -> readable event text.
  - No message -> No messages yet.
- Unread badge is conversation-specific; shell badge sums all counts.
- Pull refresh keeps current rows visible.
- Cached rows display offline/stale state and open cached history.

Realtime user-queue events update last message, time, unread count, and ordering. Unknown id triggers a conversation-list refetch.

## Start Direct Conversation

1. Open new-message search.
2. Search after two characters with debounce.
3. Filter/label blocked or DM-disallowed users according to returned state.
4. Tap result -> call get-or-create.
5. Insert only if id is absent.
6. Navigate to detail.

Repeated taps/pending calls for the same target are disabled or coalesced.

## Create Group

1. Enter group name.
2. Search and select users, excluding self and duplicates.
3. Selected members render as removable chips with X.
4. Create enabled only for trimmed name plus at least two selected members.
5. Pending locks duplicate creation.
6. Success inserts returned conversation, clears draft, closes sheet, and opens group.
7. Failure preserves name and members.
8. Closing with a non-empty draft asks Discard/Keep editing.

## Group Settings

Header:

- Group name, generated avatar, participant count, current-user admin status.

Member row:

- Avatar, nickname/display name, username, admin badge.
- Tap profile separately from member actions.

Role rules:

- Admin-only controls are hidden/disabled using `currentUserAdmin` and server response.
- Rename, add, make admin, and kick follow backend authorization.
- Any member can edit nicknames only as backend permits.
- Any member can leave.
- Delete group is admin-only.

## Action Behavior

Rename:

- Initialize current name, trim, disable unchanged/blank.
- Success replaces conversation everywhere.

Add:

- Search after two characters.
- Exclude self and existing participants.
- Add pending is per target.

Make admin:

- Confirm if product wants an explicit role consequence.
- Success refreshes admin badges and permissions.

Nickname:

- Empty nickname clears override if backend permits.
- Success updates title/member/message sender display in this conversation only.
- Nickname change system message renders in history.

Kick:

- Confirm with participant name.
- Success removes member but never rewrites/deletes their old messages.

Leave:

- Confirm access loss.
- Success removes conversation locally and returns to list.

Delete:

- Explain deletion scope.
- Success removes conversation for applicable members and leaves detail.

## State Reconciliation

- Conversation detail and list share entity by id.
- Rename/add/kick/make-admin/nickname replace the entity with returned `ConversationResponse`; leave/delete return `data=null`, so remove the entity only after a successful envelope and reconcile the list on resume/reconnect.
- If a realtime event arrives during settings edit, preserve local draft but show canonical member/role changes.
- If current user is kicked/deleted elsewhere, exit detail to an unavailable/removed state.

## Behavior Completion Checklist

- [ ] Conversation ordering, previews, unread and avatars cover every message/conversation type.
- [ ] Direct get-or-create cannot duplicate rows.
- [ ] Group draft preserves name/members on failure and protects discard.
- [ ] Settings expose only valid role actions.
- [ ] Response-bearing group mutations replace list/detail state by id; successful leave/delete remove the entity without attempting to decode `data`.
- [ ] Kick/leave/delete confirmations name their consequence.
- [ ] Removed-member history remains attributed correctly.
