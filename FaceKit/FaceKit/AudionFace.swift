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

public extension CodingUserInfoKey {
    static let audionFacePath = CodingUserInfoKey(rawValue: "decodingContext")!
}

public struct AudionFace {
    let base: CGImage
    let mask: CGImage?
    let inactiveMask: CGImage?

    let artistFont: CTFont
    let albumFont: CTFont

    let artistDisplayRect: CGRect?
    let albumDisplayRect: CGRect?

    let artistColor: CGColor
    let albumColor: CGColor

    let artistStyle: TextStyle
    let albumStyle: TextStyle

    let artistXor: Bool
    let albumXor: Bool

    let playButton: Button?
    let pauseButton: Button?
    let stopButton: Button?
    let rewindButton: Button?
    let fastForwardButton: Button?

    let playIndicator: Indicator?
    let pauseIndicator: Indicator?
    let netIndicator: Indicator?
    let MP3Indicator: Indicator?
    let CDIndicator: Indicator?
    let CDDBIndicator: Indicator?

    let closeButton: Button?
    let infoButton: Button?
    let volumeButton: Button?
    let playlistButton: Button?
    let modeButton: Button?
    let ejectButton: Button?

    let trackDigit1: Digit?
    let trackDigit2: Digit?

    let timeDigit1: Digit?
    let timeDigit2: Digit?
    let timeDigit3: Digit?
    let timeDigit4: Digit?

    public let connectingAnim: Animation?
    public let streamingAnim: Animation?
    public let netLagAnim: Animation?

    public static var `default`: AudionFace {
        get {
            do {
                return try AudionFace.load(path: Bundle.init(identifier: "com.panic.FaceKit")!.url(forResource: "Smoothface 2", withExtension: nil)!)
            } catch {
                fatalError()
            }
        }
    }

    public static func load(path: URL) throws -> AudionFace {
        let decoder = JSONDecoder()
        decoder.userInfo[CodingUserInfoKey.audionFacePath] = path

        let indexJSONURL = path.appendingPathComponent("index.json")

        if !FileManager.default.fileExists(atPath: indexJSONURL.path) {
            throw AudionFaceError.MissingIndexJSON
        }

        let data = try Data(contentsOf: indexJSONURL)

        return try decoder.decode(AudionFace.self, from: data)
    }

    struct TextStyle: OptionSet {
        public let rawValue: Int
        static let bold = TextStyle(rawValue: 1 << 0)
        static let italic = TextStyle(rawValue: 1 << 1)
        static let underline = TextStyle(rawValue: 1 << 2)
        static let outline = TextStyle(rawValue: 1 << 3)
        static let shadow = TextStyle(rawValue: 1 << 4)
        static let condense = TextStyle(rawValue: 1 << 5)
        static let extend = TextStyle(rawValue: 1 << 6)
        static let justify = TextStyle(rawValue: 1 << 7)
    }

    public struct Animation {
        public let rect: CGRect
        public let frames: [CGImage]
        public let frameDelay: Int
    }

    public struct Button {
        public let image: CGImage
        public let disabledImage: CGImage?
        public let pressedImage: CGImage?
        public let hoverImage: CGImage?
        public let rect: CGRect
    }

    public struct Indicator {
        public let image: CGImage
        public let onImage: CGImage
        public let rect: CGRect
    }

    public struct Digit {
        public let numPICTs: Int
        public let images: [CGImage]
        public let rect: CGRect
    }
}

// MARK: - Deocding

public enum AudionFaceError: Error {
    case MissingPathInUserInfo
    case MissingIndexJSON
    case MissingBaseImage
    case MissingMask
}

