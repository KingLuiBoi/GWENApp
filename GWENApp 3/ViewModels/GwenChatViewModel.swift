//
//  GwenChatViewModel.swift
//  GWENApp
//
//  Created by Manus on 5/14/25.
//

import Foundation
import Combine
import SwiftUI // For Color, etc. if used in displayable items

class GwenChatViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var conversation: [GwenInteraction] = []
    @Published var currentInput: String = ""
    @Published var isThinking: Bool = false // To show a thinking indicator
    @Published var errorMessage: String? = nil
    @Published var hasPermissions: Bool = false
    @Published var isListeningForHeyGwen: Bool = false
    @Published var isActivelyListening: Bool = false // After "Hey GWEN" or manual tap

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
        // Simplified check; VoiceInputService should handle actual permission status
        // For now, assume we need to request if not explicitly known
        if SFSpeechRecognizer.authorizationStatus() == .authorized && AVAudioSession.sharedInstance().recordPermission == .granted {
            hasPermissions = true
        } else {
            hasPermissions = false
            // voiceInputService.requestPermissions() // Or trigger this from UI
        }
    }

    private func subscribeToVoiceInput() {
        voiceInputService.transcribedText
            .receive(on: DispatchQueue.main)
            .sink { [weak self] transcribedText in
                guard let self = self else { return }
                if self.isListeningForHeyGwen && transcribedText.lowercased().contains("hey gwen") {
                    print("ViewModel: Hey GWEN detected by service.")
                    self.voiceInputService.stopHeyGwenDetection()
                    self.isListeningForHeyGwen = false
                    // Automatically start active listening for the command
                    self.startActiveListening()
                } else if self.isActivelyListening {
                    self.currentInput = transcribedText // Update input field with ongoing transcription
                    // User might stop speaking, then we send. Or a send button.
                    // For now, let's assume a manual send action after transcription populates currentInput.
                }
            }
            .store(in: &cancellables)

        voiceInputService.isListening
            .receive(on: DispatchQueue.main)
            .sink { [weak self] listeningState in
                self?.isActivelyListening = listeningState
                if !listeningState && !self!.currentInput.isEmpty && self!.isThinking == false { // Auto-send if listening stops and there's input
                    // This auto-send logic might need refinement based on UX.
                    // self.sendCurrentPrompt()
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
                self?.errorMessage = "Voice input error: \(error.localizedDescription)"
                self?.isThinking = false
                self?.isListeningForHeyGwen = false
                self?.isActivelyListening = false
            }
            .store(in: &cancellables)
    }
    
    private func subscribeToAudioPlayback() {
        // Example: If you need to react to playback state changes from the service
        // For instance, if AudioPlaybackService had a @Published var isPlaying:
        // audioPlaybackService.isPlayingPublisher // Assuming a publisher exists
        //     .receive(on: DispatchQueue.main)
        //     .sink { [weak self] playing in
        //         // self.isGwenSpeaking = playing
        //     }
        //     .store(in: &cancellables)
    }

    // MARK: - User Intents
    func requestVoicePermissions() {
        voiceInputService.requestPermissions()
        // Update hasPermissions based on callback or a delay, or re-check
        // For simplicity, this is a one-shot request. UI should reflect actual status from SFSpeechRecognizer.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { // Simulate permission grant delay
            self.checkPermissions()
        }
    }
    
    func toggleHeyGwenListening() {
        if isListeningForHeyGwen {
            voiceInputService.stopHeyGwenDetection()
        } else {
            guard hasPermissions else { 
                errorMessage = "Please grant speech and microphone permissions first."
                requestVoicePermissions()
                return
            }
            voiceInputService.startHeyGwenDetection()
        }
    }
    
    func startActiveListening() {
        guard hasPermissions else { 
            errorMessage = "Please grant speech and microphone permissions first."
            requestVoicePermissions()
            return
        }
        currentInput = "" // Clear previous input
        voiceInputService.startTranscribing()
    }
    
    func stopActiveListening() {
        voiceInputService.stopTranscribing()
        // If there's content in currentInput, user might expect it to be sent
        if !currentInput.isEmpty {
            // sendCurrentPrompt() // Or require explicit send button tap
        }
    }

    func sendCurrentPrompt() {
        let promptToSend = currentInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !promptToSend.isEmpty else { return }

        isThinking = true
        errorMessage = nil
        currentInput = "" // Clear input field

        let userInteraction = GwenInteraction(userPrompt: promptToSend)
        conversation.append(userInteraction)
        let interactionIndex = conversation.count - 1

        Task {
            do {
                let audioData = try await networkingService.sendGwenPrompt(prompt: "hey gwen " + promptToSend) // Prepend "hey gwen" as per backend expectation
                
                // In a real scenario, the backend might also return the transcript.
                // For now, we assume the prompt itself is the user side of transcript.
                // And GWEN's response is primarily audio.
                // If backend provides transcript, update here.
                
                DispatchQueue.main.async {
                    self.conversation[interactionIndex].audioData = audioData
                    // For now, let's assume the backend doesn't send back its own transcript of its speech.
                    // If it did, we would update: self.conversation[interactionIndex].gwenTranscript = backendTranscript
                    self.isThinking = false
                    self.audioPlaybackService.playAudio(data: audioData)
                }
            } catch {
                DispatchQueue.main.async {
                    self.isThinking = false
                    if let networkError = error as? NetworkError {
                        switch networkError {
                        case .serverError(_, let message):
                            self.errorMessage = message ?? "Server error occurred."
                        default:
                            self.errorMessage = "Network error: \(error.localizedDescription)"
                        }
                    } else {
                        self.errorMessage = "Failed to send prompt: \(error.localizedDescription)"
                    }
                    // Update the interaction to show an error state if desired
                }
            }
        }
    }
    
    func playAudio(for interactionId: UUID) {
        if let interaction = conversation.first(where: { $0.id == interactionId }), let audioData = interaction.audioData {
            audioPlaybackService.playAudio(data: audioData)
        } else {
            errorMessage = "Audio data not found for this interaction."
        }
    }
}

