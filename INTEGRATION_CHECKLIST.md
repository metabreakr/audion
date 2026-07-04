# Audion Playlist Integration Checklist

Quick reference checklist for integrating the playlist feature into Xcode.

## Pre-Integration Verification

- [x] All Swift files created (6 files)
- [x] PlaylistView.xib created
- [x] Player.swift modified
- [x] ViewController.swift modified
- [x] Documentation complete

## Xcode Integration Steps

### 1. Add Files to Project (5 min)

- [ ] Open `Audion.xcodeproj` in Xcode
- [ ] Right-click "Audion" group in Project Navigator
- [ ] Select "Add Files to 'Audion'..."
- [ ] Add these files (check "Copy items if needed" and "Audion" target):
  - [ ] PlaylistModels.swift
  - [ ] PlaylistManager.swift
  - [ ] PlaylistViewController.swift
  - [ ] PlaylistWindowManager.swift
  - [ ] PlaylistPreferencesViewController.swift
  - [ ] PlaylistView.xib

### 2. Build Test (2 min)

- [ ] Press ⌘B to build
- [ ] Verify no compilation errors
- [ ] If errors occur, check that all files are added to target

### 3. Create Playlist Menu (10 min)

- [ ] Open Main.storyboard
- [ ] Select "Main Menu" in Document Outline
- [ ] Add new "Menu" after "Controls" menu
- [ ] Set menu title to "Playlist"
- [ ] Add menu items (see detailed structure below)
- [ ] Set keyboard shortcuts:
  - [ ] Show/Hide Playlist → ⌘⇧P
  - [ ] Next Track → ⌘→
  - [ ] Previous Track → ⌘←

**Menu Structure:**
```
Playlist
├── Show/Hide Playlist (⌘⇧P)
├── ─── separator
├── Add Files to Playlist...
├── Save Playlist...
├── Load Playlist...
├── Clear Playlist
├── ─── separator
├── Next Track (⌘→)
├── Previous Track (⌘←)
├── ─── separator
└── Display Mode ▶
    ├── Floating Window
    ├── Menu Bar
    └── Slide-in Panel
```

### 4. Connect Menu Actions (5 min)

Connect each menu item to First Responder:

- [ ] Show/Hide Playlist → `togglePlaylist:`
- [ ] Add Files to Playlist → `addToPlaylist:`
- [ ] Next Track → `nextTrack:`
- [ ] Previous Track → `previousTrack:`
- [ ] Save Playlist → `savePlaylist:`
- [ ] Load Playlist → `loadPlaylist:`
- [ ] Clear Playlist → `clearPlaylist:`

### 5. Create PlaylistViewController Scene (10 min)

**Option A: Use XIB (Recommended)**
- [ ] PlaylistViewController will load from PlaylistView.xib automatically
- [ ] Set Storyboard ID in Identity Inspector: "PlaylistViewController"
- [ ] Verify custom class is set to `PlaylistViewController`

**Option B: Use Storyboard**
- [ ] Add new View Controller to Main.storyboard
- [ ] Set Storyboard ID: "PlaylistViewController"
- [ ] Set Custom Class: `PlaylistViewController`
- [ ] Recreate UI from PlaylistView.xib (table, buttons, etc.)
- [ ] Connect all outlets

### 6. Add Playlist Preferences Tab (10 min)

- [ ] Open Preferences window scene in Main.storyboard
- [ ] Add toolbar item "Playlist"
- [ ] Create new View Controller scene
- [ ] Set custom class: `PlaylistPreferencesViewController`
- [ ] Add UI elements:
  - [ ] Label: "Display Mode:"
  - [ ] NSPopUpButton (outlet: `uiModePopUp`)
  - [ ] Label: "Slide Direction:" (outlet: `slideDirectionLabel`)
  - [ ] NSPopUpButton (outlet: `slideDirectionPopUp`)
- [ ] Connect outlets
- [ ] Connect actions:
  - [ ] uiModePopUp → `uiModeChanged:`
  - [ ] slideDirectionPopUp → `slideDirectionChanged:`

### 7. Update Info.plist (5 min)

Add document type support:

- [ ] Open Info.plist
- [ ] Add `CFBundleDocumentTypes` array (if not exists)
- [ ] Add entry for "Audion Playlist" (.audionplaylist)
- [ ] Add entry for "M3U Playlist" (.m3u, .m3u8)
- [ ] Add `UTExportedTypeDeclarations` for custom type

