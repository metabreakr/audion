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
import Carbon.HIToolbox

public protocol AudionFaceViewDelegate: AnyObject {
    var supportsStop: Bool { get }
    var supportsRewind: Bool { get }
    var supportsFastForward: Bool { get }

    func play(_ sender: AudionFaceView)
    func pause(_ sender: AudionFaceView)
    func stop(_ sender: AudionFaceView)
    func rewind(_ sender: AudionFaceView)
    func fastForward(_ sender: AudionFaceView)
    func eject(_ sender: AudionFaceView)
    func volumeChanged(to: Double, sender: AudionFaceView)
    func playTimeChanged(to: Double, sender: AudionFaceView)

    func pauseBeforeScrubbing(_ sender: AudionFaceView)
    func playAfterScrubbing(_ sender: AudionFaceView)
}

fileprivate protocol AudionFaceElement {
    var unscaledRect: CGRect { get }
    var leftConstraint: NSLayoutConstraint? { get }
    var topConstraint: NSLayoutConstraint? { get }
    var widthConstraint: NSLayoutConstraint? { get }
    var heightConstraint: NSLayoutConstraint? { get }
}

public class AudionFaceView: NSView, CALayerDelegate {
    public enum AnimationType {
        case none
        case connecting
        case streaming
        case lag
    }

    public var isInactive = false {
        didSet {
            self.updateMask()
        }
    }

    private let draggable: Bool
    private unowned let delegate: AudionFaceViewDelegate
    private var widthConstraint: NSLayoutConstraint? = nil
    private var heightConstraint: NSLayoutConstraint? = nil
    private var timer: Timer? = nil

    private var animationFrame: Int = 0
    public var animationType: AnimationType = .none {
        didSet {
            self.animationFrame = 0
        }
    }

    private var animation: AudionFace.Animation? {
        get {
            let animation: AudionFace.Animation?
            switch self.animationType {
            case .connecting:
                animation = self.face?.connectingAnim
            case .streaming:
                animation = self.face?.streamingAnim
            case .lag:
                animation = self.face?.netLagAnim
            default:
                animation = nil
            }
            return animation
        }
    }

    private var frameNum = 0 {
        didSet {
            self.artistLabel?.frameNum = self.frameNum
            self.albumLabel?.frameNum = self.frameNum
            self.updateAnimationFrame()
        }
    }

    private func updateAnimationFrame() {
        if let animation = self.animation, animation.frameDelay > 0, animation.frames.count > 0 {
            let animationFrame = (self.frameNum / animation.frameDelay) % animation.frames.count

            if animationFrame != self.animationFrame {
                self.animationFrame = animationFrame
                self.setNeedsDisplay(flippedRect(from: animation.rect))
            }
        }
    }

    private var timeDigitsAccessibilityElement: TimeDigitsAccessibilityRect? = nil

    private let positionSliderTooltip: NSString = (LocalizedString("Show Position Slider")! as NSString)

    let sublayer = CALayer()
    public init(draggable: Bool, delegate: AudionFaceViewDelegate) {
        self.draggable = draggable
        self.delegate = delegate
        self.volumeSlider = AudionSliderWindow(frame: NSRect(x: 0, y: 0, width: 19.0, height: 96.0), toolTip: LocalizedString("Volume"))
        self.timeSlider = AudionSliderWindow(frame: NSRect(x: 0, y: 0, width: 192.0, height: 19.0), toolTip: self.positionSliderTooltip as String)

        super.init(frame: CGRect.zero)
        self.translatesAutoresizingMaskIntoConstraints = false
        self.widthConstraint = self.widthAnchor.constraint(equalToConstant: 0)
        self.heightConstraint = self.heightAnchor.constraint(equalToConstant: 0)

        self.widthConstraint?.isActive = true
        self.heightConstraint?.isActive = true

        self.volumeSlider.target = self
        self.volumeSlider.action = #selector(adjustVolume(_:))
        self.volumeSlider.isVertical = true

        self.timeSlider.target = self
        self.timeSlider.action = #selector(adjustTime(_:))

        self.timeSlider.minValue = 0.0

        self.timer = Timer.scheduledTimer(withTimeInterval: (1.0 / 60.0), repeats: true, block: { _ in
            self.frameNum += 1
        })

        NotificationCenter.default.addObserver(forName: NSWindow.didResignKeyNotification, object: self.volumeSlider, queue: OperationQueue.main) { _ in
            self.volumeButton?.isEnabled = true
        }

        self.wantsLayer = true
        self.layer?.addSublayer(self.sublayer)
        self.sublayer.zPosition = 2
        self.sublayer.delegate = self
        self.layer?.delegate = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        self.timer?.invalidate()
    }

