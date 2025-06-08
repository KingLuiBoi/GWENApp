import Foundation
import Combine
import CoreLocation // For CLLocationCoordinate2D

// Assuming NetworkingServiceProtocol and LocationServiceProtocol are defined and accessible.
// VoiceInputServiceProtocol for potential voice-based reminder creation.

@MainActor
class WatchRemindersViewModel: ObservableObject {
    @Published var reminders: [LocationReminder] = []
    @Published var triggeredReminders: [LocationReminder] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    // For creating a simple reminder (e.g., "remind me here: [note]")
    @Published var newReminderNote: String = ""
    @Published var addReminderSuccess: Bool = false

    private let networkingService: NetworkingServiceProtocol
    let locationService: LocationServiceProtocol // Made public for potential direct use in View for permissions
    // Optional: VoiceInputService for adding reminders by voice
    // private let voiceInputService: VoiceInputServiceProtocol

    private var cancellables = Set<AnyCancellable>()

    init(
        networkingService: NetworkingServiceProtocol = NetworkingService.shared,
        locationService: LocationServiceProtocol = LocationService.shared
        // voiceInputService: VoiceInputServiceProtocol = VoiceInputService.shared
    ) {
        self.networkingService = networkingService
        self.locationService = locationService
        // self.voiceInputService = voiceInputService

        subscribeToLocationUpdates()
    }

    private func subscribeToLocationUpdates() {
        locationService.currentLocation
            .compactMap { $0 }
            .sink { [weak self] coordinates in
                self?.checkLocationForTriggers(coordinates: coordinates)
            }
            .store(in: &cancellables)
            
        locationService.authorizationStatus
            .sink { [weak self] status in
                guard let self = self else { return }
                if status == .authorizedWhenInUse || status == .authorizedAlways {
                    self.locationService.startUpdatingLocation()
                } else {
                    // Handle case where permissions are not granted or revoked on watch
                    self.locationService.stopUpdatingLocation()
                    // self.errorMessage = "Location permission needed." // Potentially
                }
            }
            .store(in: &cancellables)
    }

    func fetchReminders() {
        guard reminders.isEmpty else { // Only fetch if reminders list is empty
            print("Reminders already loaded.")
            return
        }
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let fetchedReminders = try await networkingService.fetchLocationReminders()
                self.reminders = fetchedReminders.sorted(by: { $0.created_at > $1.created_at }) // Show newest first
            } catch {
                self.errorMessage = "Error: \(error.localizedDescription.prefix(100))"
                print("Error fetching reminders: \(error)")
            }
            self.isLoading = false
        }
    }

    // Simplified add reminder: uses current location and a note (e.g., from voice input)
    func addReminderHere(note: String) {
        guard !note.isEmpty else {
            errorMessage = "Note is empty."
            return
        }
        guard let currentLocation = locationService.currentLocation.value else {
            errorMessage = "Location unknown."
            // Try to request location update if status allows
            if locationService.authorizationStatus.value == .authorizedWhenInUse || locationService.authorizationStatus.value == .authorizedAlways {
                 locationService.startUpdatingLocation()
            } else {
                // This should ideally trigger the system permission prompt if not determined,
                // or guide user if denied. For watch, direct prompting might be limited.
                locationService.requestLocationPermissions()
            }
            return
        }

        isLoading = true
        errorMessage = nil
        addReminderSuccess = false

        let placeName = "Near Current Location"

        Task {
            do {
                let newReminder = try await networkingService.createLocationReminder(
                    place: placeName,
                    lat: currentLocation.latitude,
                    lon: currentLocation.longitude,
                    note: note
                )
                self.reminders.insert(newReminder, at: 0)
                self.reminders.sort(by: { $0.created_at > $1.created_at })
                self.newReminderNote = ""
                self.addReminderSuccess = true
            } catch {
                self.errorMessage = "Save failed: \(error.localizedDescription.prefix(50))"
                print("Error adding reminder: \(error)")
                self.addReminderSuccess = false
            }
            self.isLoading = false
        }
    }

    func deleteReminder(at offsets: IndexSet) {
        let remindersToDelete = offsets.map { reminders[$0] }
        reminders.remove(atOffsets: offsets)

        Task {
            for reminder in remindersToDelete {
                do {
                    try await networkingService.deleteLocationReminder(reminderID: reminder.id)
                } catch {
                    print("Error deleting reminder \(reminder.id) from backend: \(error.localizedDescription)")
                }
            }
        }
    }

    private func checkLocationForTriggers(coordinates: CLLocationCoordinate2D) {
        print("Watch: Checking for location triggers at lat: \(coordinates.latitude), lon: \(coordinates.longitude)")
        Task {
            do {
                let triggered = try await networkingService.updateUserLocation(lat: coordinates.latitude, lon: coordinates.longitude)
                if !triggered.isEmpty {
                    self.triggeredReminders = triggered
                    print("Watch: Triggered reminders: \(triggered.map { $0.reminder })")
                    // WKInterfaceDevice.current().play(.notification) // Example haptic
                } else {
                    self.triggeredReminders = []
                }
            } catch {
                print("Watch: Error checking location triggers: \(error.localizedDescription)")
            }
        }
    }
    
    func requestLocationAccessIfNeeded() {
        locationService.requestLocationPermissions()
        if locationService.authorizationStatus.value == .authorizedWhenInUse || locationService.authorizationStatus.value == .authorizedAlways {
            locationService.startUpdatingLocation()
        }
    }
}
