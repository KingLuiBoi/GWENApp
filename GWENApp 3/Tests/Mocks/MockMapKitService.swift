import Foundation
import Combine
import MapKit
@testable import GWENApp_3 // Replace GWENApp_3 with your actual app module name

class MockMapKitService: MapKitServiceProtocol {
    // MARK: - Call Tracking
    var searchForPlacesCalled = false
    var getDirectionsCalled = false
    var convertMapItemToPlaceSearchResultCalled = false
    var convertPlaceSearchResultToMapItemCalled = false

    // MARK: - Input Tracking
    var lastSearchLocation: CLLocationCoordinate2D?
    var lastSearchQuery: String?
    var lastSearchRadius: CLLocationDistance?
    var lastDirectionsSource: CLLocationCoordinate2D?
    var lastDirectionsDestination: CLLocationCoordinate2D?

    // MARK: - Mock Results & Errors
    var searchForPlacesResult: Result<[MKMapItem], Error>?
    var getDirectionsResult: Result<MKRoute, Error>?

    // MARK: - Mock Conversion Results
    var mockPlaceSearchResult: PlaceSearchResult?
    var mockMapItemFromResult: MKMapItem?

    func reset() {
        searchForPlacesCalled = false
        getDirectionsCalled = false
        convertMapItemToPlaceSearchResultCalled = false
        convertPlaceSearchResultToMapItemCalled = false

        lastSearchLocation = nil
        lastSearchQuery = nil
        lastSearchRadius = nil
        lastDirectionsSource = nil
        lastDirectionsDestination = nil

        searchForPlacesResult = nil
        getDirectionsResult = nil
        mockPlaceSearchResult = nil
        mockMapItemFromResult = nil
    }

    // MARK: - Protocol Implementation
    func searchForPlaces(near location: CLLocationCoordinate2D, query: String, radius: CLLocationDistance) -> AnyPublisher<[MKMapItem], Error> {
        searchForPlacesCalled = true
        lastSearchLocation = location
        lastSearchQuery = query
        lastSearchRadius = radius

        guard let result = searchForPlacesResult else {
            return Fail(error: NSError(domain: "MockMapKitService", code: 0, userInfo: [NSLocalizedDescriptionKey: "searchForPlacesResult not set"]))
                .eraseToAnyPublisher()
        }
        return result.publisher.eraseToAnyPublisher()
    }

    func getDirections(from source: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D, transportType: MKDirectionsTransportType) -> AnyPublisher<MKRoute, Error> {
        getDirectionsCalled = true
        lastDirectionsSource = source
        lastDirectionsDestination = destination

        guard let result = getDirectionsResult else {
            return Fail(error: NSError(domain: "MockMapKitService", code: 0, userInfo: [NSLocalizedDescriptionKey: "getDirectionsResult not set"]))
                .eraseToAnyPublisher()
        }
        return result.publisher.eraseToAnyPublisher()
    }

    func convertMapItemToPlaceSearchResult(mapItem: MKMapItem) -> PlaceSearchResult {
        convertMapItemToPlaceSearchResultCalled = true
        // Return a default mock or a configured one
        return mockPlaceSearchResult ?? PlaceSearchResult(id: "mockId", name: mapItem.name ?? "Mock Place", address: "Mock Address", lat: "0.0", lon: "0.0")
    }

    func convertPlaceSearchResultToMapItem(place: PlaceSearchResult) -> MKMapItem? {
        convertPlaceSearchResultToMapItemCalled = true
        // Return a default mock or a configured one
        if let mock = mockMapItemFromResult { return mock }

        guard let lat = Double(place.lat ?? ""), let lon = Double(place.lon ?? "") else { return nil }
        let placemark = MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon))
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = place.name
        return mapItem
    }
}