    public var scale: CGFloat = 1.0 {
        didSet {
            self.updateFrames()
        }
    }

    private var artistTextImage: CGImage? = nil
    private var artistLabel: LabelView? = nil
    public var artistText: String? = nil {
        didSet {
            self.updateFrames()
        }
    }

    private var albumTextImage: CGImage? = nil
    private var albumLabel: LabelView? = nil
    public var albumText: String? = nil {
        didSet {
            self.updateFrames()
        }
    }

    private func updateMask() {
        if self.isInactive, let mask = self.face?.inactiveMask {
            self.applyMask(mask: mask)
        } else if let mask = self.face?.mask {
            self.applyMask(mask: mask)
        } else {
            self.layer?.mask = nil
        }
    }

    private func applyMask(mask: CGImage) {
        let maskLayer = CALayer()
        let frame = self.frame
        let scale = self.scale
        
        if scale > 1.0, let scaledMask = FaceKit.resize(image: mask, scale: scale) {
            maskLayer.contents = scaledMask
        } else {
            maskLayer.contents = mask
        }
        maskLayer.contentsGravity = .bottomLeft
        
        maskLayer.frame = CGRect(x: frame.origin.x * scale, y: frame.origin.y * scale, width: frame.size.width * scale, height: frame.size.height * scale)
        
        self.layer?.mask = maskLayer
    }

    private func updateFrames() {
        self.removeAllToolTips()

        if let face = self.face {
            let base = face.base
            self.widthConstraint?.constant = CGFloat(base.width) * self.scale
            self.heightConstraint?.constant = CGFloat(base.height) * self.scale

            self.updateMask()

            for subview in self.subviews {
                if let subview = subview as? NSView & AudionFaceElement {
                    var frame = subview.unscaledRect
                    frame.origin.x *= scale
                    frame.origin.y *= scale
                    frame.size.width *= scale
                    frame.size.height *= scale
                    subview.leftConstraint?.constant = frame.origin.x
                    subview.topConstraint?.constant = frame.origin.y
                    subview.widthConstraint?.constant = frame.size.width
                    subview.heightConstraint?.constant = frame.size.height
                }
            }

            var digitsRect = CGRect.zero
            for digit in [ face.timeDigit1, face.timeDigit2, face.timeDigit3, face.timeDigit4 ] {
                if let digit = digit {
                    var rect = self.flippedRect(from: digit.rect, height: CGFloat(base.height))
                    rect.origin.y = CGFloat(base.height) - rect.maxY

                    if self.durationInSeconds > 0 {
                        self.addToolTip(rect, owner: self.positionSliderTooltip, userData: nil)
                    }

                    digitsRect = digitsRect.union(rect)
                }
            }

            self.timeDigitsAccessibilityElement = TimeDigitsAccessibilityRect(player: self, rect: self.flippedRect(from: digitsRect, height: CGFloat(base.height)))

            if let artistText = self.artistText, let rect = face.artistDisplayRect, rect.width > 12.0, !artistText.isEmpty {
                let style = face.artistStyle
                self.artistTextImage = self.draw(text: artistText, font: face.artistFont, color: face.artistColor, width: rect.width, bold: style.contains(.bold), italic: style.contains(.italic), underline: style.contains(.underline), outline: style.contains(.outline), shadow: style.contains(.shadow), condense: style.contains(.condense), extend: style.contains(.extend), justify: true)

                if self.artistLabel == nil {
                    self.artistLabel = LabelView(draggable: self.draggable, xor: face.artistXor)
                    self.addSubview(self.artistLabel!)
                }

                if let artistLabel = self.artistLabel, let artistTextImage = self.artistTextImage {
                    artistLabel.frame = self.flippedRect(from: rect)
                    artistLabel.string = artistText
                    artistLabel.image = artistTextImage
                    artistLabel.frameNum = self.frameNum
                    artistLabel.justify = true
                }
            } else {
                self.artistTextImage = nil

                if let artistLabel = self.artistLabel {
                    artistLabel.removeFromSuperview()
                    self.artistLabel = nil
                }
            }

            if let albumText = self.albumText, let rect = face.albumDisplayRect, rect.width > 12.0 {
                let justify = face.albumStyle.contains(.justify)
                let style = face.albumStyle
                self.albumTextImage = self.draw(text: albumText, font: face.albumFont, color: face.albumColor, width: rect.width, bold: style.contains(.bold), italic: style.contains(.italic), underline: style.contains(.underline), outline: style.contains(.outline), shadow: style.contains(.shadow), condense: style.contains(.condense), extend: style.contains(.extend), justify: justify)

                if self.albumLabel == nil {
                    self.albumLabel = LabelView(draggable: self.draggable, xor: face.albumXor)
                    self.addSubview(self.albumLabel!)
                }

                if let albumLabel = self.albumLabel, let albumTextImage = self.albumTextImage {
                    albumLabel.frame = self.flippedRect(from: rect)
                    albumLabel.string = albumText
                    albumLabel.image = albumTextImage
                    albumLabel.frameNum = self.frameNum
                    albumLabel.justify = false
                }
            } else {
                self.albumTextImage = nil

                if let albumLabel = self.albumLabel {
                    albumLabel.removeFromSuperview()
                    self.albumLabel = nil
                }
            }
        }
    }

