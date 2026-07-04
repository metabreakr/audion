# Audion Playlist Feature

## 🎵 Complete Playlist System for Audion

A comprehensive playlist feature has been implemented for the Audion audio player with all requested functionality.

---

## 📋 Quick Start

### For Developers

1. **Read First**: [INTEGRATION_CHECKLIST.md](INTEGRATION_CHECKLIST.md)
2. **Then**: [PLAYLIST_IMPLEMENTATION_GUIDE.md](PLAYLIST_IMPLEMENTATION_GUIDE.md)
3. **Reference**: [MENU_STRUCTURE.md](MENU_STRUCTURE.md)

**Estimated Integration Time**: 30-45 minutes

### For Users (After Integration)

Press **⌘⇧P** to open the playlist!

---

## ✨ Features

### Core Playlist Functionality
- ✅ Queue multiple audio tracks
- ✅ Auto-advance to next track
- ✅ Next/Previous navigation (⌘→ / ⌘←)
- ✅ Drag & drop to add and reorder
- ✅ Shuffle/Unshuffle
- ✅ Remove tracks
- ✅ Clear all
- ✅ Persistent across app restarts

### File Operations
- ✅ Save playlists (.audionplaylist, .m3u)
- ✅ Load playlists from files
- ✅ Auto-extract metadata (title, artist, album, duration)
- ✅ Support for streams and local files

### UI Display Modes
1. **Floating Window** - Independent always-on-top window
2. **Menu Bar** - Popover from menu bar icon
3. **Slide-in Panel** - Attaches to left or right of main window

### Keyboard Shortcuts
- **⌘⇧P** - Toggle playlist visibility
- **⌘→** - Next track
- **⌘←** - Previous track

---

## 📁 Files Overview

### New Swift Files (6)
| File | Lines | Purpose |
|------|-------|---------|
| PlaylistModels.swift | 177 | Data models (Track, Playlist, enums) |
| PlaylistManager.swift | 305 | Queue & persistence manager |
| PlaylistViewController.swift | 298 | Table view & UI controller |
| PlaylistWindowManager.swift | 245 | UI mode management |
| PlaylistPreferencesViewController.swift | 72 | Settings panel |

### Interface Files (1)
- **PlaylistView.xib** - Table view layout with controls

### Documentation (4)
1. **PLAYLIST_README.md** (this file) - Overview
2. **INTEGRATION_CHECKLIST.md** - Step-by-step integration
3. **PLAYLIST_IMPLEMENTATION_GUIDE.md** - Detailed technical guide
4. **MENU_STRUCTURE.md** - Complete menu layout
5. **PLAYLIST_FEATURE_SUMMARY.md** - Feature comparison & stats

### Modified Files (2)
- **Player.swift** (+38 lines) - Playlist integration & auto-advance
- **ViewController.swift** (+50 lines) - Playlist actions & setup

---

## 🛠 Technology Stack

- **Language**: Swift 5.0+
- **Frameworks**: AppKit, Combine, AVFoundation
- **UI**: NSTableView, NSWindow, NSPanel, NSPopover, NSStatusItem
- **Persistence**: JSON (UserDefaults + file-based)
- **Design Pattern**: MVC with Singleton managers

---

## 📖 Documentation Structure

```
PLAYLIST_README.md (you are here)
├── Quick overview and features
├── File listing
└── Links to detailed docs

INTEGRATION_CHECKLIST.md
├── Step-by-step checklist
├── Xcode integration tasks
└── Testing verification

PLAYLIST_IMPLEMENTATION_GUIDE.md
├── Detailed technical documentation
├── Architecture explanation
├── Xcode project setup
├── Storyboard configuration
├── Info.plist updates
└── Troubleshooting guide

MENU_STRUCTURE.md
├── Complete menu hierarchy
├── Keyboard shortcuts table
├── Action mappings
└── Interface Builder instructions

PLAYLIST_FEATURE_SUMMARY.md
├── Feature comparison (before/after)
├── Code statistics
├── User experience flow
└── Quality assurance notes
```

---

## 🚀 Integration Steps (TL;DR)

1. Add 6 Swift files + 1 XIB to Xcode project
2. Create "Playlist" menu in Main.storyboard
3. Add PlaylistViewController scene (Storyboard ID: "PlaylistViewController")
4. Add Playlist preferences tab
5. Update Info.plist with document types
6. Build & test

**See [INTEGRATION_CHECKLIST.md](INTEGRATION_CHECKLIST.md) for detailed steps.**

---

## 🎯 UI Modes Explained

### Floating Window
Best for: Power users, multi-monitor setups
- Independent window
- Always on top
- Resizable and movable
- Persists position

### Menu Bar
Best for: Minimal UI, focused work
- Hidden until needed
- Icon in menu bar
- Click to show popover
- Auto-hides when inactive

### Slide-in Panel
Best for: Single screen, side-by-side viewing
- Attaches to main window (left or right)
- Moves with main window
- Compact and space-efficient
- Always visible when enabled

**Users can switch modes in Preferences → Playlist**

---

## 📊 Statistics