extension AudionFace: Decodable {
    fileprivate enum CodingKeys: String, CodingKey {
        case artistDisplayFontName
        case artistFontSize
        case albumDisplayFontName
        case albumFontSize

        case albumDisplayRect
        case artistDisplayRect

        case artistDisplayTextFaceColorFromFace
        case artistDisplayTextFaceColorFromTxtr
        case artistTextMode
        case albumDisplayTextFaceColorFromFace
        case albumDisplayTextFaceColorFromTxtr
        case albumTextMode

        case artistBold
        case artistItalic
        case artistUnderline
        case artistOutline
        case artistShadow
        case artistCondense
        case artistExtend
        case artistJustify

        case albumBold
        case albumItalic
        case albumUnderline
        case albumOutline
        case albumShadow
        case albumCondense
        case albumExtend
        case albumJustify

        case playButtonRect
        case stopButtonRect
        case rewindButtonRect
        case fastForwardButtonRect

        case playIndicatorRect
        case pauseIndicatorRect
        case netIndicatorRect
        case MP3IndicatorRect
        case CDIndicatorRect
        case CDDBIndicatorRect

        case closeButtonRect
        case infoButtonRect
        case volumeButtonRect
        case playlistButtonRect
        case modeButtonRect
        case ejectButtonRect

        case trackDigit1Rect
        case trackDigit1FirstPICTID
        case trackDigit2Rect
        case trackDigit2FirstPICTID

        case timeDigit1Rect
        case timeDigit1FirstPICTID
        case timeDigit2Rect
        case timeDigit2FirstPICTID
        case timeDigit3Rect
        case timeDigit3FirstPICTID
        case timeDigit4Rect
        case timeDigit4FirstPICTID

        case connectingAnimRect
        case connectingFrameDelay
        case connectingFirstPICTID
        case connectingNumPICTs

        case streamingAnimRect
        case streamingFrameDelay
        case streamingFirstPICTID
        case streamingNumPICTs

        case netLagAnimRect
        case netLagFrameDelay
        case netLagFirstPICTID
        case netLagNumPICTs
    }