    public private(set) var isPlaying = false

    public func play() {
        self.isPlaying = true
        self.updatePlayButton()
    }

    public func pause() {
        self.isPlaying = false
        self.updatePlayButton()
    }

    public func stop() {
        self.timeInSeconds = 0
        self.durationInSeconds = 0
        self.artistText = nil
        self.albumText = nil
        self.needsDisplay = true
        self.animationType = .none
        self.isPlaying = false
        self.updatePlayButton()
        self.animationType = .none
    }

    private func updatePlayButton() {
        if self.isPlaying, let pauseButton = self.pauseButton {
            self.playButton?.isHidden = true
            pauseButton.isHidden = false
        } else {
            self.playButton?.isHidden = false
            self.pauseButton?.isHidden = true
        }

        self.stopButton?.isEnabled = (self.delegate.supportsStop && self.durationInSeconds != 0)
    }

    private var playButton: Button? = nil
    private var pauseButton: Button? = nil
    private var stopButton: Button? = nil
    private var rewindButton: Button? = nil
    private var fastForwardButton: Button? = nil
    private var ejectButton: Button? = nil

    private var closeButton: Button? = nil
    private var infoButton: Button? = nil
    private var volumeButton: Button? = nil
    private var playlistButton: Button? = nil
    private var modeButton: Button? = nil

    @IBAction func play(_ sender: Any?) {
        self.delegate.play(self)
    }

    @IBAction func pause(_ sender: Any?) {
        self.delegate.pause(self)
    }

    @IBAction func stop(_ sender: Any?) {
        self.delegate.stop(self)
    }

    @IBAction func rewind(_ sender: Any?) {
        self.delegate.rewind(self)
    }

    @IBAction func fastForward(_ sender: Any?) {
        self.delegate.fastForward(self)
    }

    @IBAction func eject(_ sender: Any?) {
        self.delegate.eject(self)
    }

    public var enableAllButtons = false

