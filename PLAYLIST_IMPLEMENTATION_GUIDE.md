# Audion Playlist Feature - Implementation Guide

This guide explains how to complete the integration of the playlist feature into Audion.

## Overview

A comprehensive playlist feature has been implemented with the following capabilities:

### Core Features
- ✅ Queue multiple tracks for sequential playback
- ✅ Auto-advance to next track when current finishes
- ✅ Next/Previous track navigation
- ✅ Drag & drop reordering
- ✅ Add/remove tracks
- ✅ Clear playlist
- ✅ Shuffle/unshuffle
- ✅ Save/Load playlists (.m3u and .audionplaylist formats)
- ✅ Automatic metadata extraction (title, artist, album, duration)
- ✅ Persistent playlist (saved between sessions)

### UI Modes
Three display modes are implemented:
1. **Floating Window** - Standalone playlist window
2. **Menu Bar** - Popover from menu bar icon
3. **Slide-in Panel** - Panel attached to main window (left or right)

## Files Added

The following new files have been created:

1. **PlaylistModels.swift** - Data models for tracks and playlists
2. **PlaylistManager.swift** - Queue management and persistence logic
3. **PlaylistViewController.swift** - Table view controller for playlist UI
4. **PlaylistWindowManager.swift** - Manages the three UI display modes
5. **PlaylistPreferencesViewController.swift** - Preferences for playlist settings
6. **PlaylistView.xib** - Interface layout for playlist table view

## Files Modified

1. **Player.swift** - Added playlist queue support and auto-advance
2. **ViewController.swift** - Added playlist actions and integration

## Xcode Project Integration

### Step 1: Add Files to Xcode Project

1. Open `Audion.xcodeproj` in Xcode
2. Right-click on the "Audion" folder in the project navigator
3. Select "Add Files to Audion..."
4. Add these files:
   - PlaylistModels.swift
   - PlaylistManager.swift
   - PlaylistViewController.swift
   - PlaylistWindowManager.swift
   - PlaylistPreferencesViewController.swift
   - PlaylistView.xib

### Step 2: Update Main.storyboard

Open `Main.storyboard` and make the following changes:

#### A. Add Playlist Menu

1. Add a new menu to the menu bar called "Playlist"
2. Position it between "Controls" and "Window" menus
3. Add the following menu items:

```
Playlist Menu
├── Show/Hide Playlist (⌘⇧P) → togglePlaylist:
├── ─── (separator)
├── Add Files to Playlist... → addToPlaylist:
├── Save Playlist... → PlaylistViewController.savePlaylist:
├── Load Playlist... → PlaylistViewController.loadPlaylist:
├── Clear Playlist → PlaylistViewController.clearPlaylist:
├── ─── (separator)
├── Next Track (⌘→) → nextTrack:
├── Previous Track (⌘←) → previousTrack:
├── ─── (separator)
└── Display Mode (submenu)
    ├── Floating Window → (checkmark based on preference)
    ├── Menu Bar → (checkmark based on preference)
    └── Slide-in Panel → (checkmark based on preference)
```

#### B. Update Preferences Window

1. Open the Preferences window scene in Main.storyboard
2. Add a new toolbar item labeled "Playlist"
3. Create a new view controller scene for PlaylistPreferencesViewController
4. Set the view controller's custom class to `PlaylistPreferencesViewController`
5. Add the following UI elements:
   - Label: "Display Mode:"
   - NSPopUpButton for UI mode selection (bind to `uiModePopUp`)
   - Label: "Slide Direction:" (bind to `slideDirectionLabel`)
   - NSPopUpButton for slide direction (bind to `slideDirectionPopUp`)

#### C. Create PlaylistViewController Scene

1. Add a new View Controller scene to Main.storyboard
2. Set its Storyboard ID to "PlaylistViewController"
3. Set custom class to `PlaylistViewController`
4. You can either:
   - Reference the PlaylistView.xib file, OR
   - Recreate the interface in the storyboard with the same outlets

### Step 3: Configure Keyboard Shortcuts

