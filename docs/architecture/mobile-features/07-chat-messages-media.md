# Feature 07: Chat Messages and Attachments

## Scope And Dependencies

Includes history paging, message bubbles/system events, composer, text send, image/video/PDF/DOCX selection/upload/send, draft preview X, attachment grids, fullscreen viewer, downloads, unread/read behavior, and failure recovery.

## Contract Readiness

Status: history/read/upload/message DTO behavior is `Ready for mobile`; publishing is under the Feature 08 `Transport gate`. Acknowledgement/idempotency, delivery/read receipts, and message edit/delete remain `Backend gap`.


Depends on Feature 06 and the validated account-scoped connection manager/transport gate from Feature 08. The message UI may be developed against that interface, but publish acceptance waits for the transport spike.

## Current Web Behavior To Preserve

- History loads by conversation and is reversed into chronological UI order.
- New topic messages append live.
- Opening a conversation and receiving a message while it is active marks it read.
- Composer accepts trimmed text or attachments.
- Typing stop is sent after 1.5 seconds idle and after send.
- Picker accepts image, video, PDF, DOCX.
- Limits:
  - Up to 10 images/message.
  - Image 50 MB each.
  - Video 500 MB each.
  - PDF/DOCX 50 MB each.
- Invalid/oversize files produce visible errors.
- Selected image/video renders local preview; every item has top-right X.
- Web maps the flat upload response into STOMP attachment metadata and supplements original name/content type from the selected local file; the upload API does not return those two fields.
- Message bubble renders FILE as filename/size/download tile.
- Image/video attachments render a square grid: one column for one, two for two, three for three or more.
- Tapping image/video opens black fullscreen preview with Close and Download; video has controls.
- System messages are centered rather than shown as user bubbles.

Current reliability gap:

- STOMP send returns no client acknowledgement/idempotency id. Mobile cannot truthfully show delivery/read states. MVP states are Draft/Uploading/Publishing locally and server-confirmed only when the message returns via topic/history.

## Backend Contracts

| Action | Contract |
| --- | --- |
| History | `GET /api/messages/{conversationId}?page=0&size=50`. |
| Mark read | `POST /api/messages/{conversationId}/read`. |
| Upload | Multipart `POST /api/media/chat`, one file per request. |
| Send | STOMP publish `/app/chat.send` with conversationId/content/attachments. |
| Direct permission | `GET /api/privacy/can-message/{receiverId}`; Chat Service revalidates the same rule for every direct-message publish. |

Exact upload response:

```text
MediaUploadResponse
{ type, url, publicId, width, height, format, bytes }
```

Exact client transformation before STOMP publish:

```text
Attachment.type = upload.type
Attachment.url = upload.url
Attachment.cloudinaryPublicId = upload.publicId
Attachment.metadata.width/height/format/bytes = upload fields
Attachment.metadata.name = selected local file name
Attachment.metadata.contentType = selected local MIME type
```
Exact publish/receive shapes:

```text
SendMessageRequest { conversationId, content, attachments }
Attachment { type, url, cloudinaryPublicId, metadata }
MessageResponse { id, conversationId, senderId, senderName, senderAvatar, content,
  type, attachments, sentAt, status }
MessageType = TEXT | IMAGE | VIDEO | FILE | SYSTEM
MessageStatus = ACTIVE | DELETED
```

The open conversation receives `MessageResponse` from `/topic/conversation.{conversationId}`. The per-user `/user/queue/messages` payload is a conversation-list update, not a full message:

```text
ConversationUpdateMessage { conversationId, conversationName, lastMessage, unreadCount, updatedAt }
```

Attachment `metadata` is an open map. The mobile-owned keys required for current rendering are `width`, `height`, `format`, `bytes`, `name`, and `contentType`; unknown keys must be tolerated.

No message edit/delete/retry acknowledgement/read-receipt endpoint currently exists.

For a direct conversation, load canonical permission when the detail opens. `false` disables text, attachment selection, and Send while preserving the draft. A permission lookup failure is an unavailable/dependency error, not a privacy denial. Even after a `true` result, a later publish can be rejected because friendship/privacy changed; surface the sanitized STOMP application error and reconcile permission rather than claiming the message was sent.

