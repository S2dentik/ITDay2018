//
//  ViewController.swift
//  ITDay2018
//
//  Created by Alexandru Culeva on 9/8/18.
//  Copyright © 2018 S2dent. All rights reserved.
//

import UIKit
import SpriteKit
import ARKit
import Vision

final class Atomic<T> {

    private var queue = DispatchQueue(label: "com.aculeva.itday2018.\(Date().timeIntervalSince1970)")
    private var _value: T
    var value: T {
        get {
            return queue.sync { _value }
        } set {
            queue.sync { [ weak self] in self?._value = newValue }
        }
    }

    init(value: T) {
        self._value = value
    }
}

class ViewController: UIViewController {

    @IBOutlet var micButton: UIButton!
    @IBOutlet var sceneView: ARSKView!
    var faceRectangleLayer: CAShapeLayer!
    var textLayer: CALayer?

    let visionQueue = DispatchQueue(label: "com.aculeva.itday2018.serialVisionQueue")
    private var detectionRequests = Atomic(value: [VNDetectFaceRectanglesRequest]())
    private var trackingRequests = Atomic(value: [VNTrackObjectRequest]())
    lazy var sequenceRequestHandler = VNSequenceRequestHandler()

    private var currentText = ""
    var englishSpeechRecognizer: SpeechRecognizer!

    override func viewDidLoad() {
        super.viewDidLoad()

        englishSpeechRecognizer = SpeechRecognizer(localeIdentifier: "en--US",
                                                   onRecognized: { [weak self] in self?.currentText = $0 })

        englishSpeechRecognizer.requestAuthorizationIfNeeded()

        let overlayScene = SKScene()
        overlayScene.scaleMode = .aspectFill
        sceneView.delegate = self
        sceneView.presentScene(overlayScene)
        sceneView.session.delegate = self

        prepareVisionRequest()
        setupFaceRectangleLayer()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()

        // Run the view's session
        sceneView.session.run(configuration)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        sceneView.session.pause()
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

    private func setupFaceRectangleLayer() {
        let faceRectangleShapeLayer = CAShapeLayer()
        faceRectangleShapeLayer.name = "RectangleOutlineLayer"
        faceRectangleShapeLayer.bounds = sceneView.bounds
        faceRectangleShapeLayer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        faceRectangleShapeLayer.position = sceneView.center
        faceRectangleShapeLayer.fillColor = nil
        faceRectangleShapeLayer.strokeColor = UIColor.white.withAlphaComponent(0.7).cgColor
        faceRectangleShapeLayer.lineWidth = 5
        faceRectangleShapeLayer.shadowOpacity = 0.7
        faceRectangleShapeLayer.shadowRadius = 5

        self.faceRectangleLayer = faceRectangleShapeLayer
        self.sceneView.layer.addSublayer(faceRectangleShapeLayer)
    }

    private func drawFaceObservations(_ observations: [VNDetectedObjectObservation]) {
        guard let observation = observations.first else { return }
        CATransaction.begin()

        CATransaction.setValue(NSNumber(value: true), forKey: kCATransactionDisableActions)

        let path = CGMutablePath()

        let transform = CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: 0, y: -sceneView.frame.height)
        let translate = CGAffineTransform.identity.scaledBy(x: sceneView.frame.width, y: sceneView.frame.height)
        let rect = observation.boundingBox.applying(translate).applying(transform)

        let smallEllipseRect = CGRect(x: rect.origin.x,
                                      y: rect.origin.y - rect.height / 8,
                                      width: rect.width / 8,
                                      height: rect.width / 8)
        path.addEllipse(in: smallEllipseRect)

        let mediumEllipseRect = CGRect(x: smallEllipseRect.origin.x - rect.width / 5,
                                       y: smallEllipseRect.origin.y - rect.height / 5 - 20,
                                       width: rect.width / 5,
                                       height: rect.width / 5)
        path.addEllipse(in: mediumEllipseRect)

        let bigWidth = sceneView.bounds.width - 40
        let bigHeight = bigWidth * 0.66
        let bigOriginX = sceneView.frame.minX + 20
        let bigEllipseRect = CGRect(x: bigOriginX,
                                    y: mediumEllipseRect.origin.y - bigHeight - 20,
                                    width: bigWidth,
                                    height: bigHeight)
        path.addEllipse(in: bigEllipseRect)

        // Add text label
        let label = UILabel(frame: bigEllipseRect)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.textColor = .white
        label.font = .systemFont(ofSize: 18)
        label.adjustsFontSizeToFitWidth = true
        label.text = currentText

        textLayer?.removeFromSuperlayer()
        textLayer = label.layer
        textLayer.map(faceRectangleLayer.addSublayer)

        faceRectangleLayer.path = path

        CATransaction.commit()
    }

    private func prepareVisionRequest() {

        self.trackingRequests.value = []
        var requests = [VNTrackObjectRequest]()

        let faceDetectionRequest = VNDetectFaceRectanglesRequest(completionHandler: { (request, error) in

            if error != nil {
                print("FaceDetection error: \(String(describing: error)).")
            }

            guard let faceDetectionRequest = request as? VNDetectFaceRectanglesRequest,
                let results = faceDetectionRequest.results as? [VNFaceObservation] else {
                    return
            }
            if results.isEmpty { return }
            // Add the observations to the tracking list
            for observation in results {
                print("started tracking face")
                let faceTrackingRequest = VNTrackObjectRequest(detectedObjectObservation: observation)
                requests.append(faceTrackingRequest)
            }
            self.trackingRequests.value = requests
        })

        // Start with detection.  Find face, then track it.
        self.detectionRequests.value = [faceDetectionRequest]

        self.sequenceRequestHandler = VNSequenceRequestHandler()
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

extension ViewController: ARSKViewDelegate {

}

extension ViewController: ARSessionDelegate {
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        visionQueue.async {
            let requests = self.trackingRequests.value
            if requests.isEmpty {
                // No tracking object detected, so perform initial detection
                let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: frame.capturedImage,
                                                                orientation: .right)

                do {
                    try imageRequestHandler.perform(self.detectionRequests.value)
                } catch let error as NSError {
                    NSLog("Failed to perform FaceRectangleRequest: %@", error)
                }
                return
            }

            do {
                let buffer = frame.capturedImage
                try self.sequenceRequestHandler.perform(requests,
                                                        on: buffer,
                                                        orientation: .right)
            } catch let error as NSError {
                NSLog("Failed to perform SequenceRequest: %@", error)
            }

            // Setup the next round of tracking.
            var newTrackingRequests = [VNTrackObjectRequest]()
            var observations = [VNDetectedObjectObservation]()
            for trackingRequest in requests {
                guard let results = trackingRequest.results as? [VNDetectedObjectObservation],
                    let observation = results.first else {
                        return
                }
                if !trackingRequest.isLastFrame {
                    if observation.confidence > 0.3 {
                        observations.append(observation)
                        trackingRequest.inputObservation = observation
                    } else {
                        trackingRequest.isLastFrame = true
                    }
                    newTrackingRequests.append(trackingRequest)
                } else {
                    print("finished tracking face")
                }
            }
            DispatchQueue.main.async {
                self.drawFaceObservations(observations)
            }
            self.trackingRequests.value = newTrackingRequests
        }
    }
}
