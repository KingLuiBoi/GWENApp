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
        // Update isListeningForHeyGwen based on the service's state
        voiceInputService.isListeningForWakeWord
            .receive(on: DispatchQueue.main)
            .assign(to: \.isListeningForHeyGwen, on: self)
            .store(in: &cancellables)

        // Handle wake word detection
        voiceInputService.wakeWordDetected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] detected in
                guard let self = self, detected else { return }
                print("ViewModel: Wake word detected by service!")
                // Service itself handles stopping wake word listening and starting command recording.
                // ViewModel needs to update its state to reflect that it's now actively listening for a command.
                self.isActivelyListening = true
                self.currentInput = "" // Ensure input is clear for the new command
                // Potentially provide haptic/audio feedback here if needed
            }
            .store(in: &cancellables)

        // Update transcribedText from the service
        voiceInputService.transcribedText
            .receive(on: DispatchQueue.main)
            .sink { [weak self] text in
                guard let self = self else { return }
                // Only update currentInput if we are in active listening mode (post-wake word or manual)
                // and not in wake word detection mode.
                if self.isActivelyListening && !self.isListeningForHeyGwen {
                    self.currentInput = text
                }
            }
            .store(in: &cancellables)

        // Update isActivelyListening based on the service's recording state
        // This replaces the old `voiceInputService.isListening`
        voiceInputService.isRecording
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isRecording in
                guard let self = self else { return }

                // If recording stops, and we were actively listening (not for wake word),
                // and there's text, consider it the end of a command.
                if !isRecording && self.isActivelyListening && !self.isListeningForHeyGwen {
                    self.isActivelyListening = false // Update our state
                    if !self.currentInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        print("ViewModel: Recording stopped, sending prompt.")
                        self.sendCurrentPrompt()
                    }
                } else if isRecording && !self.isListeningForHeyGwen {
                    // If service starts recording and we are not in wake word mode, it means active listening for command.
                    self.isActivelyListening = true
                } else if !isRecording {
                    // If service just stops recording for any other reason (e.g. wake word listening stopped without detection)
                    self.isActivelyListening = false
                }
            }
            .store(in: &cancellables)

        // Note: The VoiceInputService currently doesn't have a general `errorOccurred` publisher.
        // Error handling is done via console prints in the service.
        // If specific errors need UI updates, that publisher should be added to the protocol and service.
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
    
    func startHeyGwenIfNeeded() { // New method for onAppear logic
        if !isListeningForHeyGwen && hasPermissions {
            voiceInputService.startListeningForWakeWord()
        } else if !hasPermissions {
            requestVoicePermissions()
        }
    }

    func toggleHeyGwenListening() {
        if voiceInputService.isListeningForWakeWordValue { // Accessing underlying value for immediate check
            voiceInputService.stopListeningForWakeWord()
        } else {
            guard hasPermissions else {
                errorMessage = "Please grant speech and microphone permissions first."
                requestVoicePermissions()
                return
            }
            currentInput = "" // Clear any previous input
            voiceInputService.startListeningForWakeWord()
        }
    }
    
    func startActiveListening() { // Manual tap to listen for command
        guard hasPermissions else {
            errorMessage = "Please grant speech and microphone permissions first."
            requestVoicePermissions()
            return
        }
        if isListeningForHeyGwen { // If "Hey GWEN" was on, turn it off
            voiceInputService.stopListeningForWakeWord()
        }
        currentInput = "" // Clear previous input
        isActivelyListening = true // Set our state
        voiceInputService.startRecording(forWakeWordDetection: false) // Start general recording
    }
    
    func stopActiveListening() { // Manual tap to stop listening
        voiceInputService.stopRecording() // Stop general recording
        isActivelyListening = false // Update our state
        // The isRecording publisher will handle sending the prompt if text exists.
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

