import Foundation
import Combine
import CoreLocation

@MainActor
class WatchPlacesViewModel: ObservableObject {
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

        subscribeToLocationServices()
    }

    private func subscribeToLocationServices() {
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

    func searchPlaces(type: String? = nil) {
        let effectiveSearchQuery = type ?? searchQuery

        guard !effectiveSearchQuery.isEmpty else {
            errorMessage = "Search query is empty."
            searchResults = []
            return
        }

        guard let location = locationService.currentLocation else {
            errorMessage = "Location unknown."

            let authStatus = locationService.authorizationStatus

            if authStatus == .notDetermined {
                locationService.requestLocationPermissions()
            } else if authStatus == .authorizedWhenInUse || authStatus == .authorizedAlways {
                locationService.startUpdatingLocation()
            }

            searchResults = []
            return
        }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                let results = try await networkingService.searchPlaces(
                    lat: location.coordinate.latitude,
                    lon: location.coordinate.longitude,
                    type: effectiveSearchQuery,
                    radius: 1000 // ✅ required argument
                )
                self.searchResults = results
                if results.isEmpty {
                    self.errorMessage = "No places found for \"\(effectiveSearchQuery)\"."
                }
            } catch {
                self.errorMessage = "Search error: \(error.localizedDescription.prefix(50))"
                self.searchResults = []
            }
            self.isLoading = false
        }
    }

    func requestLocationAccessIfNeeded() {
        let authStatus = locationService.authorizationStatus

        if authStatus == .notDetermined {
            locationService.requestLocationPermissions()
        } else if authStatus == .authorizedWhenInUse || authStatus == .authorizedAlways {
            locationService.startUpdatingLocation()
        }
    }
}

