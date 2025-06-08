//
//  WatchTimeCapsuleViewModel.swift
//  GWENAppWatchOS
//
//  Created by Manus on 5/14/25.
//

import Foundation
import Combine

// Reusing the iOS TimeCapsuleViewModel for WatchOS for now.
// If significant differences in logic or data presentation are needed,
// a dedicated WatchTimeCapsuleViewModel could be created.
// For simplicity, we assume the existing one is mostly compatible for data operations.

// No new ViewModel needed if TimeCapsuleViewModel is suitable.
// If a dedicated one was needed, it would look like this:
/*
class WatchTimeCapsuleViewModel: ObservableObject {
    @Published var entries: [TimeCapsuleEntry] = [] // Might show fewer, or just allow adding
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    @Published var newEntryNote: String = ""
    // Tag might be omitted for WatchOS simplicity or handled differently

    private let networkingService: NetworkingServiceProtocol

    init(networkingService: NetworkingServiceProtocol = NetworkingService.shared) {
        self.networkingService = networkingService
        // fetchEntries()
    }

    func fetchEntries() {
        // Simplified fetch or only fetch latest N entries
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let fetchedEntries = try await networkingService.fetchTimeCapsules()
                DispatchQueue.main.async {
                    // Potentially limit the number of entries for WatchOS display
                    self.entries = Array(fetchedEntries.sorted(by: { $0.timestamp > $1.timestamp }).prefix(5))
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.errorMessage = "Failed: \(error.localizedDescription)".prefix(50).description
                }
            }
        }
    }

    func addEntryViaVoice(note: String) { // Watch might be voice-first for input
        guard !note.isEmpty else {
            errorMessage = "Note empty."
            return
        }
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let newEntry = try await networkingService.createTimeCapsule(note: note, tag: nil) // No tag for simplicity
                DispatchQueue.main.async {
                    self.entries.insert(newEntry, at: 0)
                    self.entries.sort(by: { $0.timestamp > $1.timestamp })
                    if self.entries.count > 5 { self.entries.removeLast() } // Keep list short
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.errorMessage = "Failed to add: \(error.localizedDescription)".prefix(50).description
                }
            }
        }
    }
}
*/

