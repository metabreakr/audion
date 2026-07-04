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
import FaceKit

class ViewController: NSViewController, AudionFaceViewDelegate {

    private var faceView: AudionFaceView? = nil

    override func viewDidLoad() {
        super.viewDidLoad()

        let faceView = AudionFaceView(delegate: self)
        faceView.enableAllButtons = true
        faceView.scale = 1.0
        faceView.face = AudionFace.default
        faceView.volume = 0.5
        faceView.artistText = "A very very very very very very very very long artist field"
        faceView.albumText = "Album Text Field"

        let view = self.view
        view.addSubview(faceView)

        view.topAnchor.constraint(equalTo: faceView.topAnchor).isActive = true;
        view.bottomAnchor.constraint(equalTo: faceView.bottomAnchor).isActive = true;
        view.leftAnchor.constraint(equalTo: faceView.leftAnchor).isActive = true;
        view.rightAnchor.constraint(equalTo: faceView.rightAnchor).isActive = true;

        faceView.durationInSeconds = 120

        self.faceView = faceView
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }

    // MARK: - AudionFaceViewDelegate Methods

    let supportsStop: Bool = true
    let supportsRewind: Bool = false
    let supportsFastForward: Bool = false

    func play(_ sender: AudionFaceView) {
        sender.play()
    }

    func pause(_ sender: AudionFaceView) {
        sender.pause()
    }

    func stop(_ sender: AudionFaceView) {
        sender.stop()
    }

    func rewind(_ sender: AudionFaceView) {}
    func fastForward(_ sender: AudionFaceView) {}
    func volumeChanged(to: Double, sender: AudionFaceView) {}
    func playTimeChanged(to time: Double, sender: AudionFaceView) {}
}

