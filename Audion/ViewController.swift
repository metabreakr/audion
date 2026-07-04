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
import UniformTypeIdentifiers

let AudionFloatingPrefKey = "floating"
let AudionScalePrefKey = "scale"

class ViewController: NSViewController, NSUserInterfaceValidations {
    private var faceView: AudionFaceView? = nil
    private let player = Player()
    private var faceObserver: NSKeyValueObservation? = nil

    private var hueFilter: CIFilter? = nil
    private var hueObserver: NSKeyValueObservation? = nil

    private var playlistViewController: PlaylistViewController?
    private let playlistWindowManager = PlaylistWindowManager.shared

    override func viewDidLoad() {
        super.viewDidLoad()

        let faceView = AudionFaceView(draggable: true, delegate: player)
        faceView.enableAllButtons = true
        faceView.face = AudionFace.default
        faceView.volume = UserDefaults.standard.double(forKey: AudionVolumePrefKey)
        player.faceView = faceView

        let view = self.view
        view.wantsLayer = true

        self.updateHue()

        self.hueObserver = UserDefaults.standard.observe(\.hue) { defaults, change in
            self.updateHue()
        }

        view.addSubview(faceView)

        view.topAnchor.constraint(equalTo: faceView.topAnchor).isActive = true;
        view.bottomAnchor.constraint(equalTo: faceView.bottomAnchor).isActive = true;
        view.leftAnchor.constraint(equalTo: faceView.leftAnchor).isActive = true;
        view.rightAnchor.constraint(equalTo: faceView.rightAnchor).isActive = true;

        faceView.durationInSeconds = 120

        self.faceView = faceView

        self.updateFace()

        self.faceObserver = UserDefaults.standard.observe(\.faceURL) { defaults, change in
            self.updateFace()
        }

        NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: NSApplication.shared, queue: OperationQueue.main) { _ in
            self.faceView?.isInactive = false
        }

        NotificationCenter.default.addObserver(forName: NSApplication.didResignActiveNotification, object: NSApplication.shared, queue: OperationQueue.main) { _ in
            self.faceView?.isInactive = !self.isFloating
        }