    public init(from decoder: Decoder) throws {
        if let path = decoder.userInfo[CodingUserInfoKey.audionFacePath] as? URL {
            let indexJSONURL = path.appendingPathComponent("index.json")

            if !FileManager.default.fileExists(atPath: indexJSONURL.path) {
                throw AudionFaceError.MissingIndexJSON
            }

            if let base = loadImage(at: path.appendingPathComponent("base.png")) {
                self.base = base
            } else {
                throw AudionFaceError.MissingBaseImage
            }

            if let mask = loadImage(at: path.appendingPathComponent("base-alpha.png")) {
                self.mask = mask
            } else {
                self.mask = nil
            }

            if let inactiveMask = loadImage(at: path.appendingPathComponent("inactive-alpha.png")) {
                self.inactiveMask = inactiveMask
            } else {
                self.inactiveMask = nil
            }

            let values = try decoder.container(keyedBy: CodingKeys.self)

            self.artistFont = decodeFont(container: values, fontNameKey: .artistDisplayFontName, fontSizeKey: .artistFontSize)
            self.albumFont = decodeFont(container: values, fontNameKey: .albumDisplayFontName, fontSizeKey: .albumFontSize)

            self.artistColor = decodeColor(container: values, faceKey: .artistDisplayTextFaceColorFromFace, txtrKey: .artistDisplayTextFaceColorFromTxtr)

            self.albumColor = decodeColor(container: values, faceKey: .albumDisplayTextFaceColorFromFace, txtrKey: .albumDisplayTextFaceColorFromTxtr)

            self.albumDisplayRect = decodeRect(container: values, key: .albumDisplayRect)
            self.artistDisplayRect = decodeRect(container: values, key: .artistDisplayRect)

            self.artistStyle = decodeStyle(container: values, boldKey: .artistBold, italicKey: .artistItalic, underlineKey: .artistUnderline, outlineKey: .artistOutline, shadowKey: .artistShadow, condenseKey: .artistCondense, extendKey: .artistExtend, justifyKey: .artistJustify)

            self.albumStyle = decodeStyle(container: values, boldKey: .albumBold, italicKey: .albumItalic, underlineKey: .albumUnderline, outlineKey: .albumOutline, shadowKey: .albumShadow, condenseKey: .albumCondense, extendKey: .albumExtend, justifyKey: .albumJustify)

            self.artistXor = try (values.decode(Int.self, forKey: .artistTextMode) & 2) != 0
            self.albumXor = try (values.decode(Int.self, forKey: .albumTextMode) & 2) != 0

            self.playButton = decodeButton(path: path, base: "play", container: values, rectKey: .playButtonRect)
            self.pauseButton = decodeButton(path: path, base: "pause", container: values, rectKey: .playButtonRect)
            self.stopButton = decodeButton(path: path, base: "stop", container: values, rectKey: .stopButtonRect)
            self.rewindButton = decodeButton(path: path, base: "rw", container: values, rectKey: .rewindButtonRect)
            self.fastForwardButton = decodeButton(path: path, base: "ff", container: values, rectKey: .fastForwardButtonRect)

            self.playIndicator = decodeIndicator(path: path, base: "play-indicator", container: values, rectKey: .playIndicatorRect)
            self.pauseIndicator = decodeIndicator(path: path, base: "pause-indicator", container: values, rectKey: .pauseIndicatorRect)
            self.netIndicator = decodeIndicator(path: path, base: "net", container: values, rectKey: .netIndicatorRect)
            self.MP3Indicator = decodeIndicator(path: path, base: "mp3", container: values, rectKey: .MP3IndicatorRect)
            self.CDIndicator = decodeIndicator(path: path, base: "cd", container: values, rectKey: .CDIndicatorRect)
            self.CDDBIndicator = decodeIndicator(path: path, base: "cddb", container: values, rectKey: .CDDBIndicatorRect)

            self.closeButton = decodeButton(path: path, base: "close", container: values, rectKey: .closeButtonRect)
            self.infoButton = decodeButton(path: path, base: "info", container: values, rectKey: .infoButtonRect)
            self.volumeButton = decodeButton(path: path, base: "volume", container: values, rectKey: .volumeButtonRect)
            self.playlistButton = decodeButton(path: path, base: "menu", container: values, rectKey: .playlistButtonRect)
            self.modeButton = decodeButton(path: path, base: "music", container: values, rectKey: .modeButtonRect)
            self.ejectButton = decodeButton(path: path, base: "eject", container: values, rectKey: .ejectButtonRect)

            self.trackDigit1 = try decodeDigit(path: path, container: values, rectKey: .trackDigit1Rect, startPICTKey: .trackDigit1FirstPICTID, numPICTs: 11, base: self.base)
            self.trackDigit2 = try decodeDigit(path: path, container: values, rectKey: .trackDigit2Rect, startPICTKey: .trackDigit2FirstPICTID, numPICTs: 11, base: self.base)

            self.timeDigit1 = try decodeDigit(path: path, container: values, rectKey: .timeDigit1Rect, startPICTKey: .timeDigit1FirstPICTID, numPICTs: 10, base: self.base)
            self.timeDigit2 = try decodeDigit(path: path, container: values, rectKey: .timeDigit2Rect, startPICTKey: .timeDigit2FirstPICTID, numPICTs: 10, base: self.base)
            self.timeDigit3 = try decodeDigit(path: path, container: values, rectKey: .timeDigit3Rect, startPICTKey: .timeDigit3FirstPICTID, numPICTs: 10, base: self.base)
            self.timeDigit4 = try decodeDigit(path: path, container: values, rectKey: .timeDigit4Rect, startPICTKey: .timeDigit4FirstPICTID, numPICTs: 10, base: self.base)

            self.connectingAnim = decodeAnimation(path: path, container: values, rectKey: .connectingAnimRect, delayKey: .connectingFrameDelay, numFramesKey: .connectingNumPICTs, firstPICTKey: .connectingFirstPICTID)

            self.streamingAnim = decodeAnimation(path: path, container: values, rectKey: .streamingAnimRect, delayKey: .streamingFrameDelay, numFramesKey: .streamingNumPICTs, firstPICTKey: .streamingFirstPICTID)

            self.netLagAnim = decodeAnimation(path: path, container: values, rectKey: .netLagAnimRect, delayKey: .netLagFrameDelay, numFramesKey: .netLagNumPICTs, firstPICTKey: .netLagFirstPICTID)
        } else {
            throw AudionFaceError.MissingPathInUserInfo
        }
    }
}

