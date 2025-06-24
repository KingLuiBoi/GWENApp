import Foundation
import Combine
import CoreLocation
import MapKit
import UserNotifications

@MainActor
class RemindersViewModel: NSObject, ObservableObject {
    @Published var reminders: [LocationReminder] = []
    @Published var triggeredReminders: [LocationReminder] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    
    @Published var newReminderPlace: String = ""
    @Published var newReminderNote: String = ""
    @Published var newReminderCoordinates: CLLocationCoordinate2D? = nil

    @Published var region: MKCoordinateRegion
    @Published var searchResults: [MKMapItem] = []
    @Published var searchQuery: String = ""
    @Published var showLocationPicker: Bool = false
    @Published var selectedMapItem: MKMapItem?
    @Published var addReminderSuccess: Bool = false

    private let networkingService: NetworkingServiceProtocol
    private let locationService: LocationServiceProtocol
    private let mapKitService: MapKitServiceProtocol
    private let notificationManager = LocalNotificationManager.shared
    
    private var cancellables = Set<AnyCancellable>()
    private var currentLocation: CLLocationCoordinate2D?

    init(
        networkingService: NetworkingServiceProtocol = NetworkingService.shared,
        locationService: LocationServiceProtocol = LocationService.shared,
        mapKitService: MapKitServiceProtocol = MapKitService.shared
    ) {
        self.networkingService = networkingService
        self.locationService = locationService
        self.mapKitService = mapKitService

        self.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )

        super.init()
        setupLocationMonitoring()
        Task { await notificationManager.requestAuthorization() }
    }

    private func setupLocationMonitoring() {
        if let locationService = locationService as? LocationService {
            locationService.$currentLocation
                .compactMap { $0?.coordinate }
                .receive(on: DispatchQueue.main)
                .sink { [weak self] coordinate in
                    self?.currentLocation = coordinate
                    self?.region = MKCoordinateRegion(center: coordinate, span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05))
                    self?.checkLocationForTriggers(coordinates: coordinate)
                }
                .store(in: &cancellables)
        }
    }

    func fetchReminders() {
        isLoading = true
        errorMessage = nil
        addReminderSuccess = false

        Task {
            do {
                let fetchedReminders = try await networkingService.fetchLocationReminders()
                self.reminders = fetchedReminders.sorted { $0.created_at > $1.created_at }
            } catch {
                self.errorMessage = "Failed to fetch reminders: \(error.localizedDescription)"
                print("Error fetching reminders: \(error)")
            }
            isLoading = false
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
                    print("Error deleting reminder: \(error)")
                    self.errorMessage = "Failed to delete reminder. Retrying fetch."
                    await fetchReminders()
                }
            }
        }
    }

    func addReminder() {
        guard let coordinates = newReminderCoordinates else {
            errorMessage = "Please select a location for the reminder."
            return
        }

        guard !newReminderNote.isEmpty else {
            errorMessage = "Please enter a note for the reminder."
            return
        }

        isLoading = true
        errorMessage = nil
        addReminderSuccess = false

        Task {
            do {
                let created = try await networkingService.createLocationReminder(
                    place: newReminderPlace.isEmpty ? "Selected Location" : newReminderPlace,
                    lat: coordinates.latitude,
                    lon: coordinates.longitude,
                    note: newReminderNote,
                    radius: 100
                )

                reminders.insert(created, at: 0)
                reminders.sort { $0.created_at > $1.created_at }

                newReminderPlace = ""
                newReminderNote = ""
                newReminderCoordinates = nil
                selectedMapItem = nil
                searchQuery = ""
                searchResults = []

                addReminderSuccess = true
            } catch {
                errorMessage = "Failed to add reminder: \(error.localizedDescription)"
                print("Error adding reminder: \(error)")
                addReminderSuccess = false
            }
            isLoading = false
        }
    }

    func checkLocationForTriggers(coordinates: CLLocationCoordinate2D) {
        Task {
            do {
                let triggered = try await networkingService.updateUserLocation(lat: coordinates.latitude, lon: coordinates.longitude)
                self.triggeredReminders = triggered

                for reminder in triggered {
                    notificationManager.sendNotification(
                        title: "Reminder Triggered!",
                        body: reminder.reminder
                    )
                }
            } catch {
                print("Error checking triggers: \(error.localizedDescription)")
            }
        }
    }

    func searchLocationsForPicker() {
        guard !searchQuery.isEmpty else {
            errorMessage = "Please enter a location."
            searchResults = []
            return
        }

        guard let searchCenter = currentLocation else {
            errorMessage = "Could not get your current location."
            locationService.requestLocationPermissions()
            return
        }

        isLoading = true

        mapKitService.searchForPlaces(near: searchCenter, query: searchQuery, radius: 1000)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self = self else { return }
                    self.isLoading = false
                    if case let .failure(error) = completion {
                        self.errorMessage = "Search failed: \(error.localizedDescription)"
                        self.searchResults = []
                    }
                },
                receiveValue: { [weak self] items in
                    guard let self = self else { return }
                    self.searchResults = items
                    if items.isEmpty {
                        self.errorMessage = "No locations found."
                    }
                }
            )
            .store(in: &cancellables)
    }



    func selectMapItemForReminder(_ mapItem: MKMapItem) {
        selectedMapItem = mapItem
        newReminderCoordinates = mapItem.placemark.coordinate
        newReminderPlace = mapItem.name ?? "Selected Location"
    }

    func selectCoordinatesForReminder(_ coordinate: CLLocationCoordinate2D, placeNameFromReverseGeocode: String? = nil) {
        newReminderCoordinates = coordinate
        if let name = placeNameFromReverseGeocode, !name.isEmpty {
            newReminderPlace = name
        } else if newReminderPlace.isEmpty {
            newReminderPlace = "Location (\(String(format: "%.4f", coordinate.latitude)), \(String(format: "%.4f", coordinate.longitude)))"
        }
    }

    func requestLocationAccessIfNeeded() {
        locationService.requestLocationPermissions()
    }
}

