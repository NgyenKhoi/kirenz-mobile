# Feature 02: Profile, Avatar, and Cover

## Scope And Dependencies

Includes current/other-user profile, edit profile dialog/screen, avatar replace, cover/banner replace, posts/photos/friends tabs, and privacy-aware profile actions.

## Contract Readiness

Status: profile read/edit and avatar/cover replace are `Ready for mobile`; avatar/cover delete are `Backend gap` and their controls remain absent.


Depends on Feature 01 session/current user.

## Current Web Behavior To Preserve

- Profile header uses a wide cover with a circular avatar overlapping it.
- Current user sees Edit Cover Photo and Edit Profile actions.
- Avatar change lives in Edit Profile and immediately uploads after an image is chosen.
- Cover edit is a separate route with current/new cover preview and a Save action.
- Invalid avatar type and upload failures are shown visibly.
- Profile displays posts, photos, and friends surfaces; photo tiles can open a fullscreen viewer.
- Other-user profile actions reflect friendship/block/privacy state.
- Missing avatar/cover uses fallbacks.

Web currently does not crop images and has no remove/reset action. Mobile should add crop/preview because it is a native quality improvement, but must not show Remove until backend support exists.

## Backend Contracts

| Action | Contract |
| --- | --- |
| Current profile | `GET /api/users/me`. |
| Other profile | `GET /api/users/{userId}`. |
| Edit fields | `PATCH /api/users/me`. |
| Replace avatar | Multipart `POST /api/users/me/avatar`, field `file`. |
| Replace cover | Multipart `POST /api/users/me/cover`, field `file`. |
| User posts | `GET /api/posts/user/{userId}`. |
| User photos | `GET /api/posts/user/{userId}/images`. |

Avatar/cover accept images only, maximum 10 MB.

Exact canonical profile shapes:

```text
UserProfileDTO { id, email, username, displayName, avatarUrl, coverPhotoUrl, bio,
  birthDate, gender, location, website, role, emailVerified, createdAt, updatedAt }
UpdateUserProfileRequest { displayName, bio, birthDate, gender, location, website }
Gender = MALE | FEMALE | OTHER | PREFER_NOT_TO_SAY
Role = USER | MODERATOR | ADMIN
```

`GET`, `PATCH`, avatar upload, and cover upload return the canonical `UserProfileDTO` inside `ApiResponse.data`. The Flutter repository must replace the whole canonical profile instead of synthesizing a partial response.

Backend gaps:

- No `DELETE /users/me/avatar`.
- No `DELETE /users/me/cover`.
- Old Cloudinary asset cleanup is not an exposed client concern.

## Routes

- `/profile/me`
- `/profile/:userId`
- `/profile/me/edit` or a full-height edit sheet
- Avatar/cover picker and crop are nested flows, not shell tabs.

## Profile Screen Structure

1. Collapsing/standard app bar with Back for other profile and actions menu.
2. Cover at a stable aspect ratio with placeholder.
3. Avatar overlapping the lower cover edge.
4. Name, username, bio/details, relationship/privacy state.
5. Primary actions: Edit Profile for self; relationship/message actions for others.
6. Posts/Photos/Friends segmented tabs.
7. Tab-specific loading, empty, error, and cached states.

The cover/avatar header should not jump when image metadata arrives. Reserve its geometry.

## Avatar Behavior

1. Tap avatar camera badge.
2. Open action sheet:
   - Take photo.
   - Choose from library.
   - View current photo when present.
   - Remove photo only after DELETE API exists.
3. Ask permission at the moment camera/library is chosen.
4. Validate image and size before crop/upload.
5. Correct EXIF orientation.
6. Crop 1:1 with zoom/pan and Cancel/Use photo.
7. Show the crop locally over the existing avatar with upload progress.
8. On success, replace current `UserProfileDTO`.
9. On failure, restore canonical avatar visually but keep selected crop available for Retry/Cancel.

Do not clear the current avatar while upload is pending.

## Cover/Banner Behavior

1. Tap Edit Cover.
2. Action sheet: camera, library, view current, remove only when supported.
3. Crop to the profile-header aspect; recommend 16:9 while allowing repositioning.
4. Show full header preview including avatar overlap so the user sees the final composition.
5. Save starts multipart upload and disables repeat taps.
6. Success updates the header and returns to profile.
7. Failure remains on editor with Retry and preserves selection.

## Edit Profile Behavior

- Initialize fields from current profile.
- Field errors appear below fields and clear when edited.
- Save is disabled when unchanged, invalid, or pending.
- Back/close with changed fields opens Discard changes / Keep editing.
- Server response replaces canonical current user and refreshes dependent surfaces.
- Avatar upload can be separate from text-field Save, but pending states must not overwrite one another.

## Cross-Screen Propagation

After current-user profile/avatar/cover success:

- Update session/current-user provider immediately.
- Refresh profile detail.
- Update the current user's author projection in visible feed posts/comments where state supports it.
- Refresh conversation/profile projections on next fetch; do not rewrite historical message ownership.
- Invalidate cached network image if the URL did not change.
- Do not mutate another user's cached profile accidentally.

## Other-User Profile

- Author/avatar taps from feed/comment/reaction/notification navigate here.
- Friendship status controls Add, Cancel request, Accept/Decline, Friends, or Unfriend behavior.
- Message opens get-or-create direct conversation only when permission allows.
- Block action requires confirmation and removes inaccessible content/actions after success.
- Private/blocked/unavailable sections show an intentional state rather than an endless loader.

## Photos Tab And Viewer

- Use API-provided user images; do not extract only from the currently loaded posts.
- Grid uses stable square thumbnails.
- Tap opens shared black fullscreen viewer at that index.
- Viewer supports close X, next/previous swipe, index count, image zoom, and download/share if allowed.
- Returning restores tab and scroll position.

## Behavior Completion Checklist

- [ ] Self and other-user profile have distinct actions.
- [ ] Avatar flow includes permission, validation, crop, preview, progress, Retry, and global propagation.
- [ ] Cover flow includes composition preview and preserves selection on failure.
- [ ] Edit fields protect unsaved changes.
- [ ] Posts/photos/friends tabs own complete loading/empty/error states.
- [ ] Photo viewer returns to the same tab/scroll position.
- [ ] Remove avatar/cover remains hidden while DELETE contracts are absent.
