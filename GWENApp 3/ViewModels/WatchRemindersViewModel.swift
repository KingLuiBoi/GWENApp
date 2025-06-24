import Foundation
import Combine
import CoreLocation

@MainActor
class WatchRemindersViewModel: ObservableObject {
    @Published var reminders: [LocationReminder] = []
    @Published var triggeredReminders: [LocationReminder] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    @Published var newReminderNote: String = ""
    @Published var addReminderSuccess: Bool = false

    private let networkingService: NetworkingServiceProtocol
    let locationService: LocationServiceProtocol

    private var cancellables = Set<AnyCancellable>()

    init(
        networkingService: NetworkingServiceProtocol = NetworkingService.shared,
        locationService: LocationServiceProtocol = LocationService.shared
    ) {
        self.networkingService = networkingService
        self.locationService = locationService

        subscribeToLocationUpdates()
    }

    private func subscribeToLocationUpdates() {
        locationService.currentLocationPublisher
            .compactMap { $0 }
            .sink { [weak self] location in
                self?.checkLocationForTriggers(coordinates: location.coordinate)
            }
            .store(in: &cancellables)

        locationService.authorizationStatusPublisher
            .sink { [weak self] status in
                guard let self = self else { return }

                if status == .authorizedWhenInUse || status == .authorizedAlways {
                    self.locationService.startUpdatingLocation()
                } else {
                    self.locationService.stopUpdatingLocation()
                }
            }
            .store(in: &cancellables)
    }

    func fetchReminders() {
        guard reminders.isEmpty else { return }
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let fetchedReminders = try await networkingService.fetchLocationReminders()
                self.reminders = fetchedReminders.sorted(by: { $0.created_at > $1.created_at })
            } catch {
                self.errorMessage = "Error: \(error.localizedDescription.prefix(100))"
            }
            self.isLoading = false
        }
    }

    func addReminderHere(note: String) {
        guard !note.isEmpty else {
            errorMessage = "Note is empty."
            return
        }

        guard let currentLocation = locationService.currentLocation else {
            errorMessage = "Location unknown."

            if locationService.authorizationStatus == .authorizedWhenInUse || locationService.authorizationStatus == .authorizedAlways {
                locationService.startUpdatingLocation()
            } else {
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
                    lat: currentLocation.coordinate.latitude,
                    lon: currentLocation.coordinate.longitude,
                    note: note,
                    radius: 100 // ✅ Added radius parameter here
                )
                self.reminders.insert(newReminder, at: 0)
                self.reminders.sort(by: { $0.created_at > $1.created_at })
                self.newReminderNote = ""
                self.addReminderSuccess = true
            } catch {
                self.errorMessage = "Save failed: \(error.localizedDescription.prefix(50))"
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
        Task {
            do {
                let triggered = try await networkingService.updateUserLocation(lat: coordinates.latitude, lon: coordinates.longitude)
                self.triggeredReminders = triggered
            } catch {
                print("Error checking triggers: \(error.localizedDescription)")
            }
        }
    }

    func requestLocationAccessIfNeeded() {
        locationService.requestLocationPermissions()
        if locationService.authorizationStatus == .authorizedWhenInUse || locationService.authorizationStatus == .authorizedAlways {
            locationService.startUpdatingLocation()
        }
    }
}