        setupPlaylist()
        setupFaceKitNotifications()
    }

    private func setupPlaylist() {
        let playlistVC = PlaylistViewController(nibName: "PlaylistView", bundle: nil)
        playlistVC.player = player
        playlistViewController = playlistVC
        playlistWindowManager.setup(with: playlistVC)
    }

    private func setupFaceKitNotifications() {
        // Listen for FaceKit button clicks
        NotificationCenter.default.addObserver(forName: NSNotification.Name("TogglePlaylist"), object: nil, queue: .main) { [weak self] _ in
            self?.togglePlaylist(nil)
        }

        NotificationCenter.default.addObserver(forName: NSNotification.Name("ToggleShuffle"), object: nil, queue: .main) { _ in
            let manager = PlaylistManager.shared
            if manager.isShuffled {
                manager.unshuffle()
            } else {
                manager.shuffle()
            }
        }

        NotificationCenter.default.addObserver(forName: NSNotification.Name("ShowInfoPanel"), object: nil, queue: .main) { [weak self] _ in
            self?.showInfoPanel(nil)
        }
    }

    override func viewWillAppear() {
        super.viewWillAppear()

        self.faceView?.scale = self.scale

        if UserDefaults.standard.bool(forKey: AudionFloatingPrefKey) {
            self.view.window?.level = .floating
        }

        playlistWindowManager.mainWindow = self.view.window
    }

    func updateHue() {
        if #available(macOS 10.15, *) {
            if let hueFilter = CIFilter(name: "CIHueAdjust", parameters: ["inputAngle": UserDefaults.standard.hue]) {
                view.layer?.filters = [hueFilter]
            }
        }
    }

    func updateFace() {
        if let faceURL = UserDefaults.standard.url(forKey: AudionFacePrefsKey) {
            do {
                self.faceView?.face = try AudionFace.load(path: faceURL)
            } catch {
                self.faceView?.face = AudionFace.default
            }
        }
    }

    deinit {
        self.faceObserver?.invalidate()
    }

    @IBAction func openDocument(_ sender: Any?) {
        self.stop(sender)
        let openPanel = NSOpenPanel()
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        openPanel.allowedContentTypes = AVURLAsset.audiovisualTypes().compactMap { UTType($0.rawValue) }

        let result = openPanel.runModal()
        if result == .OK {
            let _ = self.open(url: openPanel.url!)
        }
    }

    var openStreamWindowController: NSWindowController? = nil
    @IBAction func openStream(_ sender: Any?) {
        self.stop(sender)
        if self.openStreamWindowController == nil {
            if let viewController = NSStoryboard(name: "Main", bundle: nil).instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("OpenStreamSheet")) as? OpenStreamViewController {
                let window = NSWindow(contentRect: NSRect.zero, styleMask: .titled, backing: .buffered, defer: true)
                window.title = "Open Stream"
                window.contentViewController = viewController
                openStreamWindowController = NSWindowController(window: window)

                NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: OperationQueue.main) { _ in
                    self.openStreamWindowController = nil
                }

                window.center()

                viewController.callback = { str in
                    let url = URL(string: str)
                    if let url = url {
                        let _ = self.player.open(url: url)
                    }
                }
            }
        }

        self.openStreamWindowController?.window?.makeKeyAndOrderFront(self)
    }

    func open(url: URL) -> Bool {
        if self.player.open(url: url) {
            NSDocumentController.shared.noteNewRecentDocumentURL(url)
            self.player.play()
            return true
        }

        return false
    }

    // MARK: - Playlist Actions

    @IBAction func togglePlaylist(_ sender: Any?) {
        playlistWindowManager.toggleVisibility()
    }

    @IBAction func addToPlaylist(_ sender: Any?) {
        let openPanel = NSOpenPanel()
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        openPanel.allowsMultipleSelection = true
        openPanel.allowedContentTypes = AVURLAsset.audiovisualTypes().compactMap { UTType($0.rawValue) }

        let result = openPanel.runModal()
        if result == .OK {
            for url in openPanel.urls {
                PlaylistManager.shared.addURL(url)
            }
        }
    }

    @IBAction func nextTrack(_ sender: Any?) {
        player.playNextTrack()
    }

    @IBAction func previousTrack(_ sender: Any?) {
        player.playPreviousTrack()
    }

    @IBAction func savePlaylist(_ sender: Any?) {
        playlistViewController?.savePlaylist(sender ?? self)
    }

    @IBAction func loadPlaylist(_ sender: Any?) {
        playlistViewController?.loadPlaylist(sender ?? self)
    }

    @IBAction func clearPlaylist(_ sender: Any?) {
        PlaylistManager.shared.clearPlaylist()
    }

    @IBAction func toggleShuffle(_ sender: Any?) {
        playlistViewController?.toggleShuffle(sender ?? self)
    }

    @IBAction func selectAllTracks(_ sender: Any?) {
        playlistViewController?.selectAllTracks(sender ?? self)
    }

    @IBAction func removeTrack(_ sender: Any?) {
        playlistViewController?.removeSelectedTracks(sender ?? self)
    }

    @IBAction func undoRemoveTrack(_ sender: Any?) {
        playlistViewController?.undoRemoveTrack(sender ?? self)
    }

    @IBAction func redoRemoveTrack(_ sender: Any?) {
        playlistViewController?.redoRemoveTrack(sender ?? self)
    }

    @IBAction func setPlaylistModeFloating(_ sender: Any?) {
        playlistWindowManager.currentMode = .floatingWindow
        playlistWindowManager.show()
    }

    @IBAction func setPlaylistModeMenuBar(_ sender: Any?) {
        playlistWindowManager.currentMode = .menuBar
        playlistWindowManager.show()
    }

    @IBAction func togglePlaylistMode(_ sender: Any?) {
        // Toggle between floating window and menu bar
        if playlistWindowManager.currentMode == .floatingWindow {
            playlistWindowManager.currentMode = .menuBar
        } else {
            playlistWindowManager.currentMode = .floatingWindow
        }
        playlistWindowManager.show()
    }

    @IBAction func showInfoPanel(_ sender: Any?) {
        // Show playlist window if it's hidden
        if !playlistWindowManager.isCurrentlyVisible {
            playlistWindowManager.show()
        }

        // If no tracks are selected, select the current playing track
        if let playlistVC = playlistViewController, !playlistVC.hasSelectedTracks() {
            if let currentIndex = player.playlistManager.currentTrackIndex {
                playlistVC.selectTrack(at: currentIndex)
            }
        }

        playlistViewController?.showInfoDrawer(sender)
    }

    @IBAction func playPause(_ sender: Any?) {
        self.player.togglePlayPause()
    }

    @IBAction func stop(_ sender: Any?) {
        self.player.stop()
    }

    @IBAction func muteUnmute(_ sender: Any?) {
        if self.player.isMuted {
            self.player.unMute()
        } else {
            self.player.mute()
        }
    }

    private var scale: CGFloat {
        get {
            let scale = CGFloat(UserDefaults.standard.double(forKey: AudionScalePrefKey))

            if scale > 1.0 {
                return 2.0
            } else {
                return 1.0
            }
        }
    }


    @IBAction func setScale(_ sender: Any?) {
        let scale: CGFloat
        if let sender = sender as? NSMenuItem {
            scale = CGFloat(sender.tag)
        } else {
            scale = 0
        }

        UserDefaults.standard.set(scale, forKey: AudionScalePrefKey)
        self.faceView?.scale = self.scale
    }

    var isFloating: Bool {
        get {
            self.view.window?.level ?? .normal == .floating
        }
    }

    @IBAction func toggleFloating(_ sender: Any?) {
        if self.isFloating {
            self.view.window?.level = .normal
            UserDefaults.standard.set(false, forKey: AudionFloatingPrefKey)
        } else {
            self.view.window?.level = .floating
            UserDefaults.standard.set(true, forKey: AudionFloatingPrefKey)
        }
        // Update playlist window level to match
        playlistWindowManager.updateWindowLevel()
    }

    func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
        if let item = item as? NSMenuItem {
            let action = item.action
            if action == #selector(playPause(_:)) {
                if self.player.isPlaying {
                    item.title = NSLocalizedString("Pause", comment: "")
                } else {
                    item.title = NSLocalizedString("Play", comment: "")
                }
            } else if action == #selector(stop(_:)) {
                return self.player.isPlaying
            } else if action == #selector(muteUnmute(_:)) {
                if self.player.isMuted {
                    item.title = NSLocalizedString("Unmute", comment: "")
                } else {
                    item.title = NSLocalizedString("Mute", comment: "")
                }
            } else if action == #selector(toggleFloating(_:)) {
                if self.isFloating {
                    item.state = .on
                } else {
                    item.state = .off
                }
            } else if action == #selector(setScale(_:)) {
                let scale = UserDefaults.standard.integer(forKey: AudionScalePrefKey)
                if item.tag == scale {
                    item.state = .on
                } else {
                    item.state = .off
                }
            } else if action == #selector(nextTrack(_:)) {
                return player.playlistManager.hasNextTrack
            } else if action == #selector(previousTrack(_:)) {
                return player.playlistManager.hasPreviousTrack
            } else if action == #selector(setPlaylistModeFloating(_:)) {
                item.state = playlistWindowManager.currentMode == .floatingWindow ? .on : .off
            } else if action == #selector(setPlaylistModeMenuBar(_:)) {
                item.state = playlistWindowManager.currentMode == .menuBar ? .on : .off
            } else if action == #selector(undoRemoveTrack(_:)) {
                return playlistViewController?.canUndoRemove() ?? false
            } else if action == #selector(redoRemoveTrack(_:)) {
                return playlistViewController?.canRedoRemove() ?? false
            } else if action == #selector(removeTrack(_:)) {
                return playlistViewController?.hasSelectedTracks() ?? false
            } else if action == #selector(selectAllTracks(_:)) {
                return playlistViewController?.hasAnyTracks() ?? false
            } else if action == #selector(showInfoPanel(_:)) {
                // Enable if there are any tracks or a track is currently playing
                return playlistViewController?.hasAnyTracks() ?? false
            }
        }

        return true
    }
}

