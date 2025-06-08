import Foundation
import MapKit // For MKMapItem, CLLocationCoordinate2D, MKDirectionsTransportType, MKDirections.Response
import Combine // For AnyPublisher

// Define PlaceSearchResult if it's used by the protocol and not globally available
// Assuming PlaceSearchResult is defined in DataModels.swift
// Assuming Place is defined in DataModels.swift

protocol MapKitServiceProtocol {
    // Published properties (if any were needed by ViewModels directly, e.g., isSearching)
    // var isSearching: AnyPublisher<Bool, Never> { get }
    // var searchResultsPublisher: AnyPublisher<[MKMapItem], Never> { get } // Example if direct publisher needed

    // Methods
    // Note: searchNearbyPlaces in service is async (completion handler). Protocol uses Combine.
    // For consistency with async/await in other protocols, this should ideally be async.
    // However, PlacesViewModel uses it as a Combine publisher.
    // This highlights another area for future refactor towards pure async/await.
    // For now, match what PlacesViewModel expects from its MapKitService dependency.

    func searchForPlaces(near location: CLLocationCoordinate2D, query: String, radius: CLLocationDistance) -> AnyPublisher<[MKMapItem], Error>
    // Renamed searchNearbyPlaces to searchForPlaces for protocol clarity, and added radius.
    // The implementation in MapKitService.swift will need to match or be adapted.

    func getDirections(from source: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D, transportType: MKDirectionsTransportType) -> AnyPublisher<MKRoute, Error>
    // Simplified signature from original MapKitService which took MKMapItem. ViewModels have coordinates.
    // The implementation will need to create MKMapItems internally.

    // Helper methods, if used by ViewModels directly (otherwise they are implementation details)
    func convertMapItemToPlaceSearchResult(mapItem: MKMapItem) -> PlaceSearchResult
    func convertPlaceSearchResultToMapItem(place: PlaceSearchResult) -> MKMapItem?
}

extension MapKitService: MapKitServiceProtocol {
    // searchForPlaces - existing searchNearbyPlaces is callback based, not publisher.
    // This will require a more significant change in MapKitService or PlacesViewModel.
    // For now, I'll create a new publisher-based wrapper in MapKitService.
    func searchForPlaces(near location: CLLocationCoordinate2D, query: String, radius: CLLocationDistance = 1000) -> AnyPublisher<[MKMapItem], Error> {
        // This is a new method to fit the protocol.
        // The existing `searchNearbyPlaces` updates a @Published var.
        // This should return a new publisher for each call.
        return Future<[MKMapItem], Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(NSError(domain: "MapKitService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Self is nil"])))
                return
            }

            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = query
            request.region = MKCoordinateRegion(center: location, latitudinalMeters: radius, longitudinalMeters: radius)

            let search = MKLocalSearch(request: request)
            search.start { response, error in
                if let error = error {
                    promise(.failure(error))
                } else if let response = response {
                    promise(.success(response.mapItems))
                } else {
                    promise(.failure(NSError(domain: "MapKitService", code: -2, userInfo: [NSLocalizedDescriptionKey: "No response and no error."])))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    // getDirections - existing one takes MKMapItem. This takes CLLocationCoordinate2D.
    func getDirections(from source: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D, transportType: MKDirectionsTransportType = .automobile) -> AnyPublisher<MKRoute, Error> {
        let sourcePlacemark = MKPlacemark(coordinate: source)
        let destinationPlacemark = MKPlacemark(coordinate: destination)
        let sourceMapItem = MKMapItem(placemark: sourcePlacemark)
        let destinationMapItem = MKMapItem(placemark: destinationPlacemark)

        // Call existing publisher method with constructed MKMapItems
        return self.getDirections(to: destinationMapItem, from: sourceMapItem, transportType: transportType)
            .map { $0.routes.first } // The protocol expects MKRoute, existing returns MKDirections.Response
            .compactMap { $0 } // Ensure we have a route
            .eraseToAnyPublisher()
    }

    // Helper methods are directly implemented in MapKitService, no change needed for protocol conformance here
    // as long as their signatures match what the protocol might require (if they were part of it).
    // The current protocol definition includes them, so they must be public in MapKitService.
}

// Definition of PlaceSearchResult if not available globally.
// Should be in DataModels.swift
/*
struct PlaceSearchResult: Identifiable {
    let id: String // place_id or a generated UUID
    let name: String
    let address: String?
    let lat: String? // Or Double
    let lon: String? // Or Double
    // Add other relevant properties that MapKitService.convertMapItemToPlaceSearchResult provides
}
*/
