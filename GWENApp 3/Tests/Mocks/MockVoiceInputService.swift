import Foundation
import Combine
import AVFoundation
import Speech
@testable import GWENApp_3 // Replace GWENApp_3 with your actual app module name

class MockVoiceInputService: VoiceInputServiceProtocol {
    // MARK: - Published Property Mocking
    private let _isRecording = CurrentValueSubject<Bool, Never>(false)
    var isRecording: AnyPublisher<Bool, Never> { _isRecording.eraseToAnyPublisher() }

    private let _transcribedText = CurrentValueSubject<String, Never>("")
    var transcribedText: AnyPublisher<String, Never> { _transcribedText.eraseToAnyPublisher() }

    private let _isListeningForWakeWord = CurrentValueSubject<Bool, Never>(false)
    var isListeningForWakeWord: AnyPublisher<Bool, Never> { _isListeningForWakeWord.eraseToAnyPublisher() }

    private let _wakeWordDetected = CurrentValueSubject<Bool, Never>(false)
    var wakeWordDetected: AnyPublisher<Bool, Never> { _wakeWordDetected.eraseToAnyPublisher() }

    // MARK: - Current Value Getter Mocking
    var isListeningForWakeWordValue: Bool = false {
        didSet { _isListeningForWakeWord.send(isListeningForWakeWordValue) }
    }

    // MARK: - Call Tracking
    var startListeningForWakeWordCalled = false
    var stopListeningForWakeWordCalled = false
    var startRecordingCalled = false
    var lastStartRecordingForWakeWordDetectionParam: Bool?
    var stopRecordingCalled = false
    var requestPermissionsCalled = false

    func reset() {
        startListeningForWakeWordCalled = false
        stopListeningForWakeWordCalled = false
        startRecordingCalled = false
        lastStartRecordingForWakeWordDetectionParam = nil
        stopRecordingCalled = false
        requestPermissionsCalled = false

        _isRecording.send(false)
        _transcribedText.send("")
        _isListeningForWakeWord.send(false)
        isListeningForWakeWordValue = false
        _wakeWordDetected.send(false)
    }

    // MARK: - Protocol Implementation
    func startListeningForWakeWord() {
        startListeningForWakeWordCalled = true
        isListeningForWakeWordValue = true
        _isRecording.send(true) // Typically wake word listening involves recording
    }

    func stopListeningForWakeWord() {
        stopListeningForWakeWordCalled = true
        isListeningForWakeWordValue = false
        _isRecording.send(false) // Stop recording when wake word listening stops
    }

    func startRecording(forWakeWordDetection: Bool) {
        startRecordingCalled = true
        lastStartRecordingForWakeWordDetectionParam = forWakeWordDetection
        _isRecording.send(true)
        if !forWakeWordDetection {
            _transcribedText.send("") // Clear text when starting command recording
        }
    }

    func stopRecording() {
        stopRecordingCalled = true
        _isRecording.send(false)
    }

    func requestPermissions() {
        requestPermissionsCalled = true
        // Simulate permission grant for tests if needed
        // SFSpeechRecognizer.requestAuthorization { _ in }
        // AVAudioSession.sharedInstance().requestRecordPermission { _ in }
    }

    // MARK: - Helper methods to manually push values for testing
    func setIsRecording(to value: Bool) {
        _isRecording.send(value)
    }

    func setTranscribedText(to text: String) {
        _transcribedText.send(text)
    }

    func setWakeWordDetected(to value: Bool) {
        _wakeWordDetected.send(value)
    }
}
