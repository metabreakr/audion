//
//  PlaylistModels.swift
//  Audion
//
//  Playlist data models for track and playlist management
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

// MARK: - Track Model

struct PlaylistTrack: Codable, Identifiable, Equatable {
    let id: UUID
    let url: URL
    var title: String?
    var artist: String?
    var album: String?
    var duration: TimeInterval?
    let addedDate: Date

    init(url: URL, title: String? = nil, artist: String? = nil, album: String? = nil, duration: TimeInterval? = nil) {
        self.id = UUID()
        self.url = url
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.addedDate = Date()
    }

    var displayTitle: String {
        if let title = title, !title.isEmpty {
            return title
        }
        return url.lastPathComponent
    }

    var displayArtist: String {
        artist ?? "Unknown Artist"
    }

    var displayAlbum: String {
        album ?? "Unknown Album"
    }

    var isStream: Bool {
        url.scheme == "http" || url.scheme == "https"
    }

    static func == (lhs: PlaylistTrack, rhs: PlaylistTrack) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Playlist Model

struct Playlist: Codable {
    var name: String
    var tracks: [PlaylistTrack]
    var createdDate: Date
    var modifiedDate: Date

    init(name: String = "Untitled Playlist", tracks: [PlaylistTrack] = []) {
        self.name = name
        self.tracks = tracks
        self.createdDate = Date()
        self.modifiedDate = Date()
    }

    mutating func addTrack(_ track: PlaylistTrack) {
        tracks.append(track)
        modifiedDate = Date()
    }

    mutating func removeTrack(at index: Int) {
        guard index >= 0 && index < tracks.count else { return }
        tracks.remove(at: index)
        modifiedDate = Date()
    }

    mutating func insertTrack(_ track: PlaylistTrack, at index: Int) {
        guard index >= 0 && index <= tracks.count else { return }
        tracks.insert(track, at: index)
        modifiedDate = Date()
    }

    mutating func moveTrack(from sourceIndex: Int, to destinationIndex: Int) {
        guard sourceIndex >= 0 && sourceIndex < tracks.count,
              destinationIndex >= 0 && destinationIndex < tracks.count,
              sourceIndex != destinationIndex else { return }

        let track = tracks.remove(at: sourceIndex)
        tracks.insert(track, at: destinationIndex)
        modifiedDate = Date()
    }

    mutating func clear() {
        tracks.removeAll()
        modifiedDate = Date()
    }
}

// MARK: - Playlist UI Mode

enum PlaylistUIMode: String, Codable, CaseIterable {
    case floatingWindow = "Floating Window"
    case menuBar = "Menu Bar"

    var description: String {
        return rawValue
    }
}