## Message Detail Layout

- App bar: back, avatar/title, direct presence/group subtitle, settings.
- Scrollable reverse-friendly message history.
- Date separators.
- New messages pill when not at bottom.
- Typing indicator above composer.
- Composer pinned to keyboard/safe area.

## History Behavior

- Normalize REST page to chronological display.
- Load older page near top.
- Insert older items while preserving visible anchor.
- Deduplicate all sources by server message id.
- Group consecutive active user messages by same sender and close timestamp for avatar/name density.
- Own and other bubbles use distinct theme surfaces.
- System events remain compact/centered.
- Removed participant uses senderName/senderAvatar response snapshot/fallback.
- Deleted/unavailable attachment keeps its message/time and stable placeholder.

## Text Send

1. Trim only for emptiness check; preserve meaningful line breaks.
2. Send enabled for non-blank content or at least one valid attachment.
3. Prevent repeated publish while upload/publish is pending.
4. Send typing false.
5. Do not clear draft until publish is issued successfully.
6. Prefer clearing only after server echo when reliable correlation exists; with current API, retain a short publishing state and reconcile by returned topic message.
7. If socket is disconnected, keep draft and show Reconnecting/Retry; never discard it.

## Attachment Selection

- System picker filters image/video/PDF/DOCX.
- Validate MIME and extension defensively.
- Process every selected file; accepted items remain even when siblings are rejected.
- Explain each rejected reason.
- Count only images toward the 10-image limit; mixed video/document limits follow backend.
- Draft tray/grid appears above composer:
  - Image/video square thumbnail.
  - Video play badge.
  - Document icon, name, size.
  - Top-right X with at least 48x48 touch target.
- Removing revokes local preview and removes only that item.

## Upload And Publish

Each item tracks local/uploading/uploaded/failed.

- Upload independently so one failure does not force successful siblings to upload again.
- Per-item progress overlays tile.
- Failed item exposes Retry and X.
- Publish disabled while retained item is local/uploading/failed.
- STOMP attachment after client transformation:
  - `type`
  - `url`
  - `cloudinaryPublicId`
  - `metadata.width/height/format/bytes/name/contentType`
- A textless attachment message is valid.
- Cancelled composer leaves backend orphan cleanup to backend policy; mobile records no fake message.

## Bubble Attachment Grid

| Previewable count | Layout |
| --- | --- |
| 1 | One tile, max width about 260, aspect-aware. |
| 2 | Two square columns, max width about 320. |
| 3+ | Three square columns, wrapping, max width about 360. |

- FILE tiles span full bubble width.
- Mixed media preserves attachment order.
- Image/video tile tap opens viewer at the corresponding previewable index.
- File tap opens/downloads using platform flow and original name.
- Show formatted bytes when available.

## Fullscreen Viewer

- Edge-to-edge black.
- Close X and Download in safe area.
- Swipe across all previewable attachments in the message.
- Image pinch/double-tap zoom.
- Video controls and optional autoplay only for tapped video.
- Back closes viewer before chat.
- Returning keeps message scroll anchor.

## Read/Scroll Behavior

- On entering active detail, call mark read and locally set conversation unread to zero with reconciliation.
- For live messages while detail is active/foregrounded, mark read after message is incorporated.
- Auto-scroll only if user is near bottom or sent the message.
- Otherwise preserve position and increment New messages pill.
- Tapping pill scrolls to bottom and clears it.

## Behavior Completion Checklist

- [ ] History pages upward without jump and deduplicates REST/topic/cache.
- [ ] Disconnected send preserves draft.
- [ ] Picker validates every supported type and exact size/count limits.
- [ ] Every draft item has X, progress, failed Retry/Remove.
- [ ] Attachment-only messages have useful conversation/bubble previews.
- [ ] Bubble grid and file tiles preserve order/name/size.
- [ ] Viewer supports close/download/swipe/zoom/video and restores scroll.
- [ ] UI does not claim delivery/read receipt unsupported by backend.
