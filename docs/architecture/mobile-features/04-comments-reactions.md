# Feature 04: Comments, Replies, and Reactions

## Scope And Dependencies

Includes post detail discussion, comment/reply create/edit/delete, post/comment reactions, picker animation, reaction summaries, and reaction-user detail.

## Contract Readiness

Status: comment/reply CRUD and all six post/comment reaction contracts are `Ready for mobile`. Comment pagination and direct single-comment navigation metadata remain `Backend gap`.


Depends on Feature 03.

## Current Web Behavior To Preserve

- Post cards can expand comments and also render a larger post/comment surface.
- Comments have author avatar/name, content, time, Reply, reaction action/summary, and owner menu.
- Reply composer is shown under the target comment.
- Nested comments use `parentCommentId`.
- Comment edit/delete are owner actions; failures are shown near the affected item.
- Post and comment reactions share six values and UI mapping:
  - LIKE 👍
  - LOVE ❤️
  - HAHA 😆
  - WOW 😮
  - SAD 😢
  - ANGRY 😡
- Reaction picker opens with scale/fade/spring animation.
- Clicking reaction totals can load the reacting-user list.
- Web reaction-user modal has All plus per-type filters and user rows linking to profiles.

## Backend Contracts

| Action | Contract |
| --- | --- |
| List comments | `GET /api/posts/{postId}/comments`. |
| Create/reply | `POST /api/posts/{postId}/comments` with optional `parentCommentId`. |
| Edit comment | `PATCH /api/posts/{postId}/comments/{commentId}`. |
| Delete comment | `DELETE /api/posts/{postId}/comments/{commentId}`. |
| Post reaction users | `GET /api/posts/{postId}/reactions`. |
| React/update post | `POST` or `PATCH /api/posts/{postId}/reactions`. |
| Remove own post reaction | `DELETE /api/posts/{postId}/reactions/me`. |
| Comment reaction users | `GET /api/comments/{commentId}/reactions`. |
| React/update comment | `POST` or `PATCH /api/comments/{commentId}/reactions`. |
| Remove own comment reaction | `DELETE /api/comments/{commentId}/reactions/me`. |

Comment lists are currently unpaginated.

Exact request/response `data` shapes:

```text
CreateCommentRequest { content, parentCommentId, taggedUserIds }
UpdateCommentRequest { content }
CommentResponse { id, postId, parentCommentId, author, content, taggedUserIds,
  reactionsCount, reactionSummary, status, createdAt, updatedAt }
CommentAuthor { id, username, displayName, avatarUrl }
ReactionRequest { type }
ReactionSummaryResponse { totalCount, currentUserReaction, breakdown }
ReactionUserResponse { userId, username, displayName, avatarUrl, type, reactedAt }
ReactionType = LIKE | LOVE | HAHA | WOW | SAD | ANGRY
```

Reaction create/update returns the canonical reaction summary used to replace the local summary. Reaction-user endpoints return the row list only when the detail sheet opens. Comment create/edit returns canonical `CommentResponse`; delete returns no comment entity, so remove/rebuild locally only after success.

`parentCommentId` is the only reply linkage. The client may flatten deeper visual nesting but must preserve that id on create and when rebuilding the thread.

## Post Detail Discussion Layout

1. Canonical post card without duplicate outer navigation.
2. Reaction/comment totals.
3. Comment sort control only if backend sorting exists; otherwise fixed server order.
4. Thread list.
5. Sticky composer above bottom safe area/keyboard.

Opening detail from a feed snapshot may paint immediately, but detail and comments refresh independently.

## Comment Composer

- Multiline input, current-user avatar, Send action.
- Send disabled for blank trimmed content or while pending.
- Keyboard submit behavior must not prevent newline unless product explicitly chooses send-on-enter.
- Pending comment appears in place or shows progress at composer.
- Failure preserves text and reply target with Retry.
- Success inserts canonical response and increments post comment count.

## Reply Behavior

1. Tap Reply.
2. Set `parentCommentId`.
3. Show `Replying to <displayName>` strip with X.
4. Focus composer and keep it above keyboard.
5. X cancels reply target but preserves draft text.
6. Success inserts under the root thread.

Render one indentation level. Replies to replies retain their real parent id but visually flatten under the root with `Replying to <name>` to avoid progressively narrow mobile content.

## Edit/Delete Comment

Edit:

- Owner-only overflow.
- Inline editor or focused sheet initialized with content.
- Cancel restores rendered content.
- Save disables duplicate taps.
- Failure keeps edit text and error near comment.
- Success replaces the comment by id and updates edited timestamp presentation if used.

Delete:

- Owner-only, destructive confirmation.
- On success remove by id and decrement count.
- If deleting a root would orphan visible replies, show a deleted placeholder or rebuild thread from canonical response; do not attach replies to the wrong root.
- Failure restores/keeps item.

## Reaction Gesture Contract

- Tap React with no current reaction -> LIKE.
- Tap active reaction -> remove own reaction.
- Long-press -> six-option picker.
- Select another type -> update current reaction.
- Picker order is fixed to LIKE, LOVE, HAHA, WOW, SAD, ANGRY.
- Active icon and label use that reaction's visual; state is not color-only.
- Picker appears above the action when space allows, otherwise as a compact sheet.
- Entrance uses short fade/scale and selection uses a spring/pop; reduced-motion removes spring/scale.

Apply the same contract to posts and comments.

## Reaction State Updates

Use `ReactionSummaryResponse`:

- `totalCount`
- `currentUserReaction`
- `breakdown`

On mutation:

- Optimistically update only if rollback snapshot is retained.
- Prevent or serialize rapid conflicting selections.
- Replace with canonical response on success.
- Roll back summary/label/count on failure and show a local error.
- Never derive per-type user lists from summary counts.

## Reaction Summary And User Sheet

- Summary shows up to three reaction icons with non-zero counts and total.
- Tap summary opens a draggable modal sheet.
- Fetch users only when sheet opens.
- Header displays total and Close/drag affordance.
- Filter chips:
  - All.
  - Only non-zero reaction types.
  - Each includes its count.
- User row: avatar, display name, username if present, reaction icon.
- Tap row -> profile.
- Switching filter is local over the fetched list.
- Loading, empty, request failure, and Retry stay inside sheet.

## Error/Unavailable Behavior

- Post deleted/private while detail open: replace discussion with unavailable state.
- Comment deleted by another client: remove/reconcile on refresh; an attempted mutation shows unavailable.
- Reacting user profile unavailable: keep row identity fallback and disable navigation if no user id.
- Offline: cached comments/reaction summary may display; composers/reactions stay disabled or visibly pending only if an outbox is later implemented.

## Behavior Completion Checklist

- [ ] Detail composer handles keyboard, pending, preserved failure draft, and canonical count.
- [ ] Reply target, cancel X, root/deep reply rendering are explicit.
- [ ] Owner edit/delete actions preserve data on failure.
- [ ] Post and comment reactions use identical six-type gesture rules.
- [ ] Rapid reaction changes cannot corrupt summary.
- [ ] Reaction-user sheet filters by All/non-zero type and routes to profile.
- [ ] Deleted/private/unavailable states do not strand the user.
