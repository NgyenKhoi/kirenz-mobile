# Feature 03: Feed, Post CRUD, and Post Media

## Scope And Dependencies

Includes Home feed, post card, create/edit/delete/share, privacy, friend tagging, post images, gallery viewer, refresh, and cached rendering.

## Contract Readiness

Status: current unpaginated feed, post CRUD/share, image upload, and gallery behavior are `Ready for mobile`. Pagination, post video, backend-owned media-count validation, and orphan cleanup remain `Backend gap`.


Depends on Features 01-02.

## Current Web Behavior To Preserve

- Home shows a create-post composer followed by post cards.
- Composer contains avatar, text, Photo, privacy, Tag, and Post actions.
- Privacy choices are PUBLIC, FRIENDS, and PRIVATE in UI; PRIVATE maps to backend `ONLY_ME`.
- Friend tagging searches the current friend list and shows selected count.
- Up to 10 images are selected; non-image selections are ignored.
- Each selected preview is square and has a top-right X.
- A post requires trimmed text or at least one image.
- Web opens a confirmation dialog before actual create.
- Images upload first; returned metadata is included in create request.
- Post card structure is author/meta, body, media, shared-post block where applicable, social summary, actions, and expanded comments.
- Owner menu supports edit/delete. Share creates a share post.
- Web media gallery renders at most four preview tiles and overlays `+N` on tile four.
- Fullscreen viewer uses black background, close/download, previous/next, and video rendering even though current post upload endpoint accepts images only.

## Backend Contracts

| Action | Contract |
| --- | --- |
| Feed | `GET /api/posts`. |
| Detail | `GET /api/posts/{postId}`. |
| Create | `POST /api/posts`. |
| Edit | `PATCH /api/posts/{postId}`. |
| Delete | `DELETE /api/posts/{postId}`. |
| Share | `POST /api/posts/{postId}/shares`. |
| Upload image | Multipart `POST /api/media/posts`. |

Exact mutation bodies:

```text
POST /api/posts
{ content, media: [{ type, url, publicId }], privacy, taggedUserIds }

PATCH /api/posts/{postId}
{ content, media: [{ type, url, publicId }], privacy }

POST /api/posts/{postId}/shares
{ caption }
```

`PATCH` does not edit `taggedUserIds`; current tags remain unchanged. Share has caption only and the backend currently creates the share with `PUBLIC` privacy. Mobile must not show edit-tags or share-privacy controls until those request contracts exist.

`POST /api/media/posts` returns `{ type, url, publicId, width, height, format, bytes }`; create/update submit only `{ type, url, publicId }` for each retained image.

Canonical post `data` shape:

```text
PostResponse { id, slug, author, content, privacy, originalPostId, sharedPost,
  media, taggedUserIds, taggedUsers, reactionsCount, reactionSummary,
  commentsCount, status, createdAt, updatedAt }
AuthorResponse { id, username, displayName, avatarUrl }
PostMediaResponse { type, url, publicId }
SharedPostResponse { id, author, content, privacy, media, available, createdAt }
PostPrivacy = PUBLIC | FRIENDS | ONLY_ME
PostStatus = ACTIVE | INACTIVE | DELETED
```

Treat `sharedPost.available=false` as canonical unavailable shared content; do not infer availability from missing media or author fields.

The upload response contains `width`, `height`, `format`, and `bytes`, but canonical `PostMediaResponse` currently does not persist/return those fields. Mobile may retain upload metadata in a device-local projection for the just-created item, but it must tolerate losing it after canonical refetch; adding canonical dimensions is a backend optimization gap, not a field the DTO may invent.

Current limits/gaps:

- Post media upload accepts image only, maximum 10 MB per image.
- Web limits selection to 10; backend must eventually own/validate the count explicitly.
- Feed is currently returned as an unpaginated list.
- No explicit client transaction cleans uploaded-but-uncommitted media.

## Routes And Navigation

- `/home`: feed.
- `/post/:postId`: canonical detail.
- Create/edit can be full screen or a tall route-backed sheet.

Tap ownership:

- Avatar/name -> profile.
- Media -> viewer.
- Comment count/Comment/body/timestamp -> post detail.
- Overflow/reaction/share/link controls handle themselves and must not trigger card navigation.

## Feed Screen

