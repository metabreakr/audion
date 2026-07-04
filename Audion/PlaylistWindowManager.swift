//
//  PlaylistWindowManager.swift
//  Audion
//
//  Manages playlist window display modes: floating window and menu bar
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

let PlaylistUIModeKey = "playlistUIMode"
let PlaylistVisibleKey = "playlistVisible"

class PlaylistWindowManager: NSObject {
    static let shared = PlaylistWindowManager()

    private var floatingWindow: NSWindow?
    private var menuBarPopover: NSPopover?
    private var statusItem: NSStatusItem?

    weak var playlistViewController: PlaylistViewController?
    weak var mainWindow: NSWindow?

    var currentMode: PlaylistUIMode {
        get {
            if let modeString = UserDefaults.standard.string(forKey: PlaylistUIModeKey),
               let mode = PlaylistUIMode(rawValue: modeString) {
                return mode
            }
            return .floatingWindow
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: PlaylistUIModeKey)
            updateDisplayMode()
        }
    }


    private var isVisible: Bool {
        get {
            UserDefaults.standard.bool(forKey: PlaylistVisibleKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: PlaylistVisibleKey)
        }
    }

    private override init() {
        super.init()
        setupNotifications()
    }

    private func setupNotifications() {
        // Observe app activation/deactivation to adjust floating window transparency
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidResignActive),
            name: NSApplication.didResignActiveNotification,
            object: nil
        )
    }

    @objc private func applicationDidBecomeActive(_ notification: Notification) {
        // Make floating window fully opaque when app becomes active
        updateWindowAlpha()
    }

    @objc private func applicationDidResignActive(_ notification: Notification) {
        // Make floating window semi-transparent when app goes to background
        updateWindowAlpha()
    }

    private func updateWindowAlpha() {
        guard currentMode == .floatingWindow, let window = floatingWindow else { return }
        window.alphaValue = NSApp.isActive ? 1.0 : 0.6
    }

    func setup(with viewController: PlaylistViewController) {
        self.playlistViewController = viewController
        updateDisplayMode()

        if isVisible {
            show()
        }
    }

    func toggleVisibility() {
        if isCurrentModeVisible() {
            hide()
        } else {
            show()
        }
    }

    func show() {
        isVisible = true

        switch currentMode {
        case .floatingWindow:
            showFloatingWindow()
        case .menuBar:
            showMenuBar()
        }
    }

    func hide() {
        isVisible = false

        switch currentMode {
        case .floatingWindow:
            hideFloatingWindow()
        case .menuBar:
            hideMenuBar()
        }
    }

    func updateWindowLevel() {
        let isFloating = UserDefaults.standard.bool(forKey: "floating")
        floatingWindow?.level = isFloating ? .floating : .normal
    }

    var isCurrentlyVisible: Bool {
        return isCurrentModeVisible()
    }

    private func isCurrentModeVisible() -> Bool {
        switch currentMode {
        case .floatingWindow:
            return floatingWindow?.isVisible ?? false
        case .menuBar:
            return menuBarPopover?.isShown ?? false
        }
    }

    private func updateDisplayMode() {
        // Save current window position before switching modes
        if let window = floatingWindow {
            // Save frame manually to UserDefaults
            let frameString = NSStringFromRect(window.frame)
            UserDefaults.standard.set(frameString, forKey: "SavedPlaylistWindowFrame")
        }

        hideAll()

        switch currentMode {
        case .floatingWindow:
            // Reuse existing window if it exists, otherwise create new one
            if floatingWindow == nil {
                createFloatingWindow()
            } else {
                // The shared view controller may have been moved into the menu-bar
                // popover, which leaves the window blank. Re-seat it before showing.
                installViewControllerInFloatingWindow()
                // Manually restore the saved frame
                if let frameString = UserDefaults.standard.string(forKey: "SavedPlaylistWindowFrame") {
                    let frame = NSRectFromString(frameString)
                    floatingWindow?.setFrame(frame, display: false)
                }
            }
            if isVisible {
                show()
            }
        case .menuBar:
            createMenuBar()
            // Menu bar icon is always visible when in menu bar mode
            // But popover only shows if isVisible is true
            if isVisible {
                showMenuBar()
            }
        }
    }

    private func hideAll() {
        hideFloatingWindow()
        removeMenuBar()
    }

    // MARK: - Floating Window Mode

    /// Re-seats the shared playlist view controller in the floating window. The
    /// same view controller is also used by the menu-bar popover, and a view can
    /// only live in one place at a time — so if the popover took it, the window is
    /// left blank. Reassigning here reclaims the view. Skipped when the view is
    /// already in this window, to avoid a needless reload.
    private func installViewControllerInFloatingWindow() {
        guard let viewController = playlistViewController, let window = floatingWindow else { return }
        if viewController.view.window !== window {
            window.contentViewController = nil
            window.contentViewController = viewController
        }
    }

    private func createFloatingWindow() {
        guard let viewController = playlistViewController else { return }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 500),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        window.title = "Audion Playlist"
        window.contentViewController = viewController
        window.isReleasedWhenClosed = false
        window.delegate = self

        // Enable automatic window frame saving
        window.setFrameAutosaveName("PlaylistFloatingWindow")

        // Match the main window's always-on-top setting
        let isFloating = UserDefaults.standard.bool(forKey: "floating")
        window.level = isFloating ? .floating : .normal

        // Restore saved frame or center on first launch
        if !window.setFrameUsingName("PlaylistFloatingWindow") {
            window.center()
        }

        floatingWindow = window

        // Set initial alpha based on app active state
        updateWindowAlpha()
    }

    private func showFloatingWindow() {
        guard let window = floatingWindow else {
            createFloatingWindow()
            showFloatingWindow()
            return
        }

        installViewControllerInFloatingWindow()
        window.makeKeyAndOrderFront(nil)
        updateWindowAlpha()
    }

    private func hideFloatingWindow() {
        floatingWindow?.orderOut(nil)
    }

    // MARK: - Menu Bar Mode

    /// Creates the status-bar item once and keeps it for the app's lifetime.
    /// Repeatedly removing and re-adding a status item on every mode switch is what
    /// made the icon vanish — the fresh item often fails to appear when the removal
    /// is still being processed on the same run-loop pass.
    private func ensureStatusItem() {
        guard statusItem == nil else { return }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            // Template SF Symbol rather than a text title: text-only status items can
            // render zero-width and misbehave with menu-bar managers like Bartender.
            if let image = NSImage(systemSymbolName: "music.note.list", accessibilityDescription: "Audion Playlist") {
                image.isTemplate = true
                button.image = image
            } else {
                button.title = "♫"
            }
            button.action = #selector(handleStatusItemClick(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        statusItem = item
    }

    private func createMenuBar() {
        ensureStatusItem()
        statusItem?.isVisible = true

        let popover = NSPopover()
        popover.contentSize = NSSize(width: 400, height: 500)
        popover.behavior = .transient
        popover.contentViewController = playlistViewController

        menuBarPopover = popover
    }

    @objc private func handleStatusItemClick(_ sender: Any?) {
        guard let button = statusItem?.button else { return }
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            // Right-click: show context menu
            let menu = NSMenu()

            let showMainWindowItem = NSMenuItem(title: "Show Main Window", action: #selector(showMainWindow(_:)), keyEquivalent: "")
            showMainWindowItem.target = self
            menu.addItem(showMainWindowItem)

            menu.addItem(NSMenuItem.separator())

            let switchToFloatingItem = NSMenuItem(title: "Switch to Floating Window", action: #selector(switchToFloatingWindow(_:)), keyEquivalent: "")
            switchToFloatingItem.target = self
            menu.addItem(switchToFloatingItem)

            menu.addItem(NSMenuItem.separator())

            let quitItem = NSMenuItem(title: "Quit Audion", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
            menu.addItem(quitItem)

            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height), in: button)
        } else {
            // Left-click: toggle popover
            toggleMenuBarPopover(sender)
        }
    }

    @objc private func toggleMenuBarPopover(_ sender: Any?) {
        guard let popover = menuBarPopover,
              let button = statusItem?.button else { return }

        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    @objc private func showMainWindow(_ sender: Any?) {
        mainWindow?.makeKeyAndOrderFront(sender)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func switchToFloatingWindow(_ sender: Any?) {
        currentMode = .floatingWindow
        show()
    }

    private func showMenuBar() {
        // Only show if we're actually in menu bar mode
        guard currentMode == .menuBar else { return }

        guard let popover = menuBarPopover,
              let button = statusItem?.button else {
            // Don't recursively call - menu bar will be created by updateDisplayMode
            return
        }

        if !popover.isShown {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    private func hideMenuBar() {
        // When in menu bar mode, just close the popover but keep the menu bar icon
        menuBarPopover?.performClose(nil)
    }

    private func removeMenuBar() {
        // Hide the icon and drop the popover, but keep the status item alive so it
        // reappears reliably on the next switch to menu-bar mode.
        menuBarPopover?.performClose(nil)
        menuBarPopover = nil
        statusItem?.isVisible = false
    }
}

// MARK: - NSWindowDelegate

extension PlaylistWindowManager: NSWindowDelegate {
    func windowDidBecomeKey(_ notification: Notification) {
        // When playlist window becomes key, also bring main window to front (unless floating)
        let isFloating = UserDefaults.standard.bool(forKey: "floating")
        if !isFloating, let mainWindow = mainWindow {
            mainWindow.orderFront(nil)
        }
    }
}
