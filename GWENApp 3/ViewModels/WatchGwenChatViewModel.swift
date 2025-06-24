//
//  WatchGwenChatViewModel.swift
//  GWENAppWatchOS
//
//  Created by Manus on 5/14/25.
//

import Foundation
import Combine
import SwiftUI // For Color, etc. if used in displayable items
import Speech
import AVFoundation

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
        voiceInputService.transcribedTextPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] transcribedText in
                guard let self = self else { return }
                self.currentInputText = transcribedText
            }
            .store(in: &cancellables)

        voiceInputService.isRecordingPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isRecording in
                guard let self = self else { return }
                self.isActivelyListening = isRecording
                if !isRecording && !self.currentInputText.isEmpty && self.isThinking == false {
                    self.sendPrompt(prompt: self.currentInputText)
                    self.currentInputText = ""
                }
            }
            .store(in: &cancellables)

        voiceInputService.wakeWordDetectedPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] detected in
                guard let self = self else { return }
                if detected {
                    self.isListeningForHeyGwen = false
                    self.startActiveListening(isHeyGwenTriggered: true)
                }
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
            voiceInputService.stopWakeWordDetection()
        } else {
            guard hasPermissions else { 
                errorMessage = "Grant permissions first."
                requestVoicePermissions()
                return
            }
            voiceInputService.startWakeWordDetection()
            isListeningForHeyGwen = true
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
        voiceInputService.startListening()
    }
    
    func stopActiveListening() {
        voiceInputService.stopListening()
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
                    self.lastGwenResponse = "(Playing GWEN's response)" // Placeholder
                    try? await self.audioPlaybackService.playAudio(data: audioData)
                }
            } catch {
                DispatchQueue.main.async {
                    self.isThinking = false
                    self.lastGwenResponse = "Error" 
                    self.errorMessage = "Failed: \(error.localizedDescription)"
                }
            }
        }
    }
}

