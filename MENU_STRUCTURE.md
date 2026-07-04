# Audion Playlist Menu Structure

## Main Menu Bar

```
Audion    File    Edit    Controls    Playlist    Window    Help
                                        ^^^^^^^^
                                      (NEW MENU)
```

## Playlist Menu (Complete Structure)

```
Playlist
├── Show/Hide Playlist                    ⌘⇧P
├── ───────────────────────────────────────────
├── Add Files to Playlist...
├── Save Playlist...
├── Load Playlist...
├── Clear Playlist
├── ───────────────────────────────────────────
├── Next Track                             ⌘→
├── Previous Track                         ⌘←
├── ───────────────────────────────────────────
└── Display Mode                            ▶
    ├── ✓ Floating Window
    ├──   Menu Bar
    └──   Slide-in Panel
```

## Menu Item Details

### Show/Hide Playlist
- **Action**: `togglePlaylist:`
- **Target**: First Responder
- **Shortcut**: ⌘⇧P (Command+Shift+P)
- **Behavior**: Toggles playlist visibility based on current mode

### Add Files to Playlist...
- **Action**: `addToPlaylist:`
- **Target**: First Responder
- **Behavior**: Opens file picker to add audio files

### Save Playlist...
- **Action**: `savePlaylist:`
- **Target**: PlaylistViewController
- **Behavior**: Save current playlist as .audionplaylist or .m3u

### Load Playlist...
- **Action**: `loadPlaylist:`
- **Target**: PlaylistViewController
- **Behavior**: Load a saved playlist file

### Clear Playlist
- **Action**: `clearPlaylist:`
- **Target**: PlaylistViewController
- **Behavior**: Remove all tracks from playlist (with confirmation)

### Next Track
- **Action**: `nextTrack:`
- **Target**: First Responder
- **Shortcut**: ⌘→ (Command+Right Arrow)
- **Validation**: Enabled only when next track exists

### Previous Track
- **Action**: `previousTrack:`
- **Target**: First Responder
- **Shortcut**: ⌘← (Command+Left Arrow)
- **Validation**: Enabled only when previous track exists

### Display Mode (Submenu)
- **Checkmarks**: Show current mode selection
- **Actions**: Change PlaylistWindowManager mode
- **Modes**:
  - Floating Window: Independent window
  - Menu Bar: Popover from status bar
  - Slide-in Panel: Attached panel (left/right)

## Keyboard Shortcuts Summary

| Shortcut | Action | Notes |
|----------|--------|-------|
| ⌘⇧P | Toggle Playlist | Show/hide playlist in current mode |
| ⌘→ | Next Track | Skip to next track in playlist |
| ⌘← | Previous Track | Go to previous track |
| ⌘, | Preferences | Access playlist settings (existing) |
| ⌫ (Delete) | Remove Track | When playlist has focus |
| Space | Play/Pause | When playlist has focus (standard) |
| ↑↓ | Navigate | Select tracks in list |
| ⌘A | Select All | Select all tracks (standard) |

## Context Menu (Right-click on Playlist Track)

```
Context Menu (on track)
├── Play
├── ───────────────────
├── Remove from Playlist
└── Show in Finder
```

## Implementation in Xcode

### Creating the Menu in Interface Builder

1. Open Main.storyboard
2. Find the Main Menu object
3. Add new menu after "Controls":
   - Drag "Menu" from Object Library
   - Title: "Playlist"
4. Add menu items as listed above
5. For Display Mode submenu:
   - Add "Menu Item" under "Display Mode"
   - Add 3 items for each mode
   - Set tags: 0 (Floating), 1 (Menu Bar), 2 (Slide-in)

### Setting Keyboard Shortcuts

In Interface Builder:
1. Select menu item
2. In Attributes Inspector → "Key Equivalent"
   - For ⌘⇧P: Type "P", check ⌘ and ⇧
   - For ⌘→: Type "→", check ⌘
   - For ⌘←: Type "←", check ⌘

### Connecting Actions

1. Control-drag from menu item to "First Responder"
2. Select action from list:
   - togglePlaylist:
   - addToPlaylist:
   - nextTrack:
   - previousTrack:

## Menu Validation

The following menu items have dynamic states:

- **Show/Hide Playlist**: Title changes based on visibility
- **Next Track**: Disabled if no next track
- **Previous Track**: Disabled if no previous track
- **Display Mode items**: Checkmark on currently selected mode

Validation is handled in `ViewController.validateUserInterfaceItem(_:)`

## Alternative Access Methods

Users can access playlist features via:

1. **Menu Bar** (described above)
2. **Keyboard Shortcuts** (⌘⇧P, ⌘→, ⌘←)
3. **Menu Bar Icon** (when in Menu Bar mode)
4. **Drag & Drop** (files onto main window or playlist)
5. **Playlist Window Buttons** (Add Files, Shuffle, Clear)

## Accessibility

All menu items support:
- VoiceOver announcements
- Keyboard navigation
- State indication (enabled/disabled, checked/unchecked)
- Tooltips (where applicable)
