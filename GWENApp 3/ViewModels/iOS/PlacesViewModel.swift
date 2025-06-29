import Foundation
import Combine
import CoreLocation

@MainActor
class PlacesViewModel: ObservableObject {
    @Published var searchResults: [Place] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var searchQuery: String = ""

    private let networkingService: NetworkingServiceProtocol
    let locationService: LocationServiceProtocol
    private var cancellables = Set<AnyCancellable>()

    init(
        networkingService: NetworkingServiceProtocol = NetworkingService.shared,
        locationService: LocationServiceProtocol = LocationService.shared
    ) {
        self.networkingService = networkingService
        self.locationService = locationService

        subscribeToLocationAndPermissions()
    }

    private func subscribeToLocationAndPermissions() {
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

    func searchNearbyPlaces(type: String? = nil) {
        let effectiveQuery = type ?? searchQuery

        guard !effectiveQuery.isEmpty else {
            errorMessage = "Search query is empty."
            searchResults = []
            return
        }

        guard let location = locationService.currentLocation else {
            errorMessage = "Current location not available."

            let auth = locationService.authorizationStatus

            if auth == .notDetermined {
                locationService.requestLocationPermissions()
            } else if auth == .authorizedWhenInUse || auth == .authorizedAlways {
                locationService.startUpdatingLocation()
            }

            return
        }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                let results = try await networkingService.searchPlaces(
                    lat: location.coordinate.latitude,
                    lon: location.coordinate.longitude,
                    type: effectiveQuery,
                    radius: 1000 // ✅ required radius
                )

                self.searchResults = results
                if results.isEmpty {
                    self.errorMessage = "No places found near you."
                }
            } catch {
                self.errorMessage = "Error: \(error.localizedDescription.prefix(50))"
                self.searchResults = []
            }

            self.isLoading = false
        }
    }

    func requestLocationAccessIfNeeded() {
        let auth = locationService.authorizationStatus

        if auth == .notDetermined {
            locationService.requestLocationPermissions()
        } else if auth == .authorizedWhenInUse || auth == .authorizedAlways {
            locationService.startUpdatingLocation()
        }
    }
}

