import Combine

protocol VoiceInputServiceProtocol: AnyObject {
    var transcribedTextPublisher: AnyPublisher<String, Never> { get }
    var isRecordingPublisher: AnyPublisher<Bool, Never> { get }
    var wakeWordDetectedPublisher: AnyPublisher<Bool, Never> { get }
    var isListeningForWakeWord: Bool { get }

    func requestPermissions()
    func startListening()
    func stopListening()
    func startWakeWordDetection()
    func stopWakeWordDetection()
}

