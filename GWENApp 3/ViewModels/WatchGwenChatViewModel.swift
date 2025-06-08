//
//  WatchGwenChatViewModel.swift
//  GWENAppWatchOS
//
//  Created by Manus on 5/14/25.
//

import Foundation
import Combine
import SwiftUI // For Color, etc. if used in displayable items

// This ViewModel can be similar to GwenChatViewModel but might be simplified
// or tailored for WatchOS specific interactions.
class WatchGwenChatViewModel: ObservableObject {
    // MARK: - Published Properties
    // For WatchOS, we might only show the last interaction or a very short list.
    @Published var lastUserPrompt: String? = nil
    @Published var lastGwenResponse: String? = nil // Transcript
    @Published var isGwenSpeaking: Bool = false // To show some indicator
    
    @Published var currentInputText: String = "" // For text input if supported
    @Published var isThinking: Bool = false
    @Published var errorMessage: String? = nil
    @Published var hasPermissions: Bool = false
    @Published var isListeningForHeyGwen: Bool = false // Not ideal for watch battery, but for consistency
    @Published var isActivelyListening: Bool = false

    // MARK: - Services
    private let networkingService: NetworkingServiceProtocol
    private let voiceInputService: VoiceInputServiceProtocol
    private let audioPlaybackService: AudioPlaybackServiceProtocol

    private var cancellables = Set<AnyCancellable>()

    init(
        networkingService: NetworkingServiceProtocol = NetworkingService.shared,
        voiceInputService: VoiceInputServiceProtocol = VoiceInputService.shared,
        audioPlaybackService: AudioPlaybackServiceProtocol = AudioPlaybackService.shared
    ) {
        self.networkingService = networkingService
        self.voiceInputService = voiceInputService
        self.audioPlaybackService = audioPlaybackService
        
        checkPermissions()
        subscribeToVoiceInput()
        subscribeToAudioPlayback()
    }

    private func checkPermissions() {
        if SFSpeechRecognizer.authorizationStatus() == .authorized && AVAudioSession.sharedInstance().recordPermission == .granted {
            hasPermissions = true
        } else {
            hasPermissions = false
        }
    }

    private func subscribeToVoiceInput() {
        voiceInputService.transcribedText
            .receive(on: DispatchQueue.main)
            .sink { [weak self] transcribedText in
                guard let self = self else { return }
                if self.isListeningForHeyGwen && transcribedText.lowercased().contains("hey gwen") {
                    self.voiceInputService.stopHeyGwenDetection()
                    self.isListeningForHeyGwen = false
                    self.startActiveListening(isHeyGwenTriggered: true)
                } else if self.isActivelyListening {
                    // For WatchOS, we might send immediately after transcription stops or on a delimiter.
                    // Or, if text input is also an option, update a field.
                    self.currentInputText = transcribedText // Keep updating
                }
            }
            .store(in: &cancellables)

        voiceInputService.isListening
            .receive(on: DispatchQueue.main)
            .sink { [weak self] listeningState in
                guard let self = self else { return }
                self.isActivelyListening = listeningState
                if !listeningState && !self.currentInputText.isEmpty && self.isThinking == false {
                    // Auto-send when listening stops and there_s transcribed text
                    // This is more suitable for voice-first interaction on Watch
                    self.sendPrompt(prompt: self.currentInputText)
                    self.currentInputText = "" // Clear after sending
                }
            }
            .store(in: &cancellables)
            
        voiceInputService.isHeyGwenListening
            .receive(on: DispatchQueue.main)
            .assign(to: \.isListeningForHeyGwen, on: self)
            .store(in: &cancellables)

        voiceInputService.errorOccurred
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.errorMessage = "Voice Error: \(error.localizedDescription)".prefix(50) + "..."
                self?.isThinking = false
                self?.isListeningForHeyGwen = false
                self?.isActivelyListening = false
            }
            .store(in: &cancellables)
    }
    
    private func subscribeToAudioPlayback() {
        // Assuming AudioPlaybackService has a @Published var isPlaying
        AudioPlaybackService.shared.$isPlaying // Direct access for simplicity here
            .receive(on: DispatchQueue.main)
            .assign(to: \.isGwenSpeaking, on: self)
            .store(in: &cancellables)
    }

    // MARK: - User Intents
    func requestVoicePermissions() {
        voiceInputService.requestPermissions()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { // Simulate permission grant delay
            self.checkPermissions()
        }
    }
    
    // "Hey GWEN" might be too battery intensive for watch, consider tap-to-speak as primary
    func toggleHeyGwenListening() {
        if isListeningForHeyGwen {
            voiceInputService.stopHeyGwenDetection()
        } else {
            guard hasPermissions else { 
                errorMessage = "Grant permissions first."
                requestVoicePermissions()
                return
            }
            voiceInputService.startHeyGwenDetection()
        }
    }
    
    func startActiveListening(isHeyGwenTriggered: Bool = false) {
        guard hasPermissions else { 
            errorMessage = "Grant permissions first."
            requestVoicePermissions()
            return
        }
        currentInputText = "" // Clear previous input
        lastUserPrompt = isHeyGwenTriggered ? "(Hey GWEN...)" : "(Listening...)"
        lastGwenResponse = nil
        voiceInputService.startTranscribing()
    }
    
    func stopActiveListening() {
        voiceInputService.stopTranscribing()
        // Prompt will be sent automatically by the sink if currentInputText is not empty
    }

    func sendPrompt(prompt: String) {
        let promptToSend = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !promptToSend.isEmpty else { return }

        isThinking = true
        errorMessage = nil
        lastUserPrompt = promptToSend
        lastGwenResponse = "..."

        Task {
            do {
                // Prepend "hey gwen " if not already part of the prompt, as per backend expectation
                let fullPrompt = promptToSend.lowercased().hasPrefix("hey gwen") ? promptToSend : "hey gwen " + promptToSend
                let audioData = try await networkingService.sendGwenPrompt(prompt: fullPrompt)
                
                DispatchQueue.main.async {
                    self.isThinking = false
                    // For WatchOS, we might not get a full transcript back from this endpoint.
                    // We can use the prompt as the user_s part and indicate GWEN is speaking.
                    // If backend could provide a transcript, we_d use it for lastGwenResponse.
                    self.lastGwenResponse = "(Playing GWENs response)" // Placeholder
                    self.audioPlaybackService.playAudio(data: audioData)
                }
            } catch {
                DispatchQueue.main.async {
                    self.isThinking = false
                    self.lastGwenResponse = "Error" 
                    if let networkError = error as? NetworkError {
                        switch networkError {
                        case .serverError(_, let message):
                            self.errorMessage = message?.prefix(50).appending("...").description ?? "Server error."
                        default:
                            self.errorMessage = "Network: \(error.localizedDescription)".prefix(50).appending("...").description
                        }
                    } else {
                        self.errorMessage = "Failed: \(error.localizedDescription)".prefix(50).appending("...").description
                    }
                }
            }
        }
    }
}

