# Kirenz Mobile UI/UX Sync Guide

## 1. Purpose

This document is the UI/UX bridge between the existing Kirenz web app and the Flutter mobile app.

Use it whenever an agent implements or reviews mobile screens. The mobile app does not need to copy the web layout one-to-one, but it must preserve the same product identity, visual tokens, interaction patterns, and social-app behavior. The goal is that a user moving between web and mobile feels they are using the same product: Kirenz/Moments.

Primary references:

- Web theme tokens: `frontend/src/index.css`
- Web shell/navigation: `frontend/src/components/Layout.tsx`
- Web feed: `frontend/src/HomeFeed.tsx`
- Web post card: `frontend/src/components/Post/PostCard.tsx`
- Web auth surface: `frontend/src/Login.tsx`
- Mobile theme to align: `mobile/lib/app/theme.dart`
- Mobile shell to align: `mobile/lib/shared/widgets/main_shell.dart`

## 2. Product Personality

Kirenz currently presents the social surface under the "Moments" identity. The tone is warm, friendly, soft, and human. It should feel like a personal social space, not an enterprise dashboard and not a generic Material starter app.

Mobile should feel:

- Warm and social.
- Soft but structured.
- Media-forward where posts, avatars, cover photos, and chat attachments matter.
- One-handed and scroll-first.
- Familiar to users coming from the web app.

Mobile should avoid:

- Default blue Material seed colors.
- Sparse placeholder screens once a real feature is implemented.
- Sharp rectangular controls.
- Enterprise-style dense tables.
- Overly decorative landing-page sections inside the authenticated app.

## 3. Design Tokens To Share

The web app defines its design language in `frontend/src/index.css`. Flutter should mirror these values as closely as Material 3 allows.

### Typography

| Web | Mobile guidance |
| --- | --- |
| Font family: `Quicksand` | Prefer bundling Quicksand in Flutter assets. If not available yet, use system font temporarily but keep weights and sizing aligned. |
| Body text uses medium weight often | Use `FontWeight.w500` for body emphasis and `FontWeight.w700/w800` for labels, nav, names, and headings. |
| Brand/headings are bold and friendly | Use strong headings, but keep mobile screen titles compact. |

Recommended Flutter text mapping:

| Use | Flutter style intent |
| --- | --- |
| Brand text `Moments` | `titleLarge` or `headlineSmall`, `w800`, primary color. |
| Screen title | `titleLarge`, `w700`. |
| Post author / profile name | `titleMedium` or `titleLarge`, `w700`. |
| Metadata / time / privacy | `labelSmall`, `w700`, `onSurfaceVariant`. |
| Button labels | `labelLarge`, `w700`. |
| Feed body | `bodyLarge`, `w500`. |

### Color Palette

Do not use Flutter's current blue seed as the final product style. Use the web tokens below.

Light mode:

| Token | Hex | Usage |
| --- | --- | --- |
| `primary` | `#8b4e3e` | Main brand actions, active tabs, links, hashtag text. |
| `onPrimary` | `#ffffff` | Text/icons on primary. |
| `primaryContainer` | `#ffb09c` | Active nav pill/FAB background, warm highlights. |
| `onPrimaryContainer` | `#7a4032` | Text/icons on primary container. |
| `secondary` | `#765b06` | Secondary social actions, comments. |
| `secondaryContainer` | `#ffd97d` | Secondary buttons and warm badges. |
| `tertiary` | `#385f95` | Search/focus accents, share actions. |
| `tertiaryContainer` | `#a1c5ff` | Tertiary soft actions. |
| `error` | `#ba1a1a` | Errors and destructive action emphasis. |
| `errorContainer` | `#ffdad6` | Error banners/dialog surfaces. |
| `surface` | `#fdf9f3` | App background. |
| `surfaceContainerLowest` | `#ffffff` | Cards, modals, composer surfaces. |
| `surfaceContainerLow` | `#f7f3ed` | Navigation, inputs, subtle panels. |
| `surfaceContainer` | `#f1ede7` | Filled inputs, disabled/light controls. |
| `surfaceContainerHigh` | `#ebe8e2` | Hover/pressed equivalents, separators. |
| `surfaceContainerHighest` | `#e6e2dc` | Stronger neutral surfaces. |
| `onSurface` | `#1c1c18` | Primary text. |
| `onSurfaceVariant` | `#534340` | Secondary text, inactive nav. |
| `outline` | `#85736f` | Icon/outline text. |
| `outlineVariant` | `#d8c2bd` | Borders and dividers. |

Dark mode:

