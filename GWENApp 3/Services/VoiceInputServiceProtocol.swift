import Foundation
import Combine
import AVFoundation // For AVAudioSession
import Speech // For SFSpeechRecognizerAuthorizationStatus

// Define the protocol based on the actual VoiceInputService.swift
protocol VoiceInputServiceProtocol {
    // Published properties
    var isRecording: AnyPublisher<Bool, Never> { get }
    var transcribedText: AnyPublisher<String, Never> { get }
    var isListeningForWakeWord: AnyPublisher<Bool, Never> { get }
    var wakeWordDetected: AnyPublisher<Bool, Never> { get }
    var isListeningForWakeWordValue: Bool { get } // Getter for current state

    // Methods
    func startListeningForWakeWord()
    func stopListeningForWakeWord()

    // This is the more general recording method.
    // UI/ViewModel might decide to call this directly after wake word,
    // or the service itself handles that transition.
    // For now, exposing it if direct control for command recording is needed.
    func startRecording(forWakeWordDetection: Bool)
    func stopRecording()

    func requestPermissions()

    // Expose authorization status if needed by ViewModel to check directly
    // This is not directly in VoiceInputService.swift as a publisher, but can be added or checked via SFSpeechRecognizer.authorizationStatus()
    // For now, keep it simple and rely on requestPermissions() and UI handling.
    // var authorizationStatus: AnyPublisher<SFSpeechRecognizerAuthorizationStatus, Never> { get }
}

// Make the actual VoiceInputService conform to this protocol.
// This will require changes in VoiceInputService.swift to expose publishers as AnyPublisher.
extension VoiceInputService: VoiceInputServiceProtocol {
    var isRecording: AnyPublisher<Bool, Never> {
        $isRecording.eraseToAnyPublisher()
    }

    var transcribedText: AnyPublisher<String, Never> {
        $transcribedText.eraseToAnyPublisher()
    }

    var isListeningForWakeWord: AnyPublisher<Bool, Never> {
        $isListeningForWakeWord.eraseToAnyPublisher()
    }

    var wakeWordDetected: AnyPublisher<Bool, Never> {
        $wakeWordDetected.eraseToAnyPublisher()
    }
    // Implementation of the getter will be in VoiceInputService.swift
}
