import Foundation
import Combine
import AVFoundation
import Speech

class VoiceInputService: NSObject, ObservableObject, VoiceInputServiceProtocol { // Added VoiceInputServiceProtocol
    static let shared = VoiceInputService()
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    @Published var isRecording = false
    @Published var transcribedText = ""
    @Published var isListeningForWakeWord = false
    @Published var wakeWordDetected = false
    
    // Computed property to satisfy VoiceInputServiceProtocol for synchronous check
    var isListeningForWakeWordValue: Bool {
        return isListeningForWakeWord // Directly return the current value of the @Published property
    }

    private var cancellables = Set<AnyCancellable>()
    
    override private init() {
        super.init()
        requestPermissions()
    }
    
    private func requestPermissions() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    print("Speech recognition authorized")
                case .denied, .restricted, .notDetermined:
                    print("Speech recognition not authorized: \(status.rawValue)")
                @unknown default:
                    print("Unknown authorization status")
                }
            }
        }
    }
    
    func startListeningForWakeWord() {
        isListeningForWakeWord = true
        startRecording(forWakeWordDetection: true)
    }
    
    func stopListeningForWakeWord() {
        isListeningForWakeWord = false
        stopRecording()
    }
    
    func startRecording(forWakeWordDetection: Bool = false) {
        // Cancel any ongoing recognition tasks
        if recognitionTask != nil {
            recognitionTask?.cancel()
            recognitionTask = nil
        }
        
        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Failed to set up audio session: \(error.localizedDescription)")
            return
        }
        
        // Create and configure the speech recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            print("Unable to create speech recognition request")
            return
        }
        recognitionRequest.shouldReportPartialResults = true
        
        // Configure the audio engine and input node
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        // Install tap on input node
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }
        
        // Start audio engine
        audioEngine.prepare()
        do {
            try audioEngine.start()
            isRecording = true
            
            if !forWakeWordDetection {
                transcribedText = ""
            }
        } catch {
            print("Failed to start audio engine: \(error.localizedDescription)")
            return
        }
        
        // Start recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            var isFinal = false
            
            if let result = result {
                if forWakeWordDetection {
                    // Check for wake word "Hey GWEN"
                    let text = result.bestTranscription.formattedString.lowercased()
                    if text.contains("hey gwen") {
                        DispatchQueue.main.async {
                            self.wakeWordDetected = true
                            self.isListeningForWakeWord = false
                            self.stopRecording()
                            
                            // Reset for next input
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                self.startRecording()
                            }
                        }
                    }
                } else {
                    // Normal transcription
                    DispatchQueue.main.async {
                        self.transcribedText = result.bestTranscription.formattedString
                    }
                }
                isFinal = result.isFinal
            }
            
            if error != nil || isFinal {
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                
                self.recognitionRequest = nil
                self.recognitionTask = nil
                
                if !forWakeWordDetection {
                    DispatchQueue.main.async {
                        self.isRecording = false
                    }
                }
            }
        }
    }
    
    func stopRecording() {
        audioEngine.stop()
        recognitionRequest?.endAudio()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        
        isRecording = false
    }
}
