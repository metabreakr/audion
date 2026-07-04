//
//  PlaylistManager.swift
//  Audion
//
//  Manages playlist state, queue operations, and persistence
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

import Foundation
import AVFoundation

class PlaylistManager: ObservableObject {
    static let shared = PlaylistManager()

    @Published private(set) var playlist: Playlist
    @Published private(set) var currentTrackIndex: Int?
    @Published private(set) var isShuffled: Bool = false

    private var originalTrackOrder: [PlaylistTrack] = []
    private var securityScopedBookmarks: [URL: Data] = [:]

    private let playlistFileURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let audionFolder = appSupport.appendingPathComponent("Audion", isDirectory: true)
        try? FileManager.default.createDirectory(at: audionFolder, withIntermediateDirectories: true)
        return audionFolder.appendingPathComponent("current_playlist.json")
    }()

    private let bookmarksFileURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let audionFolder = appSupport.appendingPathComponent("Audion", isDirectory: true)
        try? FileManager.default.createDirectory(at: audionFolder, withIntermediateDirectories: true)
        return audionFolder.appendingPathComponent("bookmarks.json")
    }()

    private init() {
        self.playlist = Playlist()
        loadBookmarks()
        loadCurrentPlaylist()
        // Skip restoring security-scoped access - causes permission prompts
        // restoreSecurityScopedAccess()
    }

    // MARK: - Queue Management

    var currentTrack: PlaylistTrack? {
        guard let index = currentTrackIndex, index >= 0 && index < playlist.tracks.count else {
            return nil
        }
        return playlist.tracks[index]
    }

    var hasNextTrack: Bool {
        guard let index = currentTrackIndex else { return !playlist.tracks.isEmpty }
        return index < playlist.tracks.count - 1
    }

    var hasPreviousTrack: Bool {
        guard let index = currentTrackIndex else { return false }
        return index > 0
    }

    func addTrack(_ track: PlaylistTrack) {
        playlist.addTrack(track)
        saveCurrentPlaylist()
    }

    func addTracks(_ tracks: [PlaylistTrack]) {
        for track in tracks {
            playlist.addTrack(track)
        }
        saveCurrentPlaylist()
    }

    func addURL(_ url: URL, autoExtractMetadata: Bool = true, completion: ((PlaylistTrack) -> Void)? = nil) {
        // Skip bookmark creation - it causes permission prompts on removable volumes
        // when the app isn't properly sandboxed or code-signed
        // if url.isFileURL {
        //     let parentDirectory = url.deletingLastPathComponent()
        //     createBookmark(for: parentDirectory)
        // }

        if autoExtractMetadata && !url.isFileURL {
            let track = PlaylistTrack(url: url)
            addTrack(track)
            completion?(track)
        } else if autoExtractMetadata {
            extractMetadata(from: url) { [weak self] track in
                self?.addTrack(track)
                completion?(track)
            }
        } else {
            let track = PlaylistTrack(url: url)
            addTrack(track)
            completion?(track)
        }
    }

    func removeTrack(at index: Int) {
        if let currentIndex = currentTrackIndex {
            if index == currentIndex {
                currentTrackIndex = nil
            } else if index < currentIndex {
                currentTrackIndex = currentIndex - 1
            }
        }
        playlist.removeTrack(at: index)
        saveCurrentPlaylist()
    }

    func insertTrack(_ track: PlaylistTrack, at index: Int) {
        if let currentIndex = currentTrackIndex {
            if index <= currentIndex {
                currentTrackIndex = currentIndex + 1
            }
        }
        playlist.insertTrack(track, at: index)
        saveCurrentPlaylist()
    }

    func moveTrack(from sourceIndex: Int, to destinationIndex: Int) {
        if let currentIndex = currentTrackIndex {
            if sourceIndex == currentIndex {
                currentTrackIndex = destinationIndex
            } else if sourceIndex < currentIndex && destinationIndex >= currentIndex {
                currentTrackIndex = currentIndex - 1
            } else if sourceIndex > currentIndex && destinationIndex <= currentIndex {
                currentTrackIndex = currentIndex + 1
            }
        }
        playlist.moveTrack(from: sourceIndex, to: destinationIndex)
        saveCurrentPlaylist()
    }

    func clearPlaylist() {
        playlist.clear()
        currentTrackIndex = nil
        isShuffled = false
        originalTrackOrder.removeAll()
        saveCurrentPlaylist()
    }

    func setCurrentTrack(at index: Int?) {
        currentTrackIndex = index
    }

    func nextTrack() -> PlaylistTrack? {
        guard hasNextTrack else { return nil }

        if let index = currentTrackIndex {
            currentTrackIndex = index + 1
        } else if !playlist.tracks.isEmpty {
            currentTrackIndex = 0
        }

        return currentTrack
    }

    func previousTrack() -> PlaylistTrack? {
        guard hasPreviousTrack else { return nil }

        if let index = currentTrackIndex {
            currentTrackIndex = index - 1
        }

        return currentTrack
    }

    func shuffle() {
        guard !playlist.tracks.isEmpty else { return }

        if !isShuffled {
            originalTrackOrder = playlist.tracks
            let currentTrack = self.currentTrack

            var shuffledTracks = playlist.tracks
            shuffledTracks.shuffle()

            if let current = currentTrack, let newIndex = shuffledTracks.firstIndex(of: current) {
                shuffledTracks.swapAt(0, newIndex)
                currentTrackIndex = 0
            }

            playlist.tracks = shuffledTracks
            isShuffled = true
        }
        saveCurrentPlaylist()
    }

    func unshuffle() {
        guard isShuffled else { return }

        let currentTrack = self.currentTrack
        playlist.tracks = originalTrackOrder

        if let current = currentTrack, let originalIndex = playlist.tracks.firstIndex(of: current) {
            currentTrackIndex = originalIndex
        }

        isShuffled = false
        originalTrackOrder.removeAll()
        saveCurrentPlaylist()
    }

    // MARK: - Metadata Extraction

    private func extractMetadata(from url: URL, completion: @escaping (PlaylistTrack) -> Void) {
        let asset = AVURLAsset(url: url)

        Task {
            var title: String?
            var artist: String?
            var album: String?
            var duration: TimeInterval?

            if let metadata = try? await asset.load(.commonMetadata) {
                for item in metadata {
                    guard let commonKey = item.commonKey else { continue }
                    let value = try? await item.load(.stringValue)
                    switch commonKey {
                    case .commonKeyTitle:
                        title = value
                    case .commonKeyArtist:
                        artist = value
                    case .commonKeyAlbumName:
                        album = value
                    default:
                        break
                    }
                }
            }

            if let assetDuration = try? await asset.load(.duration),
               assetDuration.isValid, !assetDuration.isIndefinite {
                duration = assetDuration.seconds
            }

            let track = PlaylistTrack(url: url, title: title, artist: artist, album: album, duration: duration)

            await MainActor.run {
                completion(track)
            }
        }
    }

    // MARK: - Persistence

    private func saveCurrentPlaylist() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        guard let data = try? encoder.encode(playlist) else {
            print("Failed to encode playlist")
            return
        }

        do {
            try data.write(to: playlistFileURL)
        } catch {
            print("Failed to save playlist: \(error)")
        }
    }

    private func loadCurrentPlaylist() {
        guard FileManager.default.fileExists(atPath: playlistFileURL.path) else { return }

        do {
            let data = try Data(contentsOf: playlistFileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            playlist = try decoder.decode(Playlist.self, from: data)
        } catch {
            print("Failed to load playlist: \(error)")
        }
    }

    // MARK: - File I/O

    func savePlaylistToFile(at url: URL) throws {
        if url.pathExtension == "m3u" || url.pathExtension == "m3u8" {
            try saveAsM3U(to: url)
        } else {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

            let data = try encoder.encode(playlist)
            try data.write(to: url)
        }
    }

    func loadPlaylistFromFile(at url: URL) throws {
        // For HTTP/HTTPS URLs, download the content first
        let effectiveURL: URL
        let shouldDeleteTemp: Bool

        if url.scheme == "http" || url.scheme == "https" {
            let data = try Data(contentsOf: url)
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("temp_playlist.\(url.pathExtension)")
            try data.write(to: tempURL)
            effectiveURL = tempURL
            shouldDeleteTemp = true
        } else {
            effectiveURL = url
            shouldDeleteTemp = false
        }

        defer {
            if shouldDeleteTemp {
                try? FileManager.default.removeItem(at: effectiveURL)
            }
        }

        let ext = effectiveURL.pathExtension.lowercased()

        if ext == "m3u" || ext == "m3u8" {
            try loadFromM3U(from: effectiveURL)
        } else if ext == "pls" {
            try loadFromPLS(from: effectiveURL)
        } else {
            let data = try Data(contentsOf: effectiveURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            let loadedPlaylist = try decoder.decode(Playlist.self, from: data)
            playlist = loadedPlaylist
            currentTrackIndex = nil
            saveCurrentPlaylist()
        }
    }

    private func saveAsM3U(to url: URL) throws {
        var m3uContent = "#EXTM3U\n"

        for track in playlist.tracks {
            let duration = track.duration.map { Int($0) } ?? -1
            let title = track.displayTitle
            m3uContent += "#EXTINF:\(duration),\(title)\n"
            m3uContent += track.url.path + "\n"
        }

        try m3uContent.write(to: url, atomically: true, encoding: .utf8)
    }

    private func loadFromM3U(from url: URL) throws {
        let content = try String(contentsOf: url, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines)

        // Relative entries in an M3U are resolved against the playlist's own folder.
        let baseDirectory = url.deletingLastPathComponent()

        var tracks: [PlaylistTrack] = []
        var currentTitle: String?

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("#EXTINF:") {
                let components = trimmed.replacingOccurrences(of: "#EXTINF:", with: "").components(separatedBy: ",")
                if components.count > 1 {
                    currentTitle = components[1...].joined(separator: ",")
                }
            } else if !trimmed.isEmpty && !trimmed.hasPrefix("#") {
                let trackURL: URL
                if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
                    trackURL = URL(string: trimmed) ?? URL(fileURLWithPath: trimmed)
                } else if trimmed.hasPrefix("/") {
                    trackURL = URL(fileURLWithPath: trimmed)
                } else {
                    trackURL = URL(fileURLWithPath: trimmed, relativeTo: baseDirectory)
                }

                let track = PlaylistTrack(url: trackURL, title: currentTitle)
                tracks.append(track)
                currentTitle = nil
            }
        }

        playlist.tracks = tracks
        playlist.modifiedDate = Date()
        currentTrackIndex = nil
        saveCurrentPlaylist()
    }

    private func loadFromPLS(from url: URL) throws {
        let content = try String(contentsOf: url, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines)

        var tracks: [PlaylistTrack] = []
        var entries: [Int: (file: String, title: String?)] = [:]

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Parse File entries (File1=http://...)
            if trimmed.lowercased().hasPrefix("file") {
                let components = trimmed.components(separatedBy: "=")
                if components.count >= 2 {
                    // Extract the entry number (File1, File2, etc.)
                    let key = components[0].lowercased().replacingOccurrences(of: "file", with: "")
                    if let entryNum = Int(key) {
                        let fileURL = components[1...].joined(separator: "=")
                        if var entry = entries[entryNum] {
                            entry.file = fileURL
                            entries[entryNum] = entry
                        } else {
                            entries[entryNum] = (file: fileURL, title: nil)
                        }
                    }
                }
            }
            // Parse Title entries (Title1=...)
            else if trimmed.lowercased().hasPrefix("title") {
                let components = trimmed.components(separatedBy: "=")
                if components.count >= 2 {
                    let key = components[0].lowercased().replacingOccurrences(of: "title", with: "")
                    if let entryNum = Int(key) {
                        let title = components[1...].joined(separator: "=")
                        if var entry = entries[entryNum] {
                            entry.title = title
                            entries[entryNum] = entry
                        } else {
                            entries[entryNum] = (file: "", title: title)
                        }
                    }
                }
            }
        }

        // Convert entries to tracks
        for (_, entry) in entries.sorted(by: { $0.key < $1.key }) {
            guard !entry.file.isEmpty else { continue }

            let trackURL: URL
            if entry.file.hasPrefix("http://") || entry.file.hasPrefix("https://") {
                trackURL = URL(string: entry.file) ?? URL(fileURLWithPath: entry.file)
            } else {
                trackURL = URL(fileURLWithPath: entry.file)
            }

            let track = PlaylistTrack(url: trackURL, title: entry.title)
            tracks.append(track)
        }

        playlist.tracks = tracks
        playlist.modifiedDate = Date()
        currentTrackIndex = nil
        saveCurrentPlaylist()
    }

    // MARK: - Security-Scoped Bookmarks

    private func createBookmark(for url: URL) {
        // Skip if we already have a bookmark for this URL
        if securityScopedBookmarks[url] != nil {
            return
        }

        do {
            // Create security-scoped bookmark for persistent access
            let bookmarkData = try url.bookmarkData(
                options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            securityScopedBookmarks[url] = bookmarkData
            saveBookmarks()
            NSLog("Created security-scoped bookmark for: \(url.path)")
        } catch {
            NSLog("Failed to create bookmark for \(url.path): \(error)")
        }
    }

    private func restoreSecurityScopedAccess() {
        NSLog("Restoring security-scoped access for \(securityScopedBookmarks.count) bookmarks")
        for (url, bookmarkData) in securityScopedBookmarks {
            do {
                var isStale = false
                // Resolve security-scoped bookmark
                let resolvedURL = try URL(
                    resolvingBookmarkData: bookmarkData,
                    options: .withSecurityScope,
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )

                if isStale {
                    NSLog("Bookmark is stale for: \(url.path), recreating...")
                    // Try to recreate bookmark if stale
                    if FileManager.default.fileExists(atPath: resolvedURL.path) {
                        // Remove old bookmark and create new one
                        securityScopedBookmarks.removeValue(forKey: url)
                        createBookmark(for: resolvedURL)
                    }
                } else {
                    // Start accessing the security-scoped resource
                    if resolvedURL.startAccessingSecurityScopedResource() {
                        NSLog("✅ Successfully restored security-scoped access to: \(resolvedURL.path)")
                        // Note: We keep the access active for the lifetime of the app
                        // In a production app, you'd want to call stopAccessingSecurityScopedResource()
                        // when done, but for a media player, continuous access is needed
                    } else {
                        NSLog("❌ Failed to start accessing security-scoped resource: \(resolvedURL.path)")
                    }
                }
            } catch {
                NSLog("Failed to resolve bookmark for \(url.path): \(error)")
            }
        }
    }

    private func saveBookmarks() {
        let encoder = JSONEncoder()

        // Convert bookmarks dictionary to a serializable format
        let bookmarksDict = securityScopedBookmarks.mapValues { $0.base64EncodedString() }
        let urlStringsDict = Dictionary(uniqueKeysWithValues: bookmarksDict.map { (key, value) in
            (key.path, value)
        })

        guard let data = try? encoder.encode(urlStringsDict) else {
            NSLog("Failed to encode bookmarks")
            return
        }

        do {
            try data.write(to: bookmarksFileURL)
            NSLog("Saved \(securityScopedBookmarks.count) bookmarks")
        } catch {
            NSLog("Failed to save bookmarks: \(error)")
        }
    }

    private func loadBookmarks() {
        guard FileManager.default.fileExists(atPath: bookmarksFileURL.path) else {
            NSLog("No bookmarks file found")
            return
        }

        do {
            let data = try Data(contentsOf: bookmarksFileURL)
            let decoder = JSONDecoder()
            let urlStringsDict = try decoder.decode([String: String].self, from: data)

            // Convert back to URL and Data format
            securityScopedBookmarks = Dictionary(uniqueKeysWithValues: urlStringsDict.compactMap { (urlString, base64String) in
                guard let url = URL(string: "file://\(urlString)"),
                      let bookmarkData = Data(base64Encoded: base64String) else {
                    return nil
                }
                return (url, bookmarkData)
            })

            NSLog("Loaded \(securityScopedBookmarks.count) bookmarks")
        } catch {
            NSLog("Failed to load bookmarks: \(error)")
        }
    }
}