- Compact Moments header and create entry/FAB.
- Pull refresh keeps existing content visible.
- Initial loading uses post-card skeletons.
- Cached feed may render immediately with a stale/offline label, then reconcile.
- Empty state offers Create post or Explore.
- Fetch failure preserves cache and shows a retry surface.
- New/edited/deleted post updates feed and matching profile list without forcing app restart.

## Create Post Flow

1. Open composer.
2. Enter multiline content.
3. Select PUBLIC/FRIENDS/ONLY_ME.
4. Optionally open Tag friends, search, toggle users, and show selected chips/count.
5. Select up to 10 images.
6. Render previews immediately in a 2-3 column grid.
7. X removes exactly one local item and releases its preview resource.
8. Post is enabled when text or image exists and no blocking upload failure exists.
9. Confirm create, matching current web behavior.
10. Upload each image; show per-item progress/failure.
11. Commit post only after all retained items upload.
12. On success, prepend canonical response and clear composer.
13. On failure, preserve text, privacy, tags, uploaded metadata, and failed selections for Retry/Remove.

Do not silently truncate selections over 10. Explain the limit and keep the first accepted items.

## Edit Post Flow

- Owner-only overflow action.
- Initialize content, privacy, existing media, and tags supported by response.
- Existing media has staged Remove; local new images have immediate X.
- Cancel restores the original post.
- Save uploads only new images and sends retained existing plus uploaded media.
- Failure preserves edit state.
- Success replaces post by id across feed/detail/profile.

## Delete And Share

Delete:

- Owner-only.
- Confirm with destructive styling.
- Disable confirm while pending.
- On success remove by post id and leave detail with a short confirmation.
- On failure keep the post and expose retryable error.

Share:

- Open a caption-only share surface. Do not show privacy selection; the backend currently creates shares as PUBLIC.
- Success inserts the returned shared post.
- Render original author/content/media inside a visually subordinate shared block.
- If original becomes unavailable, show an unavailable shared-content placeholder without breaking the share post.

## Post Card

1. Header: avatar, display name, time, privacy icon/text, overflow.
2. Text: preserve line breaks; linkify supported hashtags/mentions without unsafe HTML.
3. Shared block when applicable.
4. Media gallery.
5. Reaction/comment summary.
6. React, Comment, Share row.
7. Optional comments preview only when expanded/detail behavior asks for it.

Long text should use a consistent collapsed/See more rule when implemented; do not let one card monopolize the feed.

## Gallery Layout

Mirror web visibility rule: show at most four feed tiles.

| Count | Mobile arrangement |
| --- | --- |
| 1 | One wide, aspect-aware image with a maximum height. |
| 2 | Two equal columns. |
| 3 | One large tile plus two smaller tiles. |
| 4 | 2x2. |
| 5-10 | 2x2, tile four overlays `+N`. |

- Reserve aspect geometry from upload metadata.
- Tiles have consistent clipping/gaps.
- Broken images retain the grid cell and show Retry/unavailable.
- Current create picker offers image only. Do not expose post video based solely on the web viewer's latent video support.

## Fullscreen Viewer

- Starts at tapped index and contains all media, not only four preview tiles.
- Edge-to-edge black surface.
- Close X in safe area; Back closes viewer first.
- Swipe next/previous; show index/total.
- Pinch/double-tap zoom image; disable page swipe while zoomed.
- Download/share action follows platform save/share flow.
- Restore feed/detail scroll position after close.

## Controller/Cache Behavior

- Key posts by id and reuse the same canonical entity in feed/detail/profile projections.
- Keep route/list projection state such as order and scroll separately from entity data.
- Ignore stale mutation responses using post id and mutation generation.
- Cached feed/detail is display-only while offline; keep drafts locally but do not claim post success.

## Behavior Completion Checklist

- [ ] Composer preserves web text/privacy/tag/image behavior and explicit 10-image limit.
- [ ] Every selected image has working X, upload state, retry, and remove.
- [ ] Create/edit/delete/share update every visible projection by post id.
- [ ] Post card tap targets do not conflict.
- [ ] Gallery 1/2/3/4/5+ and `+N` behave consistently.
- [ ] Full viewer closes to the same route/scroll location.
- [ ] Post video is hidden until backend upload supports it.
