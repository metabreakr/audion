//
//  PlaylistViewController.swift
//  Audion
//
//  Manages the playlist table view and user interactions
//
//  Audion is © Panic Inc. — https://gitlab.com/panicinc/audion
//  Playlist additions contributed by Jonathan Ruzek, 2025–2026.
//
//  Audion is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Audion is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Audion.  If not, see <https://www.gnu.org/licenses/>.
//

import Cocoa
import Combine
import AVFoundation
import UniformTypeIdentifiers

class PlaylistViewController: NSViewController {

    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var clearButton: NSButton!
    @IBOutlet weak var shuffleButton: NSButton!
    @IBOutlet weak var addFilesButton: NSButton!
    @IBOutlet weak var infoButton: NSButton!
    @IBOutlet weak var positionSlider: NSSlider!
    @IBOutlet weak var previousButton: NSButton!
    @IBOutlet weak var playPauseButton: NSButton!
    @IBOutlet weak var nextButton: NSButton!

    private var cancellables = Set<AnyCancellable>()
    private let playlistManager = PlaylistManager.shared
    weak var player: Player?
    private var infoPopover: NSPopover?
    private var sliderUpdateTimer: Timer?
    private var albumArtCache: [URL: NSImage] = [:]

    // Undo/Redo stacks for removed tracks
    private var removedTracksStack: [(tracks: [PlaylistTrack], indices: [Int])] = []
    private var redoStack: [(tracks: [PlaylistTrack], indices: [Int])] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        setupTableView()
        setupBindings()
        setupPositionSlider()
        updateShuffleButton()
    }

    override var acceptsFirstResponder: Bool {
        return true
    }

    override func keyDown(with event: NSEvent) {
        // Handle Space bar for play/pause
        if event.keyCode == 49 { // Space bar
            NSApp.sendAction(#selector(ViewController.playPause(_:)), to: nil, from: self)
        }
        // Handle Delete and Backspace keys
        else if event.keyCode == 51 || event.keyCode == 117 { // Delete or Backspace
            removeSelectedTracks(self)
        } else {
            super.keyDown(with: event)
        }
    }

    private func setupPositionSlider() {
        positionSlider?.target = self
        positionSlider?.action = #selector(positionSliderChanged(_:))
        positionSlider?.isContinuous = true
        positionSlider?.minValue = 0
        positionSlider?.maxValue = 100
        positionSlider?.doubleValue = 0

        // Start timer to update slider position
        sliderUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updatePositionSlider()
        }
    }

    @objc private func positionSliderChanged(_ sender: NSSlider) {
        guard let player = player, let duration = player.duration, duration > 0 else { return }
        let position = duration * (sender.doubleValue / 100.0)
        player.seek(to: position)
    }

    private func updatePositionSlider() {
        guard let player = player, let duration = player.duration, duration > 0 else {
            positionSlider?.doubleValue = 0
            return
        }

        let currentTime = player.currentTime
        let percentage = (currentTime / duration) * 100.0
        positionSlider?.doubleValue = percentage
    }

    deinit {
        sliderUpdateTimer?.invalidate()
    }

    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.target = self
        tableView.doubleAction = #selector(tableViewDoubleClick(_:))
        tableView.registerForDraggedTypes([.fileURL, .string])
        tableView.setDraggingSourceOperationMask(.move, forLocal: true)
        tableView.setDraggingSourceOperationMask(.copy, forLocal: false)
    }

    private func setupBindings() {
        playlistManager.$playlist
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.tableView.reloadData()
            }
            .store(in: &cancellables)

        playlistManager.$currentTrackIndex
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.tableView.reloadData()
                self?.updateInfoPopoverIfOpen()
            }
            .store(in: &cancellables)

        playlistManager.$isShuffled
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateShuffleButton()
            }
            .store(in: &cancellables)
    }

    private func updateShuffleButton() {
        shuffleButton?.title = playlistManager.isShuffled ? "Unshuffle" : "Shuffle"
    }

    // MARK: - Actions

    @IBAction func addFiles(_ sender: Any) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = ["mp3", "m4a", "wav", "aiff", "flac", "ogg", "aac"].compactMap { UTType(filenameExtension: $0) }

        panel.begin { [weak self] response in
            guard response == .OK else { return }

            for url in panel.urls {
                self?.playlistManager.addURL(url)
            }
        }
    }

    @IBAction func clearPlaylist(_ sender: Any) {
        let alert = NSAlert()
        alert.messageText = "Clear Playlist?"
        alert.informativeText = "This will remove all tracks from the playlist."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Clear")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            playlistManager.clearPlaylist()
        }
    }

    @IBAction func toggleShuffle(_ sender: Any) {
        if playlistManager.isShuffled {
            playlistManager.unshuffle()
        } else {
            playlistManager.shuffle()
        }
    }

    @IBAction func playPause(_ sender: Any) {
        player?.togglePlayPause()
    }

    @IBAction func previousTrack(_ sender: Any) {
        player?.playPreviousTrack()
    }

    @IBAction func nextTrack(_ sender: Any) {
        player?.playNextTrack()
    }

    @IBAction func selectAllTracks(_ sender: Any) {
        NSLog("selectAllTracks called, track count: \(playlistManager.playlist.tracks.count)")
        let allRows = IndexSet(integersIn: 0..<playlistManager.playlist.tracks.count)
        tableView.selectRowIndexes(allRows, byExtendingSelection: false)
        NSLog("Selected rows: \(tableView.selectedRowIndexes)")
    }

    @IBAction func removeSelectedTracks(_ sender: Any) {
        let selectedRows = tableView.selectedRowIndexes
        guard !selectedRows.isEmpty else {
            NSLog("No tracks selected for removal")
            return
        }

        NSLog("Removing \(selectedRows.count) selected tracks")
        let rowsToRemove = Array(selectedRows).sorted(by: >)
        var removedTracks: [PlaylistTrack] = []
        var removedIndices: [Int] = []

        // Collect tracks to remove
        for row in rowsToRemove.reversed() {
            if row < playlistManager.playlist.tracks.count {
                removedTracks.insert(playlistManager.playlist.tracks[row], at: 0)
                removedIndices.insert(row, at: 0)
            }
        }

        // Remove tracks
        for row in rowsToRemove {
            playlistManager.removeTrack(at: row)
        }

        // Save to undo stack
        if !removedTracks.isEmpty {
            removedTracksStack.append((tracks: removedTracks, indices: removedIndices))
            redoStack.removeAll() // Clear redo stack when new action is performed
            NSLog("Saved to undo stack, stack size now: \(removedTracksStack.count)")
        }
    }

    @IBAction func undoRemoveTrack(_ sender: Any) {
        NSLog("undoRemoveTrack called, stack size: \(removedTracksStack.count)")
        guard let last = removedTracksStack.popLast() else {
            NSLog("No items in undo stack")
            return
        }

        NSLog("Restoring \(last.tracks.count) tracks at indices: \(last.indices)")
        // Re-insert tracks at their original positions
        for (index, track) in zip(last.indices, last.tracks) {
            playlistManager.insertTrack(track, at: index)
        }

        // Save to redo stack
        redoStack.append(last)
        NSLog("Undo complete, redo stack size: \(redoStack.count)")
    }

    @IBAction func redoRemoveTrack(_ sender: Any) {
        NSLog("redoRemoveTrack called, stack size: \(redoStack.count)")
        guard let last = redoStack.popLast() else {
            NSLog("No items in redo stack")
            return
        }

        NSLog("Re-removing \(last.tracks.count) tracks")
        // Remove tracks again
        for index in last.indices.sorted(by: >) {
            playlistManager.removeTrack(at: index)
        }

        // Save to undo stack
        removedTracksStack.append(last)
        NSLog("Redo complete, undo stack size: \(removedTracksStack.count)")
    }

    @objc private func tableViewDoubleClick(_ sender: Any) {
        let clickedRow = tableView.clickedRow
        guard clickedRow >= 0 && clickedRow < playlistManager.playlist.tracks.count else { return }

        player?.playTrack(at: clickedRow)
    }

    func selectTrack(at index: Int) {
        guard index >= 0 && index < playlistManager.playlist.tracks.count else { return }
        tableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
        tableView.scrollRowToVisible(index)
    }

    // MARK: - Menu Actions

    @IBAction func savePlaylist(_ sender: Any) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = ["audionplaylist", "m3u"].compactMap { UTType(filenameExtension: $0) }
        panel.nameFieldStringValue = playlistManager.playlist.name

        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }

            do {
                try self?.playlistManager.savePlaylistToFile(at: url)
            } catch {
                let alert = NSAlert()
                alert.messageText = "Save Failed"
                alert.informativeText = "Could not save playlist: \(error.localizedDescription)"
                alert.alertStyle = .critical
                alert.runModal()
            }
        }
    }

    @IBAction func loadPlaylist(_ sender: Any) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = ["audionplaylist", "m3u", "m3u8", "pls"].compactMap { UTType(filenameExtension: $0) }

        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }

            do {
                try self?.playlistManager.loadPlaylistFromFile(at: url)
            } catch {
                let alert = NSAlert()
                alert.messageText = "Load Failed"
                alert.informativeText = "Could not load playlist: \(error.localizedDescription)"
                alert.alertStyle = .critical
                alert.runModal()
            }
        }
    }
}

