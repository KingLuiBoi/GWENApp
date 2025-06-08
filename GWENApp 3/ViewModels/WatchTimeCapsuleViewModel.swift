import Foundation
import Combine

// Assuming NetworkingServiceProtocol is defined elsewhere and accessible,
// and NetworkingService.shared conforms to it with the required time capsule methods.

@MainActor
class WatchTimeCapsuleViewModel: ObservableObject {
    @Published var timeCapsules: [TimeCapsule] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    // For creating a new capsule on watch
    @Published var newCapsuleNote: String = ""
    // For watchOS, DatePicker can be used. Defaulting to 1 day from now.
    @Published var newCapsuleOpenDate: Date = Date().addingTimeInterval(60*60*24)
    @Published var addCapsuleSuccess: Bool = false

    private let networkingService: NetworkingServiceProtocol

    init(networkingService: NetworkingServiceProtocol = NetworkingService.shared) {
        self.networkingService = networkingService
    }

    func fetchTimeCapsules() {
        guard timeCapsules.isEmpty else { // Only fetch if time capsules list is empty
            print("Time capsules already loaded.")
            return
        }
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let fetchedCapsules = try await networkingService.fetchTimeCapsules()
                self.timeCapsules = fetchedCapsules.sorted(by: { $0.timestamp < $1.timestamp })
            } catch {
                self.errorMessage = "Error: \(error.localizedDescription.prefix(100))" // Keep error messages concise for watch
                print("Error fetching time capsules: \(error)")
            }
            self.isLoading = false
        }
    }

    func addTimeCapsule() {
        guard !newCapsuleNote.isEmpty else {
            errorMessage = "Note is empty."
            return
        }
        guard newCapsuleOpenDate > Date() else {
            errorMessage = "Date must be future."
            return
        }

        isLoading = true
        errorMessage = nil
        addCapsuleSuccess = false

        Task {
            do {
                let createdCapsule = try await networkingService.createTimeCapsule(
                    note: newCapsuleNote,
                    timestamp: newCapsuleOpenDate.timeIntervalSince1970
                )
                self.timeCapsules.append(createdCapsule)
                self.timeCapsules.sort(by: { $0.timestamp < $1.timestamp })

                self.newCapsuleNote = ""
                self.newCapsuleOpenDate = Date().addingTimeInterval(60*60*24)
                self.addCapsuleSuccess = true
            } catch {
                self.errorMessage = "Save failed: \(error.localizedDescription.prefix(50))"
                print("Error creating time capsule: \(error)")
                self.addCapsuleSuccess = false
            }
            self.isLoading = false
        }
    }

    func deleteTimeCapsule(at offsets: IndexSet) {
        let capsulesToDelete = offsets.map { timeCapsules[$0] }
        timeCapsules.remove(atOffsets: offsets)

        Task {
            for capsule in capsulesToDelete {
                do {
                    try await networkingService.deleteTimeCapsule(capsuleID: capsule.id)
                } catch {
                    print("Error deleting time capsule \(capsule.id) from backend: \(error.localizedDescription)")
                    // On watch, simply log error. UI already reflects deletion.
                    // May briefly show an error if critical.
                    DispatchQueue.main.async {
                       // self.errorMessage = "Sync delete error." // Very brief error
                    }
                }
            }
        }
    }
}