fileprivate func decodeFont<A: CodingKey>(container: KeyedDecodingContainer<A>, fontNameKey: A, fontSizeKey: A) -> CTFont {
    do {
        let fontName = try container.decode(String.self, forKey: fontNameKey)
        let fontSize = try container.decode(Int.self, forKey: fontSizeKey)

        #if os(macOS)
        return NSFont(name: fontName, size: CGFloat(fontSize)) ?? NSFont(name: "Helvetica", size: CGFloat(fontSize))!
        #else
        #endif
    } catch {
        #if os(macOS)
        return NSFont(name: "Helvetica", size: 12.0)!
        #else
        #endif
    }
}

fileprivate enum RectKeys: String, CodingKey {
    case top
    case bottom
    case left
    case right
}

fileprivate func decodeRect<A: CodingKey>(container: KeyedDecodingContainer<A>, key: A, image: CGImage? = nil) -> CGRect? {
    do {
        let nestedContainer = try container.nestedContainer(keyedBy: RectKeys.self, forKey: key)
        let top = try nestedContainer.decode(Int.self, forKey: .top)
        let left = try nestedContainer.decode(Int.self, forKey: .left)

        let rect: CGRect
        if let image = image {
            rect = CGRect(x: CGFloat(left), y: CGFloat(top), width: CGFloat(image.width), height: CGFloat(image.height))
        } else {
            let bottom = try nestedContainer.decode(Int.self, forKey: .bottom)
            let right = try nestedContainer.decode(Int.self, forKey: .right)
            rect = CGRect(x: CGFloat(left), y: CGFloat(top), width: CGFloat(right - left), height: CGFloat(bottom - top))
        }

        if rect.size.width == 0 || rect.size.height == 0 {
            return nil
        }

        return rect
    } catch {
        return nil
    }
}

fileprivate enum ColorKeys: String, CodingKey {
    case red
    case green
    case blue
}

fileprivate func decodeColor<A: CodingKey>(container: KeyedDecodingContainer<A>, faceKey: A, txtrKey: A) -> CGColor {
    var red: CGFloat = 0.0
    var green: CGFloat = 0.0
    var blue: CGFloat = 0.0
    var usedTxtr = false

    do {
        let txtr = try container.nestedContainer(keyedBy: ColorKeys.self, forKey: txtrKey)
        red = CGFloat(try txtr.decode(Int.self, forKey: .red)) / 255.0
        green = CGFloat(try txtr.decode(Int.self, forKey: .green)) / 255.0
        blue = CGFloat(try txtr.decode(Int.self, forKey: .blue)) / 255.0
        usedTxtr = true
    } catch {
        red = 0.0
        green = 0.0
        blue = 0.0
    }

    if !usedTxtr {
        do {
            let face = try container.nestedContainer(keyedBy: ColorKeys.self, forKey: faceKey)
            red = CGFloat(try face.decode(Int.self, forKey: .red)) / 255.0
            green = CGFloat(try face.decode(Int.self, forKey: .green)) / 255.0
            blue = CGFloat(try face.decode(Int.self, forKey: .blue)) / 255.0
        } catch {
            red = 0.0
            green = 0.0
            blue = 0.0
        }
    }

    return CGColor(red: red, green: green, blue: blue, alpha: 1.0)
}

fileprivate func loadImage(at url: URL) -> CGImage? {
    #if os(macOS)
    return NSImage(contentsOf:url)?.cgImage(forProposedRect: nil, context: nil, hints: nil)
    #else
    #endif
}