// MARK: - NSTableViewDataSource

extension PlaylistViewController: NSTableViewDataSource {

    func numberOfRows(in tableView: NSTableView) -> Int {
        return playlistManager.playlist.tracks.count
    }

    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        guard row >= 0 && row < playlistManager.playlist.tracks.count else { return nil }

        let track = playlistManager.playlist.tracks[row]

        switch tableColumn?.identifier.rawValue {
        case "ArtColumn":
            return albumArtThumbnail(for: track, row: row)
        case "TrackColumn":
            return track.displayTitle
        case "ArtistColumn":
            return track.artist
        case "AlbumColumn":
            return track.album
        case "DurationColumn":
            if let duration = track.duration {
                return formatDuration(duration)
            }
            return track.isStream ? "Stream" : ""
        default:
            return nil
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private static let placeholderArt: NSImage =
        NSImage(systemSymbolName: "music.note", accessibilityDescription: "Music") ?? NSImage()

    /// Returns a cached thumbnail immediately, or a placeholder while the artwork
    /// loads asynchronously off the main thread. When loading finishes, the row is
    /// reloaded so the real thumbnail appears without ever blocking the UI.
    private func albumArtThumbnail(for track: PlaylistTrack, row: Int) -> NSImage {
        if let cached = albumArtCache[track.url] {
            return cached
        }

        // Streams never carry embedded artwork; cache the placeholder and move on.
        if track.isStream {
            albumArtCache[track.url] = Self.placeholderArt
            return Self.placeholderArt
        }

        let url = track.url
        let asset = AVURLAsset(url: url)
        Task { [weak self] in
            let thumbnail = await Self.loadArtworkThumbnail(from: asset, size: NSSize(width: 32, height: 32))
            await MainActor.run {
                guard let self = self else { return }
                self.albumArtCache[url] = thumbnail ?? Self.placeholderArt
                self.reloadRow(for: url, hint: row)
            }
        }

        return Self.placeholderArt
    }

    /// Reloads the table row that displays the track at `url`, using `hint` as a
    /// fast path and falling back to a search in case the playlist reordered.
    private func reloadRow(for url: URL, hint: Int) {
        let tracks = playlistManager.playlist.tracks
        let row: Int? = (hint < tracks.count && tracks[hint].url == url)
            ? hint
            : tracks.firstIndex { $0.url == url }

        guard let row = row else { return }
        let columns = IndexSet(integersIn: 0..<tableView.numberOfColumns)
        tableView.reloadData(forRowIndexes: IndexSet(integer: row), columnIndexes: columns)
    }

    private static func loadArtworkThumbnail(from asset: AVURLAsset, size: NSSize) async -> NSImage? {
        guard let formats = try? await asset.load(.availableMetadataFormats) else { return nil }
        for format in formats {
            guard let items = try? await asset.loadMetadata(for: format) else { continue }
            for item in items where item.commonKey?.rawValue == "artwork" {
                if let data = try? await item.load(.dataValue), let image = NSImage(data: data) {
                    return resizeImage(image, to: size)
                }
            }
        }
        return nil
    }

    private static func resizeImage(_ image: NSImage, to size: NSSize) -> NSImage {
        let newImage = NSImage(size: size)
        newImage.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: size),
                   from: NSRect(origin: .zero, size: image.size),
                   operation: .copy,
                   fraction: 1.0)
        newImage.unlockFocus()
        return newImage
    }

    // MARK: - Info Popover

    @IBAction func showInfoDrawer(_ sender: Any?) {
        // Get currently selected or playing track
        let trackIndex = tableView.selectedRow >= 0 ? tableView.selectedRow : playlistManager.currentTrackIndex
        guard let index = trackIndex,
              index >= 0 && index < playlistManager.playlist.tracks.count else {
            let alert = NSAlert()
            alert.messageText = "No Track Selected"
            alert.informativeText = "Please select a track to view its information."
            alert.alertStyle = .informational
            alert.runModal()
            return
        }

        let track = playlistManager.playlist.tracks[index]

        // Toggle popover if already showing
        if let popover = infoPopover, popover.isShown {
            popover.close()
            infoPopover = nil
            return
        }

        // Create popover
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 300, height: 500)
        popover.behavior = .transient
        popover.animates = true

        // Create info view controller
        let infoViewController = TrackInfoViewController()
        infoViewController.track = track
        popover.contentViewController = infoViewController

        // Show popover relative to info button
        if let button = sender as? NSButton {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .maxY)
        } else if let button = infoButton {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .maxY)
        }

        infoPopover = popover
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func updateInfoPopoverIfOpen() {
        guard let popover = infoPopover, popover.isShown,
              let infoVC = popover.contentViewController as? TrackInfoViewController else { return }

        guard let index = playlistManager.currentTrackIndex,
              index >= 0 && index < playlistManager.playlist.tracks.count else { return }

        let track = playlistManager.playlist.tracks[index]
        infoVC.track = track
    }

    // MARK: - Drag and Drop

    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        let item = NSPasteboardItem()
        item.setString(String(row), forType: .string)
        return item
    }

    func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
        if dropOperation == .above {
            return .move
        }
        return []
    }

    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        let pasteboard = info.draggingPasteboard

        if let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL] {
            for url in urls {
                playlistManager.addURL(url)
            }
            return true
        }

        if let rowData = pasteboard.pasteboardItems?.first?.string(forType: .string),
           let sourceRow = Int(rowData) {
            playlistManager.moveTrack(from: sourceRow, to: row > sourceRow ? row - 1 : row)
            return true
        }

        return false
    }
}