    public var face: AudionFace? = nil {
        didSet {
            for subview in self.subviews {
                if let subview = subview as? NSView & AudionFaceElement {
                    subview.removeFromSuperview()
                }
            }

            self.playButton = self.loadButton(config: self.face?.playButton, superview: self, target: self, action: #selector(play(_:)), toolTip: LocalizedString("Play"))
            self.pauseButton = self.loadButton(config: self.face?.pauseButton, superview: self, target: self, action: #selector(pause(_:)), toolTip: LocalizedString("Pause"))
            self.stopButton = self.loadButton(config: self.face?.stopButton, superview: self, target: self, action: #selector(stop(_:)), toolTip: LocalizedString("Stop"))
            self.rewindButton = self.loadButton(config: self.face?.rewindButton, superview: self, target: self, action: #selector(rewind(_:)), toolTip: LocalizedString("Rewind / Previous Track"))
            self.fastForwardButton = self.loadButton(config: self.face?.fastForwardButton, superview: self, target: self, action: #selector(fastForward(_:)), toolTip: LocalizedString("Fast Forward / Next Track"))
            self.ejectButton = self.loadButton(config: self.face?.ejectButton, superview: self, target: self, action: #selector(eject(_:)), toolTip: LocalizedString("Toggle Playlist Mode"))

            self.closeButton = self.loadButton(config: self.face?.closeButton, superview: self, target: nil, action: nil, toolTip: LocalizedString("Close"))
            self.infoButton = self.loadButton(config: self.face?.infoButton, superview: self, target: self, action: #selector(showInfo(_:)), toolTip: LocalizedString("Info"))
            self.volumeButton = self.loadButton(config: self.face?.volumeButton, superview: self, target: self, action: #selector(toggleVolume(_:)), toolTip: LocalizedString("Show Volume Slider"))
            self.playlistButton = self.loadButton(config: self.face?.playlistButton, superview: self, target: self, action: #selector(togglePlaylist(_:)), toolTip: LocalizedString("Show/Hide Playlist"))
            self.modeButton = self.loadButton(config: self.face?.modeButton, superview: self, target: self, action: #selector(toggleMode(_:)), toolTip: LocalizedString("Toggle Shuffle"))

            self.updatePlayButton()

            self.stopButton?.isEnabled = self.delegate.supportsStop && self.isPlaying
            self.rewindButton?.isEnabled = self.delegate.supportsRewind
            self.fastForwardButton?.isEnabled = self.delegate.supportsFastForward
            self.ejectButton?.isEnabled = self.enableAllButtons
            self.closeButton?.isEnabled = self.enableAllButtons
            self.infoButton?.isEnabled = self.enableAllButtons
            self.playlistButton?.isEnabled = self.enableAllButtons
            self.modeButton?.isEnabled = self.enableAllButtons

            if let artistLabel = self.artistLabel {
                artistLabel.removeFromSuperview()
                self.artistLabel = nil
            }

            if let albumLabel = self.albumLabel {
                albumLabel.removeFromSuperview()
                self.albumLabel = nil
            }

            self.updateAnimationFrame()
            self.updateFrames()
            self.needsDisplay = true
        }
    }

    private func loadButton(config: AudionFace.Button?, superview: NSView, target: AnyObject?, action: Selector?, toolTip: String?) -> Button? {
        if let config = config {
            let button = Button(normalImage: config.image, disabledImage: config.disabledImage, pressedImage: config.pressedImage, hoverImage: config.hoverImage, target: target, action: action, frame: config.rect, superview: self)
            button.toolTip = toolTip
            button.setAccessibilityLabel(toolTip)
            return button
        } else {
            return nil
        }
    }

    public override func draw(_ dirtyRect: NSRect) {
        self.layer?.setNeedsDisplay()
    }

    public func draw(_ layer: CALayer, in context: CGContext) {
        if let face = self.face {
            context.saveGState()
            let quality = context.interpolationQuality
            context.saveGState()
            context.interpolationQuality = .none

            if layer == self.layer {
                context.draw(face.base, in: self.bounds)

                if let animation = self.animation {
                    self.draw(animation: animation, context: context)
                }

                self.sublayer.frame = self.frame
                self.sublayer.setNeedsDisplay()
            } else {
                let minutes = self.timeInSeconds / 60
                let seconds = self.timeInSeconds % 60

                let firstDigit = minutes / 10
                let secondDigit = minutes % 10
                let thirdDigit = seconds / 10
                let forthDigit = seconds % 10

                self.draw(digit: face.timeDigit1, number: firstDigit, context: context)
                self.draw(digit: face.timeDigit2, number: secondDigit, context: context)
                self.draw(digit: face.timeDigit3, number: thirdDigit, context: context)
                self.draw(digit: face.timeDigit4, number: forthDigit, context: context)

                self.draw(digit: face.trackDigit1, number: 10, context: context)
                self.draw(digit: face.trackDigit2, number: 10, context: context)

                self.draw(indicator: face.CDDBIndicator, on: false, context: context)
                self.draw(indicator: face.CDIndicator, on: false, context: context)
                self.draw(indicator: face.netIndicator, on: self.durationInSeconds != 0 && self.animationType != .none, context: context)
                self.draw(indicator: face.MP3Indicator, on: self.durationInSeconds != 0 && self.animationType == .none, context: context)
                self.draw(indicator: face.playIndicator, on: self.isPlaying, context: context)
                self.draw(indicator: face.pauseIndicator, on: self.durationInSeconds != 0 && !isPlaying, context: context)
            }

            context.interpolationQuality = quality
            context.restoreGState()
        }
    }

    func draw(digit: AudionFace.Digit?, number: Int, context: CGContext) {
        if let digit = digit {
            if number < 0 || number >= digit.numPICTs {
                return
            }

            let rect = flippedRect(from: digit.rect)
            if self.needsToDraw(rect) {
                context.clear(rect)
                context.draw(digit.images[number], in: rect)
            }
        }
    }

    func draw(indicator: AudionFace.Indicator?, on: Bool, context: CGContext) {
        if let indicator = indicator {
            let rect = flippedRect(from: indicator.rect)

            if self.needsToDraw(rect) {
                context.clear(rect)

                if on {
                    context.draw(indicator.onImage, in: rect)
                } else {
                    context.draw(indicator.image, in: rect)
                }
            }
        }
    }

    func draw(animation: AudionFace.Animation, context: CGContext) {
        let rect = flippedRect(from: animation.rect)

        if self.needsToDraw(rect) && animation.frames.count > 0 && self.animationFrame < animation.frames.count {
            context.clear(rect)
            context.draw(animation.frames[self.animationFrame], in: rect)
        }
    }

    func draw(text: String, font: CTFont, color: CGColor, width: CGFloat, bold: Bool, italic: Bool, underline: Bool, outline: Bool, shadow: Bool, condense: Bool, extend: Bool, justify: Bool) -> CGImage? {
        if width < 12.0 {
            return nil
        }

        var combinedFont = font
        
        if self.scale > 1.0 {
            combinedFont = CTFontCreateCopyWithAttributes(combinedFont, CTFontGetSize(combinedFont) * scale, nil, nil)
        }
        
        if bold {
            if let substitutedFont = CTFontCreateCopyWithSymbolicTraits(combinedFont, CTFontGetSize(combinedFont), nil, .boldTrait, .boldTrait) {
                combinedFont = substitutedFont
            }
        }

        if italic {
            if let substitutedFont = CTFontCreateCopyWithSymbolicTraits(combinedFont, CTFontGetSize(combinedFont), nil, .italicTrait, .italicTrait) {
                combinedFont = substitutedFont
            }
        }

        if condense {
            if let substitutedFont = CTFontCreateCopyWithSymbolicTraits(combinedFont, CTFontGetSize(combinedFont), nil, .condensedTrait, .condensedTrait) {
                combinedFont = substitutedFont
            }
        }

        if extend {
            if let substitutedFont = CTFontCreateCopyWithSymbolicTraits(combinedFont, CTFontGetSize(combinedFont), nil, .expandedTrait, .condensedTrait) {
                combinedFont = substitutedFont
            }
        }
        
        var attributes: [NSAttributedString.Key : Any] = [
            .font: combinedFont,
            .foregroundColor: NSColor(cgColor: color) as Any
        ]

        if underline {
            attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
            attributes[.underlineColor] = NSColor(cgColor: color) as Any
        }

        if shadow {
            let shadow = NSShadow()
            shadow.shadowColor = NSColor(cgColor: color)
            shadow.shadowOffset = CGSize(width: 4.0, height: 4.0)
            attributes[.shadow] = shadow
        }

        if outline {
            attributes[.foregroundColor] = NSColor.clear as Any
            attributes[.strokeColor] = NSColor(cgColor: color) as Any
        }

        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let stringSize = attributedString.size()
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        if let context = CGContext(data: nil, width: Int(stringSize.width), height: Int(stringSize.height), bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: bitmapInfo.rawValue) {

            let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion

            let ascent = CTFontGetAscent(combinedFont)
            let descent = CTFontGetDescent(combinedFont)
            let baseline = (ascent - descent) / 2
            context.textMatrix = CGAffineTransform(translationX: 0, y: baseline)

            if justify || reduceMotion {
                var stringWidth = attributedString.size().width
                let scaledWidth = width * self.scale

                if stringWidth > scaledWidth {
                    let str = attributedString.string
                    let length = str.count
                    let mid = str.index(str.startIndex, offsetBy: length / 2)
                    var firstHalf = str[..<mid]
                    var secondHalf = str[mid...]

                    while stringWidth > scaledWidth {
                        firstHalf = firstHalf.dropLast()
                        secondHalf = secondHalf.dropFirst()
                        let combined = String(firstHalf + "…" + secondHalf)
                        stringWidth = (combined as NSString).size(withAttributes: attributes).width

                        if stringWidth < scaledWidth {
                            let combinedAttributedString = NSAttributedString(string: combined, attributes: attributes)
                            let line = CTLineCreateWithAttributedString(combinedAttributedString as CFAttributedString)
                            CTLineDraw(line, context)
                        }
                    }
                } else {
                    let line = CTLineCreateWithAttributedString(attributedString as CFAttributedString)
                    CTLineDraw(line, context)
                }
            } else {
                let line = CTLineCreateWithAttributedString(attributedString as CFAttributedString)
                CTLineDraw(line, context)
            }

            return context.makeImage()
        }

        return nil
    }

    func flippedRect(from rect: CGRect) -> CGRect {
        return flippedRect(from: rect, height: CGFloat(self.face?.base.height ?? Int(self.frame.size.height)))
    }

    func flippedRect(from rect: CGRect, height: CGFloat) -> CGRect {
        var rect = CGRect(x: rect.origin.x, y: height - rect.maxY, width: rect.size.width, height: rect.size.height)
        let scale = self.scale
        rect.origin.x *= scale
        rect.origin.y *= scale
        rect.size.width *= scale
        rect.size.height *= scale
        return rect
    }

    private let volumeSlider: AudionSliderWindow
    public var volume: Double = 0.5 {
        didSet {
            self.volumeSlider.doubleValue = self.volume
        }
    }

    @IBAction func adjustVolume(_ sender: Any?) {
        if let sender = sender as? NSSlider {
            self.delegate.volumeChanged(to: sender.doubleValue, sender: self)
        }
    }

    @IBAction func toggleVolume(_ sender: Any?) {
        if let sender = sender as? NSView {
            self.volumeButton?.isEnabled = false
            self.volumeSlider.show(from: sender)
        }
    }

    @IBAction func showInfo(_ sender: Any?) {
        NotificationCenter.default.post(name: NSNotification.Name("ShowInfoPanel"), object: self)
    }

    @IBAction func togglePlaylist(_ sender: Any?) {
        NotificationCenter.default.post(name: NSNotification.Name("TogglePlaylist"), object: self)
    }

    @IBAction func toggleMode(_ sender: Any?) {
        NotificationCenter.default.post(name: NSNotification.Name("ToggleShuffle"), object: self)
    }

    private let timeSlider: AudionSliderWindow
    public var timeInSeconds: Int = 0 {
        didSet {
            self.timeSlider.doubleValue = Double(self.timeInSeconds)
            self.needsDisplay = true
        }
    }

    public var durationInSeconds: Int = 0 {
        didSet {
            self.timeSlider.maxValue = Double(self.durationInSeconds)
        }
    }

    var playingBeforeScrub = false

    @IBAction func adjustTime(_ sender: Any?) {
        if let sender = sender as? NSSlider {
            if self.isPlaying {
                self.playingBeforeScrub = true
                self.delegate.pauseBeforeScrubbing(self)
            }

            self.timeInSeconds = Int(sender.doubleValue)
            self.delegate.playTimeChanged(to: sender.doubleValue, sender: self)
            self.needsDisplay = true

            if let event = NSApp.currentEvent {
                if self.playingBeforeScrub && event.type == .leftMouseUp {
                    self.playingBeforeScrub = false
                    self.delegate.playAfterScrubbing(self)
                }
            }
        }
    }

    public override func mouseDown(with event: NSEvent) {
        if let face = self.face {
            var point = self.convert(event.locationInWindow, from: nil)
            point.y = self.frame.height - point.y
            for digit in [ face.timeDigit1, face.timeDigit2, face.timeDigit3, face.timeDigit4 ] {
                if let digit = digit, digit.rect.contains(point) {
                    self.showTimeSlider(for: digit.rect)
                }
            }
        }
    }

    fileprivate func showTimeSlider(for rect: NSRect) {
        if self.durationInSeconds > 0 {
            let frame = self.convert(self.flippedRect(from: rect), to: nil)
            let minY = frame.origin.y - self.timeSlider.frame.size.height
            self.timeSlider.show(from: self, offset: CGPoint(x: frame.maxX, y: minY))
        }
    }

    public override var isFlipped: Bool {
        get {
            return false
        }
    }

    public override func accessibilityChildren() -> [Any]? {
        var children = super.accessibilityChildren()
        if let element = self.timeDigitsAccessibilityElement {
            children?.append(element)
        }

        return children
    }
}

fileprivate class Button: NSButton, AudionFaceElement {
    fileprivate var normalImage: CGImage
    fileprivate var disabledImage: CGImage?
    fileprivate var pressedImage: CGImage?
    fileprivate var hoverImage: CGImage?

    fileprivate var hovering = false

    fileprivate let unscaledRect: CGRect
    fileprivate var leftConstraint: NSLayoutConstraint?
    fileprivate var topConstraint: NSLayoutConstraint?
    fileprivate var widthConstraint: NSLayoutConstraint?
    fileprivate var heightConstraint: NSLayoutConstraint?

    init(normalImage: CGImage, disabledImage: CGImage?, pressedImage: CGImage?, hoverImage: CGImage?, target: AnyObject?, action: Selector?, frame: CGRect, superview: NSView) {
        self.normalImage = normalImage
        self.disabledImage = disabledImage
        self.hoverImage = hoverImage
        self.pressedImage = pressedImage

        self.unscaledRect = frame

        super.init(frame: frame)
        self.translatesAutoresizingMaskIntoConstraints = false

        superview.addSubview(self)
        self.leftConstraint = self.leftAnchor.constraint(equalTo: superview.leftAnchor, constant: frame.origin.x)
        self.topConstraint = self.topAnchor.constraint(equalTo: superview.topAnchor, constant: frame.origin.y)
        self.widthConstraint = self.widthAnchor.constraint(equalToConstant: frame.size.width)
        self.heightConstraint = self.heightAnchor.constraint(equalToConstant: frame.size.height)

        self.leftConstraint?.isActive = true
        self.topConstraint?.isActive = true
        self.widthConstraint?.isActive = true
        self.heightConstraint?.isActive = true

        self.setButtonType(.momentaryPushIn)
        self.isBordered = false

        self.target = target
        self.action = action

        self.wantsLayer = true
        self.layer?.zPosition = 1
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateTrackingAreas() {
        if self.hoverImage != nil {
            self.addTrackingArea(NSTrackingArea(rect: self.bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: self, userInfo: nil))
        }
    }

    override func mouseEntered(with event: NSEvent) {
        self.hovering = true
        self.needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        self.hovering = false
        self.needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        if let context = NSGraphicsContext.current?.cgContext {
            let quality = context.interpolationQuality
            context.saveGState()
            context.interpolationQuality = .none

            var image: CGImage = self.normalImage

            if self.isEnabled == false {
                if let disabledImage = self.disabledImage {
                    image = disabledImage
                }
            } else {
                if let hoverImage = self.hoverImage, self.hovering {
                    image = hoverImage
                }

                if let pressedImage = self.pressedImage, self.isHighlighted {
                    image = pressedImage
                }
            }

            context.draw(image, in: self.bounds)

            context.interpolationQuality = quality
            context.restoreGState()
        }
    }

    override var isFlipped: Bool {
        get {
            return false
        }
    }
}

@objc fileprivate class TimeDigitsAccessibilityRect: NSAccessibilityElement, NSAccessibilityButton {
    @objc unowned let player: AudionFaceView
    @objc let rect: CGRect

    @objc init(player: AudionFaceView, rect: CGRect) {
        self.player = player
        self.rect = rect
        super.init()
        self.setAccessibilityFrameInParentSpace(rect)
        self.setAccessibilityParent(player)
        self.setAccessibilityElement(true)
    }

    @objc override func accessibilityIdentifier() -> String {
        return "Time Digits"
    }

    @objc override func accessibilityLabel() -> String? {
        let timeInSeconds = self.player.timeInSeconds
        let minutes = timeInSeconds / 60
        let seconds = timeInSeconds % 60

        let firstDigit = minutes / 10
        let secondDigit = minutes % 10
        let thirdDigit = seconds / 10
        let forthDigit = seconds % 10

        return String(firstDigit) + String(secondDigit) + ":" + String(thirdDigit) + String(forthDigit) + " — " + LocalizedString("Show Position Slider")!
    }

    @objc override func accessibilityPerformPress() -> Bool {
        self.player.showTimeSlider(for: rect)
        return true
    }
}

@objc fileprivate class LabelAccessibilityElement: NSAccessibilityElement {
    init(player: AudionFaceView, rect: CGRect, identifier: String, label: String) {
        super.init()
        self.setAccessibilityParent(player)
        self.setAccessibilityIdentifier(identifier)
        self.setAccessibilityFrameInParentSpace(rect)
        self.setAccessibilityLabel(label)
        self.setAccessibilityValue(label)
        self.setAccessibilityRole(.staticText)
        self.setAccessibilityRequired(true)
        self.setAccessibilityElement(true)
    }
}

fileprivate func LocalizedString(_ str: String) -> String? {
    return str
}

fileprivate class TextImageView: NSImageView {
    private let draggable: Bool

    init (draggable: Bool) {
        self.draggable = draggable
        super.init(frame: NSRect.zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var mouseDownCanMoveWindow: Bool {
           get {
            return self.draggable
           }
       }
}

fileprivate class LabelView: NSView {
    private let draggable: Bool
    private let imageView: TextImageView
    private let xor: Bool

    init (draggable: Bool, xor: Bool) {
        self.draggable = draggable
        self.xor = xor
        self.imageView = TextImageView(draggable: draggable)
        super.init(frame: CGRect.zero)
        self.clipsToBounds = true
        self.imageView.clipsToBounds = true
        self.addSubview(self.imageView)
        self.wantsLayer = true
        self.layer?.zPosition = 10

        // Corrent macOS can't XOR with contents below it the same way we could on classic Mac OS.
        // Faces look better with xor disabled.
//        if xor {
//            if let filter = CIFilter(name: "CIColorInvert") {
//                self.layer?.filters = [filter]
//            }
//        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var mouseDownCanMoveWindow: Bool {
        get {
            return self.draggable
        }
    }

    public var image: CGImage? {
        get {
            return self.imageView.image?.cgImage(forProposedRect: nil, context: nil, hints: nil)
        } set {
            if let newValue = newValue {
                self.imageView.image = NSImage(cgImage: newValue, size: NSSize.zero)
                self.imageView.setFrameSize(CGSize(width: CGFloat(newValue.width), height: CGFloat(newValue.height)))
            } else {
                self.imageView.image = nil
            }
        }
    }

    public var justify = false

    public var frameNum: Int = 0 {
        didSet {
            let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion

            if self.justify || reduceMotion {
                self.offset = 0
            } else {
                let rect = self.frame
                let margin: CGFloat = 60.0
                let startup = 80
                let stringWidth = self.imageView.frame.size.width
                let numFrames = Int(stringWidth + rect.size.width + margin)

                let frameNum: Int
                if self.frameNum < startup {
                    frameNum = 0
                } else {
                    frameNum = (((self.frameNum - startup) / 2) % numFrames)
                }

                var offset = -frameNum
                let negativeFrames = Int(stringWidth + margin)
                if offset < Int(-negativeFrames) {
                    offset = Int(rect.size.width - CGFloat(frameNum - negativeFrames))
                }

                self.offset = CGFloat(offset)
            }
        }
    }

    private var offset: CGFloat = 0 {
        didSet {
            self.imageView.setFrameOrigin(NSPoint(x: self.offset, y: 0))
        }
    }

    override var isFlipped: Bool {
        get {
            return true
        }
    }

    public var string: String = "" {
        didSet {
            self.setAccessibilityLabel(self.string)
            self.setAccessibilityValue(self.string)
            self.setAccessibilityElement(true)
            self.setAccessibilityRole(.textField)
        }
    }
}

func resize(image: CGImage, scale: CGFloat) -> CGImage? {
    let width = CGFloat(image.width) * scale
    let height = CGFloat(image.height) * scale
    
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
    guard let context = CGContext(data: nil, width: Int(width), height: Int(height), bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: bitmapInfo.rawValue) else { return nil }
    
    // draw image to context (resizing it)
    context.interpolationQuality = .high
    context.draw(image, in: CGRect(x: 0, y: 0, width: Int(width), height: Int(height)))
    
    // extract resulting image from context
    return context.makeImage()
}
