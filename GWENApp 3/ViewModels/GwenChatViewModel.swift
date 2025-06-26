import Foundation
import Combine
import AVFoundation
import Speech

@MainActor
class GwenChatViewModel: ObservableObject {
    @Published var hasPermissions = false
    @Published var isActivelyListening: Bool = false
    @Published var isListeningForHeyGwen = false
    @Published var isThinking = false
    @Published var isGwenSpeaking = false
    @Published var lastUserPrompt: String?
    @Published var lastGwenResponse: String?
    @Published var errorMessage: String?
    @Published var currentInput: String = ""
    @Published var conversation: [GwenInteraction] = []

    private var cancellables = Set<AnyCancellable>()
    private let voiceService: VoiceInputServiceProtocol
    private let networkingService: NetworkingServiceProtocol
    private let audioService: AudioPlaybackServiceProtocol

    init(
        voiceService: VoiceInputServiceProtocol = VoiceInputService.shared,
        networkingService: NetworkingServiceProtocol = NetworkingService.shared,
        audioService: AudioPlaybackServiceProtocol = AudioPlaybackService.shared
    ) {
        self.voiceService = voiceService
        self.networkingService = networkingService
        self.audioService = audioService

        observeVoiceInputs()
        requestVoicePermissions()
    }

    private func observeVoiceInputs() {
        voiceService.transcribedTextPublisher
            .sink { [weak self] text in
                guard let self = self, !text.isEmpty else { return }
                self.lastUserPrompt = text
                self.sendPromptToGwen(text)
            }
            .store(in: &cancellables)

        voiceService.isRecordingPublisher
            .sink { [weak self] isRecording in
                self?.isActivelyListening = isRecording
            }
            .store(in: &cancellables)

        voiceService.wakeWordDetectedPublisher
            .sink { [weak self] detected in
                if detected {
                    self?.startActiveListening()
                }
            }
            .store(in: &cancellables)
    }

    func requestVoicePermissions() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            Task { @MainActor in
                let micStatus = AVAudioApplication.shared.recordPermission == .granted
                self.hasPermissions = authStatus == .authorized && micStatus
            }
        }
    }

    func startActiveListening() {
        guard hasPermissions else {
            errorMessage = "Permissions missing"
            return
        }
        isActivelyListening = true
        voiceService.startListening()
    }

    func stopActiveListening() {
        isActivelyListening = false
        voiceService.stopListening()
    }

    func toggleHeyGwenListening() {
        isListeningForHeyGwen.toggle()
        if isListeningForHeyGwen {
            voiceService.startWakeWordDetection()
        } else {
            voiceService.stopWakeWordDetection()
        }
    }

    func startHeyGwenIfNeeded() {
        if isListeningForHeyGwen {
            voiceService.startWakeWordDetection()
        }
    }

    func sendCurrentPrompt() {
        let trimmed = currentInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        lastUserPrompt = trimmed
        sendPromptToGwen(trimmed)
        currentInput = ""
    }

    private func sendPromptToGwen(_ prompt: String) {
        isThinking = true
        errorMessage = nil

        Task {
            do {
                let (audioData, responseText) = try await networkingService.sendGwenPrompt(prompt: prompt)

                let interaction = GwenInteraction(
                    userPrompt: prompt,
                    gwenTranscript: responseText,
                    audioData: audioData
                )

                conversation.append(interaction)
                lastGwenResponse = responseText
                isGwenSpeaking = true

                if let audio = interaction.audioData {
                    try await audioService.playAudio(data: audio)
                }
            } catch {
                self.errorMessage = "Failed to contact GWEN: \(error.localizedDescription)"
            }

            self.isThinking = false
            self.isGwenSpeaking = false
        }
    }

    func playAudio(for interactionID: UUID) {
        guard let interaction = conversation.first(where: { $0.id == interactionID }) else {
            return
        }

        if let data = interaction.audioData {
            Task {
                try? await audioService.playAudio(data: data)
            }
        }
    }
}

