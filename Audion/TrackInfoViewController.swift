//
//  TrackInfoViewController.swift
//  Audion
//
//  Displays track information in a popover
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
import AVFoundation

class TrackInfoViewController: NSViewController {

    private var albumArtImageView: NSImageView!
    private var infoTextView: NSTextView!
    private var scrollView: NSScrollView!

    var track: PlaylistTrack? {
        didSet {
            if isViewLoaded {
                updateContent()
            }
        }
    }

    override func loadView() {
        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 500))
        self.view = contentView

        // Album art at top
        let artSize: CGFloat = 260
        albumArtImageView = NSImageView(frame: NSRect(x: 20, y: 500 - artSize - 20, width: artSize, height: artSize))
        albumArtImageView.imageScaling = .scaleProportionallyUpOrDown
        albumArtImageView.wantsLayer = true
        albumArtImageView.layer?.cornerRadius = 8
        albumArtImageView.layer?.masksToBounds = true
        albumArtImageView.autoresizingMask = [.minYMargin]
        contentView.addSubview(albumArtImageView)

        // Scroll view for info below
        let scrollViewY: CGFloat = 20
        let scrollViewHeight: CGFloat = 500 - artSize - 60
        scrollView = NSScrollView(frame: NSRect(x: 0, y: scrollViewY, width: 300, height: scrollViewHeight))
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.autoresizingMask = [.width, .height]

        infoTextView = NSTextView(frame: NSRect(x: 0, y: 0, width: 280, height: scrollViewHeight))
        infoTextView.isEditable = false
        infoTextView.isSelectable = true
        infoTextView.drawsBackground = false
        infoTextView.font = NSFont.systemFont(ofSize: 12)
        infoTextView.textColor = .labelColor
        infoTextView.textContainerInset = NSSize(width: 15, height: 10)

        scrollView.documentView = infoTextView
        contentView.addSubview(scrollView)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        updateContent()
    }

    private func updateContent() {
        guard let track = track else { return }

        // Show a placeholder immediately; real artwork loads asynchronously below.
        albumArtImageView.image = NSImage(systemSymbolName: "music.note", accessibilityDescription: "Music")
        albumArtImageView.contentTintColor = .tertiaryLabelColor

        // Render the text that needs no async metadata right away.
        infoTextView.string = buildInfoText(for: track, recordedDate: nil)

        let url = track.url
        Task { [weak self] in
            async let artwork = Self.loadArtwork(from: url)
            async let recorded = Self.loadRecordedDate(from: url)
            let (art, recordedDate) = await (artwork, recorded)

            await MainActor.run {
                guard let self = self, self.track?.url == url else { return }
                if let art = art {
                    self.albumArtImageView.image = art
                    self.albumArtImageView.contentTintColor = nil
                }
                if recordedDate != nil {
                    self.infoTextView.string = self.buildInfoText(for: track, recordedDate: recordedDate)
                }
            }
        }
    }

    private func buildInfoText(for track: PlaylistTrack, recordedDate: Date?) -> String {
        var infoText = ""
        infoText += "TRACK INFORMATION\n"
        infoText += "═══════════════════\n\n"
        infoText += "Title: \(track.displayTitle)\n\n"

        if let artist = track.artist, !artist.isEmpty {
            infoText += "Artist: \(artist)\n\n"
        }

        if let album = track.album, !album.isEmpty {
            infoText += "Album: \(album)\n\n"
        }

        if let duration = track.duration {
            infoText += "Duration: \(formatDuration(duration))\n\n"
        }

        infoText += "File: \(track.url.lastPathComponent)\n\n"
        infoText += "Path: \(track.url.path)\n\n"

        if track.isStream {
            infoText += "Type: Stream\n\n"
        }

        if let recordedDate = recordedDate {
            infoText += "Recorded: \(formatDate(recordedDate))\n\n"
        }

        if let creationDate = getFileCreationDate(for: track.url) {
            infoText += "File Created: \(formatDate(creationDate))\n\n"
        }

        infoText += "Added: \(formatDate(track.addedDate))\n"
        return infoText
    }

    private static func loadArtwork(from url: URL) async -> NSImage? {
        let asset = AVURLAsset(url: url)
        guard let formats = try? await asset.load(.availableMetadataFormats) else { return nil }
        for format in formats {
            guard let items = try? await asset.loadMetadata(for: format) else { continue }
            for item in items where item.commonKey?.rawValue == "artwork" {
                if let data = try? await item.load(.dataValue) {
                    return NSImage(data: data)
                }
            }
        }
        return nil
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func getFileCreationDate(for url: URL) -> Date? {
        guard url.isFileURL else { return nil }

        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            return attributes[.creationDate] as? Date
        } catch {
            NSLog("Failed to get creation date for \(url.path): \(error)")
            return nil
        }
    }

    private static func loadRecordedDate(from url: URL) async -> Date? {
        let asset = AVURLAsset(url: url)
        guard let formats = try? await asset.load(.availableMetadataFormats) else { return nil }
        for format in formats {
            guard let items = try? await asset.loadMetadata(for: format) else { continue }
            for item in items {
                guard let key = item.commonKey?.rawValue,
                      key == "creationDate" || key == "date" else { continue }

                // Prefer a native Date value, then fall back to parsing a string.
                if let date = try? await item.load(.dateValue) {
                    return date
                }
                if let dateString = try? await item.load(.stringValue),
                   let date = parseDate(dateString) {
                    return date
                }
            }
        }
        return nil
    }

    private static func parseDate(_ dateString: String) -> Date? {
        // Try ISO 8601 first, then common fixed formats.
        let isoFormatter = ISO8601DateFormatter()
        if let date = isoFormatter.date(from: dateString) {
            return date
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        if let date = dateFormatter.date(from: dateString) {
            return date
        }

        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return dateFormatter.date(from: dateString)
    }
}