| Token | Hex |
| --- | --- |
| `primary` | `#ffb4a2` |
| `onPrimary` | `#561e12` |
| `primaryContainer` | `#72372b` |
| `onPrimaryContainer` | `#ffdad1` |
| `secondary` | `#e5c26b` |
| `secondaryContainer` | `#5a4400` |
| `tertiary` | `#a1c5ff` |
| `tertiaryContainer` | `#1b477c` |
| `surface` | `#161412` |
| `surfaceContainerLowest` | `#0f0e0c` |
| `surfaceContainerLow` | `#1d1b18` |
| `surfaceContainer` | `#221f1b` |
| `surfaceContainerHigh` | `#2d2925` |
| `surfaceContainerHighest` | `#38342e` |
| `onSurface` | `#e6e2dc` |
| `onSurfaceVariant` | `#d8c2bd` |
| `outline` | `#a08d8a` |
| `outlineVariant` | `#534340` |

Flutter implementation note:

- Prefer explicit `ColorScheme` values over `ColorScheme.fromSeed`.
- Keep `useMaterial3: true`.
- `scaffoldBackgroundColor` should map to `surface`.
- `CardTheme.color` should map to `surfaceContainerLowest` for feed cards and major content cards.
- Inputs can use `surfaceContainer` or `surfaceContainerLow`.

### Spacing And Shape

Web spacing is built around an 8px base.

| Pattern | Mobile guidance |
| --- | --- |
| Screen horizontal padding | `16` on phones, `24` on wider mobile/tablet. |
| Feed gap | `16-24` between composer/post cards. |
| Card padding | `16-20` on mobile. |
| Avatar/post header gap | `12-16`. |
| Bottom nav safe padding | Respect safe area; keep touch targets at least `48`. |

Shape language:

| Element | Radius guidance |
| --- | --- |
| Small tiles/list items | `12-16`. |
| Inputs/search fields | `24-999`, visually pill-like. |
| Action buttons | Pill when primary/social; at least `24` radius. |
| Feed post cards | `24-32`, matching web `rounded-[2rem]`. |
| Dialogs/bottom sheets | Top radius `24-32`. |
| Avatars | Full circle. |
| Media thumbnails | `12-20` depending on size. |

## 4. Navigation Contract

Web desktop uses a left navigation rail. Web mobile uses a fixed bottom nav with a centered create action. Flutter should use a native bottom navigation shell but preserve the same mental model.

Primary mobile tabs:

| Tab | Web label/icon | Mobile route | Notes |
| --- | --- | --- | --- |
| Home | Home | `/home` | Feed and composer entry. |
| Explore | Explore | `/explore` | Search/discovery. |
| Friends | Not in current web bottom nav but part of product | `/friends` | Keep as a tab if app needs six destinations; otherwise place under profile/menu. |
| Chat | Messages | `/chat` | Must show unread badge. |
| Alerts | Notifications/Alerts | `/notifications` | Must show unread badge. |
| Profile | Profile | `/profile/me` | Current user profile and settings entry. |

Mobile shell guidance:

- Use `NavigationBar` or custom bottom navigation with Material 3 colors.
- Selected destination uses `primary` or `primaryContainer`.
- Inactive destinations use `onSurfaceVariant`.
- Chat and notification badges are separate: chat unread badges come from chat realtime state; notification badges come from notification service state.
- Use a floating or centered create-post action on feed-first contexts. It should use `primaryContainer/onPrimaryContainer` and the plus/edit icon pattern from web.
- Keep app bars minimal. The feed can show a compact "MOMENTS" or "Moments" brand header on mobile.

## 5. Screen-Level Layout Guidance

### Auth

Web auth uses a warm two-column card with a visual side on desktop and a compact centered brand header on mobile.

Flutter auth should:

- Show "Moments" or "Kirenz" branding prominently at the top.
- Use warm surface background, not blue.
- Use pill-shaped text fields with icons.
- Use a full-width primary pill button.
- Show Google login as a secondary outlined/pill action.
- Keep field-specific errors close to fields and form-level errors in `errorContainer`.
- Route unverified users into OTP verification, consistent with web.

### Feed

The feed is the product's main surface. It should mirror web behavior while using native mobile layout.

Flutter feed should:

- Use `CustomScrollView` or `ListView.builder`.
- Constrain content to a comfortable width on tablets but full-width on phones.
- Include a composer entry near the top or a FAB that opens the composer bottom sheet.
- Render post cards with the web hierarchy: author row, metadata/privacy, content, media, reaction/comment counts, action row.
- Use pull-to-refresh and pagination.
- Use skeleton loaders instead of only a spinner for mature screens.
- Keep empty state warm and simple: icon, short title, one helpful action.

### Post Card

Post cards are rounded white/surface cards with subtle borders and shadows on web.

Mobile post card structure:

1. Header row: avatar, author name, time, privacy, overflow menu.
2. Body content: text with hashtags in primary color.
3. Media gallery: image/video thumbnails with full-screen viewer.
4. Social summary: reaction count and comment count.
5. Action row: react, comment, share.
6. Comments preview or comment composer only when expanded/detail view.

Interaction guidance:

