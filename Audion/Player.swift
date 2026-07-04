/*
Copyright 2020-2021 Panic Inc.

This file is part of Audion.

Audion is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

Audion is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with Audion.  If not, see <https://www.gnu.org/licenses/>.
*/

import AVFoundation
import Cocoa
import FaceKit

let AudionVolumePrefKey = "volume"

class Player: NSObject, AudionFaceViewDelegate {
    let supportsStop = true
    let supportsRewind = true
    let supportsFastForward = true

    private var avPlayer: AVPlayer? = nil {
        willSet {
            if let avPlayer = self.avPlayer {
                avPlayer.removeObserver(self, forKeyPath: "rate")
                avPlayer.removeObserver(self, forKeyPath: "status")
                avPlayer.removeObserver(self, forKeyPath: "timeControlStatus")
                if let currentItem = avPlayer.currentItem {
                    NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: currentItem)
                }
            }
        }
        didSet {
            if let avPlayer = self.avPlayer {
                avPlayer.addObserver(self, forKeyPath: "rate", options: .new, context: nil)
                avPlayer.addObserver(self, forKeyPath: "status", options: .new, context: nil)
                avPlayer.addObserver(self, forKeyPath: "timeControlStatus", options: .new, context: nil)
                if let currentItem = avPlayer.currentItem {
                    NotificationCenter.default.addObserver(self, selector: #selector(playerDidFinishPlaying), name: .AVPlayerItemDidPlayToEndTime, object: currentItem)
                }
            }
        }
    }

    var faceView: AudionFaceView? = nil
    private var filename: String? = nil
    private var streaming = false
    private var startedStream = false
    var playlistManager = PlaylistManager.shared

    func open(url: URL) -> Bool {
        let asset = AVURLAsset(url: url)
        let playerItem = AVPlayerItem(asset: asset)
        self.avPlayer = AVPlayer(playerItem: playerItem)
        self.avPlayer?.volume = UserDefaults.standard.float(forKey: AudionVolumePrefKey)
        self.avPlayer?.automaticallyWaitsToMinimizeStalling = true
        self.faceView?.stop()

        // The real duration is filled in asynchronously once the item is ready to
        // play (see updateMetadata); show "unknown" until then rather than blocking
        // the main thread to load it here.
        self.faceView?.durationInSeconds = -1

        if url.isFileURL {
            self.filename = url.lastPathComponent
        } else {
            self.filename = url.absoluteString
        }

        if ( url.scheme != "file" ) {
            self.streaming = true
            self.faceView?.animationType = .connecting
        }

        // A local file must exist to be playable; streams are always worth attempting.
        return url.isFileURL ? FileManager.default.fileExists(atPath: url.path) : true
    }

    var isPlaying: Bool {
        get {
            return self.faceView?.isPlaying ?? false
        }
    }

    var isScrubbing = false

    var duration: TimeInterval? {
        guard let item = avPlayer?.currentItem else { return nil }
        let duration = item.duration.seconds
        return duration.isFinite ? duration : nil
    }

    var currentTime: TimeInterval {
        return avPlayer?.currentTime().seconds ?? 0
    }

    func seek(to time: TimeInterval) {
        avPlayer?.seek(to: CMTime(seconds: time, preferredTimescale: CMTimeScale(NSEC_PER_SEC)))
    }

    func play() {
        if let avPlayer = self.avPlayer {
            avPlayer.play()

            if !self.isScrubbing {
                self.faceView?.play()
            }
        } else {
            // If no track is loaded, play the current track from playlist or first track
            if let currentTrack = playlistManager.currentTrack {
                if open(url: currentTrack.url) {
                    avPlayer?.play()
                    if !self.isScrubbing {
                        self.faceView?.play()
                    }
                }
            } else if !playlistManager.playlist.tracks.isEmpty {
                playlistManager.setCurrentTrack(at: 0)
                if let track = playlistManager.currentTrack, open(url: track.url) {
                    avPlayer?.play()
                    if !self.isScrubbing {
                        self.faceView?.play()
                    }
                }
            } else {
                // Only show file picker if playlist is empty
                NSApp.sendAction(NSSelectorFromString("openDocument:"), to: nil, from: self)
            }
        }
    }

    func pause() {
        self.avPlayer?.pause()

        if !self.isScrubbing {
            self.faceView?.pause()
        }
    }

    func stop() {
        self.avPlayer?.pause()

        if !self.isScrubbing {
            self.faceView?.stop()
        }

        self.startedStream = false
        self.streaming = false
        self.avPlayer = nil
    }

    func togglePlayPause() {
        if self.isPlaying {
            self.pause()
        } else {
            self.play()
        }
    }

    private(set) var isMuted = false
    private var preMuteVolume: Double = 0.0

    func mute() {
        self.preMuteVolume = self.faceView?.volume ?? 0.0
        self.isMuted = true
        self.faceView?.volume = 0.0
        self.avPlayer?.volume = 0.0
    }

    func unMute() {
        self.isMuted = false
        self.faceView?.volume = self.preMuteVolume
        self.avPlayer?.volume = Float(self.preMuteVolume)
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "rate" {
            if (self.avPlayer?.rate ?? 0) == 0 {
                if !self.isScrubbing {
                    self.faceView?.pause()
                }
            } else {
                if !self.isScrubbing {
                    self.faceView?.play()
                }
            }
        } else if keyPath == "status" {
            let status = self.avPlayer?.status ?? .unknown
            if status == .readyToPlay {
                self.updateMetadata()
            }
        } else if keyPath == "timeControlStatus" {
            if self.streaming {
                if self.avPlayer?.timeControlStatus == .waitingToPlayAtSpecifiedRate {
                    if self.startedStream {
                        self.faceView?.animationType = .lag
                    } else {
                        self.faceView?.animationType = .connecting
                    }
                } else {
                    self.startedStream = true
                    self.faceView?.animationType = .streaming
                }
            }
        }
    }

