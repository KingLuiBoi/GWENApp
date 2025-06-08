//
//  TimeCapsuleViewModel.swift
//  GWENApp
//
//  Created by Manus on 5/14/25.
//

import Foundation
import Combine

class TimeCapsuleViewModel: ObservableObject {
    @Published var entries: [TimeCapsuleEntry] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    // For creating a new entry
    @Published var newEntryNote: String = ""
    @Published var newEntryTag: String = ""

    private let networkingService: NetworkingServiceProtocol
    private var cancellables = Set<AnyCancellable>()

    init(networkingService: NetworkingServiceProtocol = NetworkingService.shared) {
        self.networkingService = networkingService
        // fetchEntries() // Fetch entries on init or let the view trigger it
    }

    func fetchEntries() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let fetchedEntries = try await networkingService.fetchTimeCapsules()
                DispatchQueue.main.async {
                    self.entries = fetchedEntries.sorted(by: { $0.timestamp > $1.timestamp }) // Sort newest first
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.isLoading = false
                    if let networkError = error as? NetworkError {
                         self.errorMessage = networkError.localizedDescription
                    } else {
                        self.errorMessage = "Failed to fetch time capsule entries: \(error.localizedDescription)"
                    }
                    print("Error fetching time capsules: \(error)")
                }
            }
        }
    }

    func addEntry() {
        guard !newEntryNote.isEmpty else {
            errorMessage = "Note cannot be empty."
            return
        }
        isLoading = true
        errorMessage = nil
        
        let tagToSave = newEntryTag.isEmpty ? nil : newEntryTag

        Task {
            do {
                let newEntry = try await networkingService.createTimeCapsule(note: newEntryNote, tag: tagToSave)
                DispatchQueue.main.async {
                    self.entries.insert(newEntry, at: 0) // Add to top of the list
                    self.entries.sort(by: { $0.timestamp > $1.timestamp })
                    self.newEntryNote = ""
                    self.newEntryTag = ""
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.isLoading = false
                    if let networkError = error as? NetworkError {
                         self.errorMessage = networkError.localizedDescription
                    } else {
                        self.errorMessage = "Failed to add time capsule entry: \(error.localizedDescription)"
                    }
                    print("Error adding time capsule: \(error)")
                }
            }
        }
    }
    
    // In a real app, you might want to play the audio for a time capsule entry.
    // This would involve AudioPlaybackService and knowing the audio file path/data.
    // The current TimeCapsuleEntry model has an `audioFilename`. The NetworkingService
    // would need to be able to fetch this audio if it's not sent directly.
    // For now, this is out of scope of the current backend capabilities for fetching specific audio files by name.
}