- Overflow actions open a modal bottom sheet.
- Edit/delete/share confirmations match web behavior.
- Reaction picker should feel native: bottom sheet, horizontal picker, or anchored overlay.
- Post detail should open as a full screen or large bottom sheet on mobile, not a tiny dialog.

### Profile

Web profile behavior includes avatar, cover photo, edit profile, privacy-aware viewing, photos/friends tabs.

Flutter profile should:

- Use a cover photo header with avatar overlapping the cover when data is available.
- Keep name, username/email, relationship status, and primary actions near the top.
- Use tabs for posts/photos/friends or equivalent segmented control.
- Put privacy/settings/logout in app bar actions or profile settings, not as random list placeholders.
- Avatar and cover upload actions should use image picker bottom sheets.

### Explore And Friends

Flutter should preserve the discovery feel:

- Search field at the top, pill-shaped, surface-container background.
- User cards show avatar, display name, username/mutual info, and a clear friendship action.
- Suggestions/requests/friends should use tabs or segmented controls.
- Friend request actions should be one-tap with optimistic UI only if rollback is handled.

### Chat

Chat must feel like a native messaging app while matching Kirenz colors.

Flutter chat should:

- Conversation list uses avatar/group avatar, title, last message, time, unread badge, online/presence indicator.
- Chat detail has a stable bottom composer, attachment button, send button, and typing indicator.
- Own messages and other messages should use distinct bubbles based on `primaryContainer` and `surfaceContainerLow`.
- System messages for nickname changes/leaves are centered, compact, and use `onSurfaceVariant`.
- Attachments support image, video, PDF, and DOCX with recognizable icons and filenames.
- Group management actions use bottom sheets and confirm dialogs for destructive operations.

### Notifications

Web uses a drawer with avatar, unread dot, actor name, message, and timestamp.

Flutter notifications should:

- Use a list screen with unread state visible.
- Unread notifications can use `primaryContainer` tint or a primary dot.
- "Mark read" and "Mark all read" actions should be available.
- Tapping a notification deep-links to profile, post, settings, or relevant screen per web routing logic.

## 6. Component Rules For Mobile Agents

Use these components consistently:

| Need | Preferred mobile pattern |
| --- | --- |
| Primary action | `FilledButton` styled as pill with `primary/onPrimary`. |
| Secondary action | `OutlinedButton` or `TextButton` with primary text. |
| Destructive action | `errorContainer/onErrorContainer` confirmation first. |
| Screen actions | `IconButton` with tooltip/semantic label. |
| More actions | `ModalBottomSheet`. |
| Create post/media picker/privacy selector | `ModalBottomSheet`. |
| Confirmation | `AlertDialog` or custom dialog using surface tokens. |
| Loading list | Skeleton/shimmer-like placeholders when available; otherwise shaped placeholder cards. |
| Pull refresh | `RefreshIndicator`. |
| Empty/error state | Centered icon, title, short message, optional retry/action. |
| Image loading | `cached_network_image` with placeholder and error avatar/media fallback. |

## 7. Implementation Checklist For Agents

Before implementing a mobile screen:

- Check the matching web screen/component first.
- Identify the matching API behavior from `MOBILE_APP_PLANNING.md`.
- Reuse the Kirenz color tokens in `theme.dart`.
- Preserve user-facing labels where they create product continuity: `Moments`, `Home`, `Explore`, `Messages`, `Alerts`, `Profile`.
- Prefer mobile-native layout over web layout, but keep the same hierarchy and actions.

When reviewing a mobile screen:

- Does it look like Kirenz/Moments rather than default Flutter?
- Are colors pulled from the shared token set?
- Are cards, inputs, and buttons rounded consistently?
- Are loading, empty, error, and permission states present?
- Are destructive actions confirmed?
- Are chat unread badges and social notification badges treated separately?
- Does the screen support pull-to-refresh where expected?

## 8. First Alignment Tasks

Recommended first UI/UX sync tasks for the current Flutter app:

1. Replace `ColorScheme.fromSeed` blue theme in `mobile/lib/app/theme.dart` with explicit Kirenz light/dark color schemes from this guide.
2. Add Quicksand font assets or document the temporary fallback.
3. Update `MainShell` bottom navigation colors and badges to match web behavior.
4. Replace placeholder feed with a Kirenz-style feed scaffold: brand header, composer entry/FAB, post-card skeletons.
5. Update auth screens to use the Moments visual style: warm background, brand header, pill inputs/buttons.
6. Update profile screen from a simple card/list to cover-photo + avatar + tabs structure.

## 9. Relationship To Mobile Planning

`MOBILE_APP_PLANNING.md` defines architecture, APIs, feature scope, state management, and roadmap.

This file defines the visual and interaction contract. If the two documents conflict:

- Architecture/API decisions come from `MOBILE_APP_PLANNING.md`.
- Visual styling, layout behavior, component shape, and screen UX decisions come from this file.
