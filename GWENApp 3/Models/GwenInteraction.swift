//
//  GwenInteraction.swift
//  GWENApplicationXCODE
//
//  Created by Luis Velasco on 6/14/25.
//
import Foundation

struct GwenInteraction: Identifiable, Codable, Equatable {
    let id: UUID
    let userPrompt: String
    let gwenTranscript: String?
    let audioData: Data?

    init(id: UUID = UUID(), userPrompt: String, gwenTranscript: String? = nil, audioData: Data? = nil) {
        self.id = id
        self.userPrompt = userPrompt
        self.gwenTranscript = gwenTranscript
        self.audioData = audioData
    }
}
