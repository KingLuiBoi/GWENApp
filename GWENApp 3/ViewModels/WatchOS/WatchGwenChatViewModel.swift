//
//  WatchGwenChatViewModel.swift
//  GWENAppWatchOS
//
//  Created by Manus on 5/14/25.
//

import Foundation
import Combine
import SwiftUI
import Speech
import AVFoundation

@MainActor
class WatchGwenChatViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var lastUserPrompt: String? = nil
    @Published var lastGwenResponse: String? = nil
    @Published var isGwenSpeaking: Bool = false
    
    @Published var currentInputText: String = ""
    @Published var isThinking: Bool = false
    @Published var errorMessage: String? = nil
    @Published var hasPermissions: Bool = false
    @Published var isListeningForHeyGwen: Bool = false
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
        if SFSpeechRecognizer.authorizationStatus() == .authorized && AVAudioApplication.shared.recordPermission == .granted {
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
        AudioPlaybackService.shared.$isPlaying
            .receive(on: DispatchQueue.main)
            .assign(to: \.isGwenSpeaking, on: self)
            .store(in: &cancellables)
    }

    // MARK: - User Intents
    func requestVoicePermissions() {
        voiceInputService.requestPermissions()
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
            checkPermissions()
        }
    }
    
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
        currentInputText = ""
        lastUserPrompt = isHeyGwenTriggered ? "(Hey GWEN...)" : "(Listening...)"
        lastGwenResponse = nil
        voiceInputService.startListening()
    }
    
    func stopActiveListening() {
        voiceInputService.stopListening()
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
                let fullPrompt = promptToSend.lowercased().hasPrefix("hey gwen") ? promptToSend : "hey gwen " + promptToSend
                let (audioData, transcript) = try await networkingService.sendGwenPrompt(prompt: fullPrompt)
                
                isThinking = false
                lastGwenResponse = transcript.isEmpty ? "(Playing GWEN's response)" : transcript
                
                try await audioPlaybackService.playAudio(data: audioData)
            } catch {
                isThinking = false
                lastGwenResponse = "Error" 
                errorMessage = "Failed: \(error.localizedDescription)"
            }
        }
    }
}

