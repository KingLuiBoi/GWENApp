import Foundation
import Combine

@MainActor
class TimeCapsuleViewModel: ObservableObject {
    @Published var timeCapsules: [TimeCapsule] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var newCapsuleNote: String = ""
    @Published var newCapsuleOpenDate: Date = Date().addingTimeInterval(60*60*24) // Default to 1 day from now
    @Published var addCapsuleSuccess: Bool = false

    private let networkingService: NetworkingServiceProtocol

    // Ensure NetworkingServiceProtocol defines methods like fetchTimeCapsules, createTimeCapsule, deleteTimeCapsule
    // For now, we assume it does, matching the expected calls.
    init(networkingService: NetworkingServiceProtocol = NetworkingService.shared) {
        self.networkingService = networkingService
    }

    func fetchTimeCapsules() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let fetchedCapsules = try await networkingService.fetchTimeCapsules()
                // Sort by open date, soonest first
                self.timeCapsules = fetchedCapsules.sorted(by: { $0.timestamp < $1.timestamp })
            } catch {
                self.errorMessage = "Failed to fetch time capsules: \(error.localizedDescription)"
                print("Error fetching time capsules: \(error)")
            }
            self.isLoading = false
        }
    }

    func addTimeCapsule() {
        guard !newCapsuleNote.isEmpty else {
            errorMessage = "Please enter a note for your time capsule."
            return
        }
        // Ensure the date is in the future
        guard newCapsuleOpenDate > Date() else {
            errorMessage = "The open date must be in the future."
            return
        }

        isLoading = true
        errorMessage = nil
        addCapsuleSuccess = false

        Task {
            do {
                // Assuming createTimeCapsule exists and takes note and timestamp (for open date)
                let createdCapsule = try await networkingService.createTimeCapsule(
                    note: newCapsuleNote,
                    timestamp: newCapsuleOpenDate.timeIntervalSince1970
                )
                self.timeCapsules.append(createdCapsule)
                self.timeCapsules.sort(by: { $0.timestamp < $1.timestamp }) // Re-sort
                self.newCapsuleNote = ""
                self.newCapsuleOpenDate = Date().addingTimeInterval(60*60*24) // Reset to default
                self.addCapsuleSuccess = true
            } catch {
                self.errorMessage = "Failed to create time capsule: \(error.localizedDescription)"
                print("Error creating time capsule: \(error)")
                self.addCapsuleSuccess = false
            }
            self.isLoading = false
        }
    }

    func deleteTimeCapsule(at offsets: IndexSet) {
        let capsulesToDelete = offsets.map { timeCapsules[$0] }

        // Remove from local array immediately for UI responsiveness
        timeCapsules.remove(atOffsets: offsets)

        Task {
            for capsule in capsulesToDelete {
                do {
                    // Assuming deleteTimeCapsule exists and takes capsuleID
                    try await networkingService.deleteTimeCapsule(capsuleID: capsule.id)
                } catch {
                    // Handle error: e.g., inform user, re-fetch list, or add capsule back
                    print("Error deleting time capsule \(capsule.id) from backend: \(error.localizedDescription)")
                    // For robustness, consider adding the capsule back and setting errorMessage
                    // Or trigger a re-fetch: self.fetchTimeCapsules()
                    DispatchQueue.main.async {
                         self.errorMessage = "Error deleting capsule \(capsule.note). It might still be on the server."
                         // To make UI consistent, might re-fetch or add 'capsule' back.
                         // For now, local list reflects deletion, error message shown for backend issue.
                    }
                }
            }
        }
    }
}

// Removed local NetworkingServiceProtocol definition.
// Assuming a global protocol is defined in NetworkingServiceProtocol.swift
// and NetworkingService.shared conforms to it.
