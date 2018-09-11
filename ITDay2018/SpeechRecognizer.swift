import Speech
import AVFoundation

protocol SpeechReocgnizerDelegate {
    func didRecognize(_ string: String)
}

final class SpeechRecognizer {

    private let speechRecognizer: SFSpeechRecognizer
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    private var onRecognized: ((String) -> Void)?

    var isRunning: Bool {
        return audioEngine.isRunning
    }

    init(localeIdentifier: String = "en-US", onRecognized: @escaping (String) -> Void = { _ in }) {
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier))!
        self.onRecognized = onRecognized
    }

    func start() throws {
        requestAuthorizationIfNeeded()
        // Cancel the previous task if it's running.
        if let recognitionTask = recognitionTask {
            recognitionTask.cancel()
            self.recognitionTask = nil
        }

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(AVAudioSessionCategoryRecord)
        try audioSession.setMode(AVAudioSessionModeMeasurement)
        try audioSession.setActive(true, with: .notifyOthersOnDeactivation)

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()

        let inputNode = audioEngine.inputNode
        guard let recognitionRequest = recognitionRequest else {
            fatalError("Unable to create a SFSpeechAudioBufferRecognitionRequest object")
        }

        // Configure request so that results are returned before audio recording is finished
        recognitionRequest.shouldReportPartialResults = true

        // A recognition task represents a speech recognition session.
        // We keep a reference to the task so that it can be cancelled.
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
            var isFinal = false

            if let result = result {
                isFinal = result.isFinal
                self.onRecognized?(result.bestTranscription.formattedString)
            } else if let error = error {
                print(error.localizedDescription)
            }

            if error != nil || isFinal {
                self.stop()
                inputNode.removeTap(onBus: 0)
                self.recognitionRequest = nil
                self.recognitionTask = nil
            }
        }

        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 8192, format: recordingFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
            self.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()

        try audioEngine.start()
    }

    func stop() {
        audioEngine.stop()
        recognitionRequest?.endAudio()
    }

    func requestAuthorizationIfNeeded() {
        if SFSpeechRecognizer.authorizationStatus() == .authorized { return }
        SFSpeechRecognizer.requestAuthorization { _ in }
    }
}