fileprivate func decodeButton<A: CodingKey>(path: URL, base: String, container: KeyedDecodingContainer<A>, rectKey: A) -> AudionFace.Button? {
    let imageURL = path.appendingPathComponent(base + ".png")
    if let image = loadImage(at: imageURL), let rect = decodeRect(container: container, key: rectKey, image: image) {
        let disabledURL = path.appendingPathComponent(base + "-disabled.png")
        let pressedURL = path.appendingPathComponent(base + "-active.png")
        let hoverURL = path.appendingPathComponent(base + "-hover.png")

        return AudionFace.Button(image: image, disabledImage: loadImage(at: disabledURL), pressedImage: loadImage(at: pressedURL), hoverImage: loadImage(at: hoverURL), rect: rect)
    } else {
        return nil
    }
}

fileprivate func decodeIndicator<A: CodingKey>(path: URL, base: String, container: KeyedDecodingContainer<A>, rectKey: A) -> AudionFace.Indicator? {
    let imageURL = path.appendingPathComponent(base + ".png")
    let onURL = path.appendingPathComponent(base + "-on.png")
    if let image = loadImage(at: imageURL), let onImage = loadImage(at: onURL), let rect = decodeRect(container: container, key: rectKey) {
        return AudionFace.Indicator(image: image, onImage: onImage, rect: rect)
    } else {
        return nil
    }
}

fileprivate func decodeAnimation<A: CodingKey>(path: URL, container: KeyedDecodingContainer<A>, rectKey: A, delayKey: A, numFramesKey: A, firstPICTKey: A) -> AudionFace.Animation? {
    do {
        let rect = decodeRect(container: container, key: rectKey)

        if rect == nil {
            return nil
        }

        let frameDelay = try container.decode(Int.self, forKey: delayKey)
        let numFrames = try container.decode(Int.self, forKey: numFramesKey)
        let firstPICT = try container.decode(Int.self, forKey: firstPICTKey)
        var frames: [CGImage] = []

        for frameNum in 0..<numFrames {
            let frameURL = path.appendingPathComponent(String(firstPICT + frameNum) + ".png")
            
            if let frame = loadImage(at: frameURL) {
                frames.append(frame)
            } else {
                return nil
            }
        }

        return AudionFace.Animation(rect: rect!, frames: frames, frameDelay: frameDelay)
    } catch {
        return nil
    }
}

fileprivate func decodeDigit<A: CodingKey>(path: URL, container: KeyedDecodingContainer<A>, rectKey: A, startPICTKey: A, numPICTs: Int, base: CGImage) throws -> AudionFace.Digit? {
    if let rect = decodeRect(container: container, key: rectKey) {
        let firstPICT = try container.decode(Int.self, forKey: startPICTKey)
        var images: [CGImage] = []
        for pictNum in 0..<numPICTs {
            let imageURL = path.appendingPathComponent(String(pictNum + firstPICT) + ".png")
            if let image = loadImage(at: imageURL) {
                images.append(image)
            } else {
                return nil
            }
        }

        return AudionFace.Digit(numPICTs: numPICTs, images: images, rect: rect)
    } else {
        return nil
    }
}

func decodeStyle<A: CodingKey>(container: KeyedDecodingContainer<A>, boldKey: A, italicKey: A, underlineKey: A, outlineKey: A, shadowKey: A, condenseKey: A, extendKey: A, justifyKey: A) -> AudionFace.TextStyle {
    var style: AudionFace.TextStyle = []

    do {
        if try container.decode(Bool.self, forKey: boldKey) {
            style = style.union(.bold)
        }
        if try container.decode(Bool.self, forKey: italicKey) {
            style = style.union(.italic)
        }
        if try container.decode(Bool.self, forKey: underlineKey) {
            style = style.union(.underline)
        }
        if try container.decode(Bool.self, forKey: outlineKey) {
            style = style.union(.outline)
        }
        if try container.decode(Bool.self, forKey: shadowKey) {
            style = style.union(.shadow)
        }
        if try container.decode(Bool.self, forKey: condenseKey) {
            style = style.union(.condense)
        }
        if try container.decode(Bool.self, forKey: extendKey) {
            style = style.union(.extend)
        }
        if try container.decode(Bool.self, forKey: justifyKey) {
            style = style.union(.justify)
        }
    } catch {
        return []
    }

    return style
}