In Main.storyboard, add keyboard shortcuts to menu items:

| Menu Item | Key Equivalent | Modifiers |
|-----------|----------------|-----------|
| Show/Hide Playlist | P | ⌘⇧ (Command+Shift) |
| Next Track | → | ⌘ (Command) |
| Previous Track | ← | ⌘ (Command) |

### Step 4: Connect Menu Actions

Ensure these menu items are connected to First Responder actions:

- **Show/Hide Playlist** → `togglePlaylist:`
- **Add Files to Playlist** → `addToPlaylist:`
- **Next Track** → `nextTrack:`
- **Previous Track** → `previousTrack:`
- **Save Playlist** → `savePlaylist:`
- **Load Playlist** → `loadPlaylist:`
- **Clear Playlist** → `clearPlaylist:`

### Step 5: Update Info.plist

Add support for playlist file types:

```xml
<key>CFBundleDocumentTypes</key>
<array>
    <dict>
        <key>CFBundleTypeName</key>
        <string>Audion Playlist</string>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>LSItemContentTypes</key>
        <array>
            <string>com.panic.audion.playlist</string>
        </array>
        <key>NSDocumentClass</key>
        <string>PlaylistDocument</string>
    </dict>
    <dict>
        <key>CFBundleTypeName</key>
        <string>M3U Playlist</string>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>LSItemContentTypes</key>
        <array>
            <string>public.m3u-playlist</string>
        </array>
    </dict>
</array>

<key>UTExportedTypeDeclarations</key>
<array>
    <dict>
        <key>UTTypeConformsTo</key>
        <array>
            <string>public.data</string>
            <string>public.content</string>
        </array>
        <key>UTTypeDescription</key>
        <string>Audion Playlist</string>
        <key>UTTypeIdentifier</key>
        <string>com.panic.audion.playlist</string>
        <key>UTTypeTagSpecification</key>
        <dict>
            <key>public.filename-extension</key>
            <array>
                <string>audionplaylist</string>
            </array>
        </dict>
    </dict>
</array>
```

## UserDefaults Keys

The following preference keys are used:

- `playlistUIMode` (String) - Current UI mode: "Floating Window", "Menu Bar", or "Slide-in Panel"
- `playlistSlideDirection` (String) - Slide direction: "Left" or "Right"
- `playlistVisible` (Bool) - Whether playlist is currently visible

## File Formats

### .audionplaylist Format
JSON format with full metadata:
```json
{
  "name": "My Playlist",
  "tracks": [
    {
      "id": "UUID",
      "url": "file:///path/to/track.mp3",
      "title": "Track Title",
      "artist": "Artist Name",
      "album": "Album Name",
      "duration": 180.5,
      "addedDate": "2025-12-10T12:00:00Z"
    }
  ],
  "createdDate": "2025-12-10T12:00:00Z",
  "modifiedDate": "2025-12-10T12:00:00Z"
}
```

### .m3u Format
Standard M3U extended format:
```
#EXTM3U
#EXTINF:180,Track Title
/path/to/track.mp3
```

## Usage Instructions for Users

### Opening the Playlist

- **Keyboard**: Press `⌘⇧P` (Command+Shift+P)
- **Menu**: Select "Playlist" → "Show/Hide Playlist"
- **Menu Bar Mode**: Click the playlist icon in menu bar

### Adding Tracks

1. **From Playlist window**: Click "Add Files..." button
2. **From menu**: Select "Playlist" → "Add Files to Playlist..."
3. **Drag & drop**: Drag audio files directly onto playlist table

### Playing Tracks

- **Double-click** any track to play it immediately
- Use **⌘→** to skip to next track
- Use **⌘←** to go to previous track

### Managing Playlist

- **Reorder**: Drag tracks within the table
- **Remove**: Select track(s) and press Delete key
- **Shuffle**: Check the "Shuffle" checkbox
- **Clear**: Click "Clear All" button

### Saving/Loading

- **Save**: "Playlist" → "Save Playlist..." → Choose .audionplaylist or .m3u
- **Load**: "Playlist" → "Load Playlist..." → Select a playlist file

