# Netflix-Style UI Redesign Plan - Lumio IPTV

## Context
User wants a complete visual redesign to a modern Netflix/TV set-top box style. All existing features (playback, playlists, favorites, EPG, DLNA, multi-screen, TV remote control) must remain fully functional. Only the visual layer changes.

## Design Direction
- **Dark-first**: Rich blacks (#0D0D0D) with subtle color accents
- **Netflix-style horizontal rows**: Channels in horizontally scrolling rows grouped by category
- **Large poster cards**: Channel cards with prominent logos, rounded corners, hover/focus zoom
- **Hero section**: Featured/continue-watching banner at top of home screen
- **Minimal chrome**: Hide controls until needed, clean overlays
- **Proper SafeArea**: All screens respect iOS notch/status bar
- **TV-optimized focus**: Large focus rings with scale animation for D-pad navigation

## Architecture Principle
Edit existing files only. No new screen files. No feature changes. Preserve all Provider logic, navigation routes, and platform branching.

---

## Phase 1: Design System Update
**File**: `lib/core/theme/app_theme.dart`

- Update `backgroundColorDark` to `#0D0D0D` (Netflix dark)
- Update `surfaceColorDark` to `#141414`, `cardColorDark` to `#1A1A1A`
- Reduce glassmorphism blur, use solid dark cards
- Add `heroGradient` for featured section overlays
- Update `GlassCard` to solid dark + subtle border on focus
- Update `TVFocusDecoration`: scale transform + white border

## Phase 2: Channel Card Redesign
**File**: `lib/core/widgets/channel_card.dart`

- Poster-style: logo fills card, text overlaid at bottom with gradient fade
- Focus: scale(1.08) + white 2px border + shadow
- EPG as small pill badge overlay
- Favorite heart as overlay badge (top-right)
- Solid dark card, rounded corners (radius 8)

## Phase 3: Home Screen - Netflix Layout
**File**: `lib/features/home/screens/home_screen.dart`

- Hero banner: last-watched channel with gradient overlay + play button
- Horizontal scroll rows per category (`ListView.builder` horizontal)
- Row headers: category name + "See All >"
- Bottom nav: pill-style icons, translucent background
- Wrap body in `SafeArea`
- Keep all Provider logic unchanged

## Phase 4: Channels Screen Fix
**File**: `lib/features/channels/screens/channels_screen.dart`

- `SliverAppBar.primary: true`, remove manual topPadding
- Updated card style from Phase 2
- Darker category sidebar with selected indicator

## Phase 5: Other Screens
- `favorites_screen.dart` - SafeArea, updated cards
- `search_screen.dart` - SafeArea, dark search bar
- `settings_screen.dart` - Grouped sections with dark cards
- `playlist_list_screen.dart` - Dark list tiles
- `splash_screen.dart` - SafeArea

## Phase 6: Navigation & Sidebar
- `tv_sidebar.dart` - Netflix vertical icon rail
- `category_card.dart` - Updated dark styling
- `window_title_bar.dart` - Minimal dark title bar

## Execution: Swarm (6 parallel agents)
| Agent | Files | Phase |
|-------|-------|-------|
| theme-agent | `app_theme.dart` | 1 |
| card-agent | `channel_card.dart`, `category_card.dart` | 2 |
| home-agent | `home_screen.dart` | 3 |
| channels-agent | `channels_screen.dart` | 4 |
| screens-agent | `favorites`, `search`, `settings`, `playlist_list`, `splash` | 5 |
| nav-agent | `tv_sidebar.dart`, `window_title_bar.dart` | 6 |

Phase 1-2 first, then 3-6 in parallel.

## Verification
1. iOS Simulator - SafeArea on all screens
2. Android - TV D-pad navigation
3. All features: playlist, playback, favorites, search, EPG, multi-screen, DLNA
4. Both dark and light themes
