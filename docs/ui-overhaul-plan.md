# Lumio IPTV - UI Overhaul Plan

## Critical Issues

### 1. NAVIGATION BLOCKER (P0)
- Clicking "MORE" on category row pushes to ChannelsScreen
- ChannelsScreen has NO back button when pushed from home
- User gets STUCK - cannot access Settings, Favorites, Home
- **Fix:** Pass forceShowBackButton:true when pushing from home

### 2. HERO SECTION BUTTONS (P1)
- Glass-highlighted buttons look broken on dark cards
- White filled "PLAY NOW" clashes with theme
- **Fix:** Semi-transparent pill buttons, streaming style

### 3. HEADER DESIGN (P1)
- Icon buttons lack IPTV streaming identity
- **Fix:** Redesign with gradient accent play button

### 4. CHANNEL ROW (P2)
- Fixed card row cuts off on narrow screens
- **Fix:** Horizontal scroll ListView (Netflix-style)

## Execution Tracker

- [x] Phase 1: Fix navigation (back button on ChannelsScreen)
- [x] Phase 2: Hero section button redesign
- [x] Phase 3: Header streaming redesign
- [x] Phase 4: Channel row horizontal scroll
- [x] Phase 5: Build + verify on simulator
- [x] Phase 6: Push to master