### Changing Display Mode

1. Open Preferences (⌘,)
2. Go to "Playlist" tab
3. Select desired "Display Mode":
   - **Floating Window**: Independent window that stays on top
   - **Menu Bar**: Popover accessed from menu bar icon
   - **Slide-in Panel**: Panel attached to main window
4. If using Slide-in Panel, choose direction (Left/Right)

## Testing Checklist

After integration, test the following:

- [ ] Build succeeds without errors
- [ ] Playlist window opens with ⌘⇧P
- [ ] Can add files to playlist
- [ ] Double-click plays track
- [ ] Auto-advance works (track finishes → next plays)
- [ ] Next/Previous track navigation works
- [ ] Shuffle mode works correctly
- [ ] Drag & drop reordering works
- [ ] Can remove tracks
- [ ] Can clear entire playlist
- [ ] Playlist persists between app restarts
- [ ] Can save playlist as .audionplaylist
- [ ] Can save playlist as .m3u
- [ ] Can load saved playlists
- [ ] All three display modes work:
  - [ ] Floating window
  - [ ] Menu bar popover
  - [ ] Slide-in panel (left)
  - [ ] Slide-in panel (right)
- [ ] Preferences UI works
- [ ] Switching modes works correctly
- [ ] Current track is highlighted in playlist

## Architecture Notes

### Data Flow

```
User Action
    ↓
ViewController / PlaylistViewController
    ↓
PlaylistManager (singleton)
    ↓
Player (opens track, manages playback)
    ↓
AVPlayer (actual audio playback)
```

### Key Classes

- **PlaylistManager**: Central state manager (singleton)
  - Manages track queue
  - Handles persistence
  - Provides published properties for SwiftUI/Combine

- **PlaylistWindowManager**: UI mode manager (singleton)
  - Creates/manages windows for each mode
  - Handles mode switching
  - Manages visibility state

- **Player**: Extended with playlist support
  - Auto-advance on track finish
  - Navigation methods (next/previous)
  - References PlaylistManager

### Thread Safety

- PlaylistManager uses `@Published` properties
- All UI updates happen on main thread via Combine
- File I/O operations are synchronous (acceptable for playlist sizes)

## Troubleshooting

### Build Errors

**"Cannot find type 'PlaylistTrack'"**
- Ensure PlaylistModels.swift is added to the target

**"Ambiguous reference to member 'togglePlaylist'"**
- Check that ViewController has the `@IBAction` methods defined

### Runtime Issues

**Playlist doesn't appear**
- Check that PlaylistViewController is properly instantiated
- Verify Storyboard ID is set to "PlaylistViewController"
- Ensure PlaylistView.xib outlets are connected

**Crash on launch**
- Verify all IBOutlet connections in XIB/Storyboard
- Check that view controller classes are set correctly

**Playlist not persisting**
- Check file permissions for ~/Library/Application Support/Audion/
- Verify PlaylistManager.shared.saveCurrentPlaylist() is being called

## Future Enhancements

Potential additions for future versions:

1. **Repeat modes** - Repeat one, repeat all, repeat off
2. **Search/filter** - Filter tracks by name, artist, album
3. **Smart playlists** - Auto-populate based on criteria
4. **Album art** - Display in playlist table
5. **Edit metadata** - Inline editing of track info
6. **Multiple playlists** - Support for managing multiple named playlists
7. **Import iTunes/Music playlists** - Read .xml library files
8. **Lyrics display** - Show synchronized lyrics during playback
9. **Queue mode** - Temporary queue separate from playlist
10. **Keyboard shortcuts** - Additional shortcuts for playlist operations

## Support

For issues or questions:
- Review the code comments in each Swift file
- Check the Audion project documentation
- Refer to Apple's documentation for NSTableView and AVFoundation

---

**Implementation Status**: ✅ Complete - Ready for Xcode integration

**Estimated Integration Time**: 30-45 minutes

**Compatibility**: macOS 10.15+ (required for some modern APIs)
