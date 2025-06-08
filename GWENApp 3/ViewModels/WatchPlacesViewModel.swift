import Foundation
import Combine
import CoreLocation // For CLLocationCoordinate2D

// Assuming NetworkingServiceProtocol and LocationServiceProtocol are defined and accessible.

@MainActor
class WatchPlacesViewModel: ObservableObject {
    @Published var searchResults: [Place] = [] // Using Place model directly
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var searchQuery: String = "" // For text input via dictation

    private let networkingService: NetworkingServiceProtocol
    let locationService: LocationServiceProtocol // Made public for view access if needed for permissions
    private var cancellables = Set<AnyCancellable>()

    init(
        networkingService: NetworkingServiceProtocol = NetworkingService.shared,
        locationService: LocationServiceProtocol = LocationService.shared
    ) {
        self.networkingService = networkingService
        self.locationService = locationService

        subscribeToLocationServices() // Renamed for clarity
    }

    private func subscribeToLocationServices() { // Renamed for clarity
        locationService.authorizationStatus
            .sink { [weak self] status in
                guard let self = self else { return }
                if status == .authorizedWhenInUse || status == .authorizedAlways {
                    self.locationService.startUpdatingLocation() // Ensure location updates start if permitted
                } else {
                    self.locationService.stopUpdatingLocation()
                    // Optionally, prompt for permissions if status is notDetermined,
                    // or inform user if denied/restricted.
                }
            }
            .store(in: &cancellables)
    }

    func searchPlaces(type: String? = nil) {
        let effectiveSearchQuery = type ?? searchQuery // Use specific type if provided, else use bound searchQuery

        guard !effectiveSearchQuery.isEmpty else {
            errorMessage = "Search query is empty."
            searchResults = []
            return
        }

        guard let coordinates = locationService.currentLocation.value else {
            errorMessage = "Location unknown."
            // Attempt to request permissions/location if not available
            if locationService.authorizationStatus.value == .notDetermined {
                locationService.requestLocationPermissions()
            } else if locationService.authorizationStatus.value == .authorizedWhenInUse || locationService.authorizationStatus.value == .authorizedAlways {
                 locationService.startUpdatingLocation() // Try to get a location fix
            }
            searchResults = []
            return
        }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                let results = try await networkingService.searchPlaces(
                    lat: coordinates.latitude,
                    lon: coordinates.longitude,
                    type: effectiveSearchQuery
                )
                self.searchResults = results
                if results.isEmpty {
                    self.errorMessage = "No places found for \"\(effectiveSearchQuery)\"."
                }
            } catch {
                self.errorMessage = "Search error: \(error.localizedDescription.prefix(50))"
                print("Error searching places on watch: \(error)")
                self.searchResults = []
            }
            self.isLoading = false
        }
    }
    
    func requestLocationAccessIfNeeded() {
        // This ensures that location permission is requested if not already determined.
        // And starts location updates if permitted.
        if locationService.authorizationStatus.value == .notDetermined {
            locationService.requestLocationPermissions()
        } else if locationService.authorizationStatus.value == .authorizedWhenInUse || locationService.authorizationStatus.value == .authorizedAlways {
            locationService.startUpdatingLocation()
        }
    }
}