// MARK: - NSTableViewDelegate

extension PlaylistViewController: NSTableViewDelegate {

    func tableView(_ tableView: NSTableView, willDisplayCell cell: Any, for tableColumn: NSTableColumn?, row: Int) {
        guard row >= 0 && row < playlistManager.playlist.tracks.count else { return }

        let isCurrentTrack = playlistManager.currentTrackIndex == row

        if let textCell = cell as? NSTextFieldCell {
            // Set text color for dark mode support
            textCell.textColor = .labelColor

            // Make current track bold
            if isCurrentTrack {
                textCell.font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
            } else {
                textCell.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
            }
        }
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        return true
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        let rowView = NSTableRowView()

        if playlistManager.currentTrackIndex == row {
            rowView.backgroundColor = NSColor.selectedContentBackgroundColor.withAlphaComponent(0.3)
        }

        return rowView
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 32
    }
}

// MARK: - Menu Validation
extension PlaylistViewController: NSMenuItemValidation {
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(undoRemoveTrack(_:)):
            return !removedTracksStack.isEmpty
        case #selector(redoRemoveTrack(_:)):
            return !redoStack.isEmpty
        case #selector(removeSelectedTracks(_:)):
            return !tableView.selectedRowIndexes.isEmpty
        case #selector(selectAllTracks(_:)):
            return !playlistManager.playlist.tracks.isEmpty
        default:
            return true
        }
    }

    func canUndoRemove() -> Bool {
        return !removedTracksStack.isEmpty
    }

    func canRedoRemove() -> Bool {
        return !redoStack.isEmpty
    }

    func hasSelectedTracks() -> Bool {
        return !tableView.selectedRowIndexes.isEmpty
    }

    func hasAnyTracks() -> Bool {
        return !playlistManager.playlist.tracks.isEmpty
    }
}