    private func updateMetadata() {
        // AVPlayerItem.duration (unlike AVAsset.duration) is not deprecated and is
        // valid now that the item is ready to play.
        let duration = self.avPlayer?.currentItem?.duration.seconds ?? 0.0

        if duration.isFinite {
            if self.streaming && duration == 0 {
                self.stop(self.faceView!)
                let alert = NSAlert()
                alert.messageText = "Connection failed"
                alert.informativeText = "Could not connect, or connection was refused by server."
                alert.runModal()
            } else {
                self.faceView?.durationInSeconds = Int(duration)
            }
        } else {
            self.faceView?.durationInSeconds = -1
            self.play()
        }

        // Load common metadata asynchronously so we never block the main thread.
        self.faceView?.artistText = nil

        if let asset = self.avPlayer?.currentItem?.asset {
            let filename = self.filename
            Task {
                var titleText: String?
                var artist = ""
                var album = ""
                var format = ""

                if let metadata = try? await asset.load(.commonMetadata) {
                    for datum in metadata {
                        guard let key = datum.commonKey else { continue }
                        let value = try? await datum.load(.stringValue)
                        switch key {
                        case .commonKeyTitle:
                            titleText = value
                        case .commonKeyArtist:
                            artist = value ?? ""
                        case .commonKeyAlbumName:
                            album = value ?? ""
                        case .commonKeyFormat:
                            format = value ?? ""
                        default:
                            break
                        }
                    }
                }

                // Resolve to immutable values before hopping to the main actor.
                let resolvedTitle = titleText ?? filename
                let parts = [artist, album, format].filter { $0.count > 0 }
                let resolvedAlbumText = parts.isEmpty ? nil : parts.joined(separator: "—")

                await MainActor.run { [weak self] in
                    self?.faceView?.artistText = resolvedTitle
                    self?.faceView?.albumText = resolvedAlbumText
                }
            }
        }

        self.avPlayer?.addPeriodicTimeObserver(forInterval: CMTime(seconds: 1.0, preferredTimescale: CMTimeScale(NSEC_PER_SEC)), queue: DispatchQueue.main) { time in
            if self.avPlayer != nil {
                self.faceView?.timeInSeconds = Int(time.seconds)
            }
        }
    }

    // MARK: - faceViewDelegate Methods

    func play(_ sender: AudionFaceView) {
        if let avPlayer = self.avPlayer {
            avPlayer.play()
        } else {
            // If no track is loaded, play the current track from playlist or first track
            if let currentTrack = playlistManager.currentTrack {
                if open(url: currentTrack.url) {
                    avPlayer?.play()
                }
            } else if !playlistManager.playlist.tracks.isEmpty {
                playlistManager.setCurrentTrack(at: 0)
                if let track = playlistManager.currentTrack, open(url: track.url) {
                    avPlayer?.play()
                }
            } else {
                // Only show file picker if playlist is empty
                NSApp.sendAction(NSSelectorFromString("openDocument:"), to: nil, from: self)
            }
        }
    }

    func pause(_ sender: AudionFaceView) {
        self.avPlayer?.pause()
    }

    func eject(_ sender: AudionFaceView) {
        // Toggle playlist mode between floating window and menu bar
        NSApp.sendAction(#selector(ViewController.togglePlaylistMode(_:)), to: nil, from: self)
    }

    func stop(_ sender: AudionFaceView) {
        self.stop()
    }

    func rewind(_ sender: AudionFaceView) {
        playPreviousTrack()
    }

    func fastForward(_ sender: AudionFaceView) {
        playNextTrack()
    }

    func volumeChanged(to volume: Double, sender: AudionFaceView) {
        if volume > 0 {
            self.isMuted = false
        }

        self.avPlayer?.volume = Float(volume)
        UserDefaults.standard.set(Float(volume), forKey: AudionVolumePrefKey)
    }

    func playTimeChanged(to time: Double, sender: AudionFaceView) {
        self.avPlayer?.seek(to: CMTime(seconds: time, preferredTimescale: CMTimeScale(NSEC_PER_SEC)))
    }

    func pauseBeforeScrubbing(_ sender: AudionFaceView) {
        self.isScrubbing = true
        self.avPlayer?.pause()
    }

    func playAfterScrubbing(_ sender: AudionFaceView) {
        self.isScrubbing = false
        self.avPlayer?.play()
    }

    // MARK: - Playlist Methods

    @objc private func playerDidFinishPlaying(notification: Notification) {
        if playlistManager.hasNextTrack {
            playNextTrack()
        } else {
            stop()
        }
    }

    func playNextTrack() {
        guard let nextTrack = playlistManager.nextTrack() else { return }

        if open(url: nextTrack.url) {
            play()
        }
    }

    func playPreviousTrack() {
        guard let previousTrack = playlistManager.previousTrack() else { return }

        if open(url: previousTrack.url) {
            play()
        }
    }

    func playTrack(at index: Int) {
        playlistManager.setCurrentTrack(at: index)
        guard let track = playlistManager.currentTrack else { return }

        if open(url: track.url) {
            play()
        }
    }
}