**Quick Copy-Paste:**
```xml
<key>CFBundleDocumentTypes</key>
<array>
    <dict>
        <key>CFBundleTypeName</key>
        <string>Audion Playlist</string>
        <key>CFBundleTypeExtensions</key>
        <array>
            <string>audionplaylist</string>
        </array>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
    </dict>
    <dict>
        <key>CFBundleTypeName</key>
        <string>M3U Playlist</string>
        <key>CFBundleTypeExtensions</key>
        <array>
            <string>m3u</string>
            <string>m3u8</string>
        </array>
        <key>CFBundleTypeRole</key>
        <string>Viewer</string>
    </dict>
</array>
```

### 8. Final Build (2 min)

- [ ] Clean build folder (⌘⇧K)
- [ ] Build (⌘B)
- [ ] Verify no warnings or errors
- [ ] Run (⌘R)

## Testing Checklist

### Basic Functionality
- [ ] App launches without crash
- [ ] Press ⌘⇧P → Playlist window appears
- [ ] Click "Add Files..." → Can select audio files
- [ ] Files appear in playlist table
- [ ] Double-click track → Track plays
- [ ] Track finishes → Next track auto-plays
- [ ] Press ⌘→ → Skips to next track
- [ ] Press ⌘← → Goes to previous track

### UI Modes
- [ ] Open Preferences → Playlist tab exists
- [ ] Select "Floating Window" → Separate window appears
- [ ] Select "Menu Bar" → Icon appears in menu bar
- [ ] Click menu bar icon → Popover shows playlist
- [ ] Select "Slide-in Panel" + "Right" → Panel appears on right
- [ ] Select "Left" → Panel moves to left
- [ ] Move main window → Slide-in panel follows

### Playlist Operations
- [ ] Drag files onto playlist → Files added
- [ ] Drag track to new position → Track reorders
- [ ] Select track, press Delete → Track removed
- [ ] Click "Shuffle" → Tracks shuffle
- [ ] Uncheck "Shuffle" → Original order restored
- [ ] Click "Clear All" → Confirmation dialog appears
- [ ] Confirm clear → All tracks removed

### Persistence
- [ ] Add tracks to playlist
- [ ] Quit app (⌘Q)
- [ ] Relaunch app
- [ ] Press ⌘⇧P → Previous playlist restored

### Save/Load
- [ ] Menu → Playlist → Save Playlist
- [ ] Choose .audionplaylist → Saves successfully
- [ ] Clear playlist
- [ ] Menu → Playlist → Load Playlist
- [ ] Select saved file → Playlist restored
- [ ] Repeat with .m3u format

### Menu Validation
- [ ] Empty playlist → "Next Track" disabled
- [ ] Empty playlist → "Previous Track" disabled
- [ ] Play first track → "Previous Track" disabled
- [ ] Play last track → "Next Track" disabled
- [ ] Play middle track → Both enabled
- [ ] Check Display Mode → Current mode has checkmark

## Troubleshooting

### Build Issues

**Error: "Cannot find 'PlaylistManager' in scope"**
- Solution: Verify PlaylistManager.swift is added to Audion target
- Check: File Inspector → Target Membership → Audion ✓

**Error: "No such module 'Combine'"**
- Solution: Set deployment target to macOS 10.15+
- Check: Project Settings → Deployment Target

**XIB Loading Error**
- Solution: Verify PlaylistView.xib outlets are connected
- Check: Open XIB → Connections Inspector

### Runtime Issues

**Playlist doesn't show**
- Check: Storyboard ID is "PlaylistViewController"
- Check: Custom class is set correctly
- Check: ViewController.setupPlaylist() is called

**Crash on ⌘⇧P**
- Check: togglePlaylist: action is connected
- Check: PlaylistViewController outlets are valid

**Tracks don't auto-advance**
- Check: Player.swift has NotificationCenter observer
- Check: playerDidFinishPlaying selector exists

**Menu items always disabled**
- Check: validateUserInterfaceItem is implemented
- Check: Actions are connected to First Responder

## Success Criteria

✅ All items in Testing Checklist pass
✅ No compiler warnings
✅ No runtime crashes
✅ All three UI modes work
✅ Playlists persist between launches
✅ Keyboard shortcuts work

## Estimated Time

- **Minimum** (experienced developer): 30 minutes
- **Average**: 45 minutes
- **With troubleshooting**: 60 minutes

## Reference Documents

- **PLAYLIST_IMPLEMENTATION_GUIDE.md** - Detailed integration guide
- **PLAYLIST_FEATURE_SUMMARY.md** - Feature overview
- **MENU_STRUCTURE.md** - Complete menu layout

## Need Help?

1. Check the implementation guide for detailed steps
2. Review code comments in Swift files
3. Verify all outlets/actions are connected
4. Check Console.app for error messages
5. Review Apple documentation for NSTableView/AVFoundation

---

**Status**: Ready for integration
**Last Updated**: 2025-12-10
