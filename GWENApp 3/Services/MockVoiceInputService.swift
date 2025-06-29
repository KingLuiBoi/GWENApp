import Foundation
import Combine

class MockVoiceInputService: VoiceInputServiceProtocol {

    // MARK: - Published Properties
    @Published var isRecording: Bool = false
    @Published var transcribedText: String = ""
    @Published var isListeningForWakeWord: Bool = false
    @Published var wakeWordDetected: Bool = false

    // MARK: - Publishers
    var isRecordingPublisher: AnyPublisher<Bool, Never> {
        $isRecording.eraseToAnyPublisher()
    }

    var transcribedTextPublisher: AnyPublisher<String, Never> {
        $transcribedText.eraseToAnyPublisher()
    }

    var wakeWordDetectedPublisher: AnyPublisher<Bool, Never> {
        $wakeWordDetected.eraseToAnyPublisher()
    }

    // You don't need this if your protocol doesn't require it, but some versions of your code had it.
    var isListeningForWakeWordPublisher: AnyPublisher<Bool, Never> {
        $isListeningForWakeWord.eraseToAnyPublisher()
    }

    // MARK: - Protocol Conformance
    func requestPermissions() {
        print("[Mock] Permissions granted automatically.")
    }

    func startListening() {
        isRecording = true
        print("[Mock] startListening() called")
    }

    func stopListening() {
        isRecording = false
        print("[Mock] stopListening() called")
    }

    func startWakeWordDetection() {
        isListeningForWakeWord = true
        print("[Mock] startWakeWordDetection() called")
    }

    func stopWakeWordDetection() {
        isListeningForWakeWord = false
        print("[Mock] stopWakeWordDetection() called")
    }
}


