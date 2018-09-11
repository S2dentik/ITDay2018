//
//  ViewController.swift
//  ITDay2018
//
//  Created by Alexandru Culeva on 9/8/18.
//  Copyright © 2018 S2dent. All rights reserved.
//

import UIKit
import Speech
import AVFoundation

class ViewController: UIViewController {

    @IBOutlet var micButton: UIButton!
    @IBOutlet var textLabel: UILabel!

    var englishSpeechRecognizer: SpeechRecognizer!

    override func viewDidLoad() {
        super.viewDidLoad()

        englishSpeechRecognizer = SpeechRecognizer(localeIdentifier: "en-US",
                                                   onRecognized: { self.textLabel.text = $0 })

        englishSpeechRecognizer.requestAuthorizationIfNeeded()
        textLabel.text = nil
    }

    @IBAction func toggleRecognizing(_ sender: UIButton) {
        if englishSpeechRecognizer.isRunning {
            stopShaking()
            englishSpeechRecognizer.stop()
        } else {
            startShaking()
            try! englishSpeechRecognizer.start()
        }
    }

    private func startShaking() {
        let animation = CABasicAnimation(keyPath: "transform.rotation.z")
        animation.duration = 0.1
        animation.autoreverses = true
        animation.repeatCount = 1_000_000
        animation.fromValue = Double.pi / 9
        animation.toValue = -Double.pi / 9
        micButton.layer.add(animation, forKey: "transform.rotation")
    }

    private func stopShaking() {
        micButton.layer.removeAnimation(forKey: "transform.rotation")
    }
}

