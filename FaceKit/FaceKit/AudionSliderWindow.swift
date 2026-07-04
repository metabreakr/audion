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

import Cocoa

class AudionSliderWindow: NSWindow {

    private let borderWidth: CGFloat = 8.0
    private let slider: NSSlider

    init(frame: NSRect, toolTip: String?) {
        self.slider = NSSlider(frame: frame)
        super.init(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)

        self.isReleasedWhenClosed = false
        self.hidesOnDeactivate = true

        if let contentView = self.contentView {
            contentView.wantsLayer = true
            contentView.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
            contentView.layer?.borderWidth = 1.0
            contentView.layer?.borderColor = NSColor.gridColor.cgColor

            self.slider.translatesAutoresizingMaskIntoConstraints = false

            contentView.addSubview(slider)
            self.slider.topAnchor.constraint(equalTo: contentView.topAnchor, constant: self.borderWidth).isActive = true
            self.slider.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -self.borderWidth).isActive = true
            self.slider.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: self.borderWidth).isActive = true
            self.slider.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -self.borderWidth).isActive = true
        }

        self.slider.setAccessibilityLabel(toolTip)
        self.level = .popUpMenu
    }

    func show(from view: NSView) {
        let origin = view.convert(CGPoint(x: view.frame.width, y: -self.frame.height), to: nil)
        self.show(from: view, offset: origin)
    }

    func show(from view: NSView, offset: CGPoint) {
        let globalPoint = view.window!.convertPoint(toScreen:offset)
        self.setFrame(NSRect(x: globalPoint.x, y: globalPoint.y, width: self.frame.width, height: self.frame.height), display: true)
        self.makeKeyAndOrderFront(view)
    }

    override var canBecomeKey: Bool {
        get {
            return true
        }
    }

    override func resignKey() {
        self.close()
        DispatchQueue.main.async {
            super.resignKey()
        }
    }

    var minValue: Double {
        get {
            return self.slider.minValue
        } set {
            self.slider.minValue = newValue
        }
    }

    var maxValue: Double {
        get {
            return self.slider.maxValue
        } set {
            self.slider.maxValue = newValue
        }
    }

    var doubleValue: Double {
        get {
            return self.slider.doubleValue
        } set {
            self.slider.doubleValue = newValue
        }
    }

    var target: AnyObject? {
        get {
            return self.slider.target
        } set {
            self.slider.target = newValue
        }
    }

    var action: Selector? {
        get {
            return self.slider.action
        } set {
            self.slider.action = newValue
        }
    }

    var isVertical: Bool {
        get {
            return self.slider.isVertical
        } set {
            self.slider.isVertical = newValue
        }
    }
}
