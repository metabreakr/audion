# Audion (Playlist Edition)

A modernized build of Audion, the classic macOS MP3 player, extended with a full
playlist system and updated to run natively on current versions of macOS.

This is a personal fork of Panic's open-source Audion viewer. All original code and
the Audion name are the work of Panic Inc.; see **Credits** below.

## Added in this fork

- Queue multiple tracks with auto-advance and Next/Previous navigation
- Shuffle / unshuffle
- Save and load playlists (`.audionplaylist` JSON and standard `.m3u`; `.pls` import)
- Load/remove/reorder tracks via drag & drop, with undo/redo
- Automatic metadata extraction (title, artist, album, duration) and album art
- A per-track info panel
- Two playlist display modes — **Floating Window** and **Menu Bar** — switchable
  from the Playlist menu
- Persistent playlist that is restored between launches

## Requirements

- macOS 15 (Sequoia) or later
- Universal binary — runs natively on Apple Silicon and Intel

## Installing Faces

This version of Audion only supports faces that have been converted to a modern
format. You can download them from:

https://download-cdn.panic.com/audion-viewer/

Once downloaded, unzip them, launch Audion, and choose `Open Faces Folder` from the
`File` menu. A new empty Finder window will open — select all the face folders and
drag them into it.

## Building

Open `Audion.xcodeproj` in Xcode and build the `Audion` scheme. The `FaceKit`
framework (© Panic Inc.) is included in this repository under `FaceKit/`.

## Credits

Based on Panic's original Audion, released as open source at:

https://gitlab.com/panicinc/audion

Audion and FaceKit are © Panic Inc. The playlist functionality and macOS
updates in this fork were contributed by Jonathan Ruzek.

## License

Licensed under the **GNU General Public License v3**, the same license as the
original Audion, in order to prevent it from being used on the App Store. See
[LICENSE](LICENSE).

If you wish to license the original Audion for commercial purposes, get in touch
with Panic.