- **Total Implementation**: ~1,100 lines of Swift
- **New Files**: 6 Swift + 1 XIB + 4 docs
- **Modified Files**: 2 Swift files
- **Features Added**: 15+ major features
- **UI Modes**: 3 display options
- **File Formats**: 2 (JSON + M3U)
- **Keyboard Shortcuts**: 3 main shortcuts

---

## 🎨 User Interface

### Playlist Window
```
┌─────────────────────────────────────┐
│ Playlist                        ─ □ ✕│
├─────────────────────────────────────┤
│ Track         │ Artist  │ Album │ Time│
├─────────────────────────────────────┤
│ ▶ Song 1      │ Artist1 │ Alb1  │ 3:45│
│   Song 2      │ Artist2 │ Alb2  │ 4:12│
│   Song 3      │ Artist3 │ Alb3  │ 2:58│
│                                       │
├─────────────────────────────────────┤
│ [Add Files...] ☑Shuffle   [Clear All]│
└─────────────────────────────────────┘
```

### Preferences Panel
```
┌─────────────────────────────────────┐
│ Playlist Preferences                 │
├─────────────────────────────────────┤
│                                       │
│ Display Mode:  [Floating Window ▼]  │
│                                       │
│ Slide Direction: [Right ▼]          │
│ (Only for Slide-in Panel mode)      │
│                                       │
└─────────────────────────────────────┘
```

---

## 🧪 Testing

After integration, verify:

- [ ] ⌘⇧P opens playlist
- [ ] Can add files
- [ ] Double-click plays track
- [ ] Auto-advance works
- [ ] Next/Previous work
- [ ] Shuffle works
- [ ] Save/Load work
- [ ] All 3 UI modes work
- [ ] Playlist persists on restart

**Complete testing checklist in [INTEGRATION_CHECKLIST.md](INTEGRATION_CHECKLIST.md)**

---

## 🔧 Architecture

```
User Interface Layer
  ├── PlaylistViewController (Table UI)
  ├── PlaylistWindowManager (Mode handling)
  └── PlaylistPreferencesViewController (Settings)

Business Logic Layer
  ├── PlaylistManager (Queue & persistence)
  └── Player (Extended for playlists)

Data Layer
  ├── PlaylistModels (Track, Playlist)
  └── UserDefaults + JSON files
```

**Design Pattern**: MVC with Singleton managers
**Data Flow**: Reactive (Combine publishers)
**Thread Safety**: Main thread for UI, background for I/O

---

## 📝 Code Example

### Adding a Track to Playlist

```swift
// Simple API
PlaylistManager.shared.addURL(trackURL)

// With metadata extraction
PlaylistManager.shared.addURL(trackURL, autoExtractMetadata: true) { track in
    print("Added: \(track.displayTitle)")
}

// Bulk add
let urls = [url1, url2, url3]
let tracks = urls.map { PlaylistTrack(url: $0) }
PlaylistManager.shared.addTracks(tracks)
```

### Playing from Playlist

```swift
// Play specific track
player.playTrack(at: 3)

// Navigate
player.playNextTrack()
player.playPreviousTrack()

// Auto-advance happens automatically
// when track finishes playing
```

### Saving/Loading

```swift
// Save
try PlaylistManager.shared.savePlaylistToFile(at: url)

// Load
try PlaylistManager.shared.loadPlaylistFromFile(at: url)
```

---

## 🐛 Troubleshooting

### Common Issues

**Playlist won't show**
- Check Storyboard ID is "PlaylistViewController"
- Verify XIB outlets are connected

**Build errors**
- Ensure all files are added to Audion target
- Check deployment target is macOS 10.15+

**Menu items disabled**
- Verify actions are connected to First Responder
- Check validateUserInterfaceItem implementation

**See [PLAYLIST_IMPLEMENTATION_GUIDE.md](PLAYLIST_IMPLEMENTATION_GUIDE.md) for complete troubleshooting.**

---

## 🎓 Learning Resources

- **Apple Documentation**:
  - [NSTableView](https://developer.apple.com/documentation/appkit/nstableview)
  - [AVPlayer](https://developer.apple.com/documentation/avfoundation/avplayer)
  - [Combine](https://developer.apple.com/documentation/combine)

- **Audion Resources**:
  - Original README.md
  - Existing codebase (Player.swift, ViewController.swift)

---

## 📄 License

This playlist feature implementation follows the same license as Audion (GNU GPL v3).

See [LICENSE](LICENSE) for details.

---

## ✅ Status

**Implementation**: ✅ Complete
**Documentation**: ✅ Complete
**Testing**: ⏳ Ready for integration testing
**Production**: ⏳ Awaiting Xcode integration

---

## 🤝 Next Steps

1. Follow [INTEGRATION_CHECKLIST.md](INTEGRATION_CHECKLIST.md)
2. Add files to Xcode project
3. Create menu in Main.storyboard
4. Test all features
5. Enjoy your playlist feature! 🎉

---

**Questions?** Refer to the implementation guide or check the inline code comments.

**Ready to integrate?** Start with [INTEGRATION_CHECKLIST.md](INTEGRATION_CHECKLIST.md)!
