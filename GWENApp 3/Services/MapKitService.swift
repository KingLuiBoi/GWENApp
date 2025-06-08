import Foundation
import MapKit
import Combine

class MapKitService: ObservableObject {
    static let shared = MapKitService()
    
    @Published var searchResults: [MKMapItem] = []
    @Published var selectedItem: MKMapItem?
    @Published var isSearching = false
    @Published var searchError: Error?
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {}
    
    func searchNearbyPlaces(for query: String, near location: CLLocationCoordinate2D, radius: CLLocationDistance = 1000) {
        isSearching = true
        searchResults = []
        searchError = nil
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = MKCoordinateRegion(
            center: location,
            latitudinalMeters: radius * 2,
            longitudinalMeters: radius * 2
        )
        
        let search = MKLocalSearch(request: request)
        search.start { [weak self] response, error in
            DispatchQueue.main.async {
                self?.isSearching = false
                
                if let error = error {
                    self?.searchError = error
                    return
                }
                
                if let response = response {
                    self?.searchResults = response.mapItems
                }
            }
        }
    }
    
    func getDirections(to destination: MKMapItem, from source: MKMapItem? = nil, transportType: MKDirectionsTransportType = .automobile) -> AnyPublisher<MKDirections.Response, Error> {
        let request = MKDirections.Request()
        request.source = source ?? MKMapItem.forCurrentLocation()
        request.destination = destination
        request.transportType = transportType
        
        let directions = MKDirections(request: request)
        
        return Future<MKDirections.Response, Error> { promise in
            directions.calculate { response, error in
                if let error = error {
                    promise(.failure(error))
                } else if let response = response {
                    promise(.success(response))
                } else {
                    promise(.failure(NSError(domain: "MapKitService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown error getting directions"])))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    func openInMaps(item: MKMapItem) {
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }
    
    func convertPlaceToMapItem(place: Place) -> MKMapItem {
        let placemark = MKPlacemark(coordinate: place.coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = place.name
        return mapItem
    }
    
    func geocodeAddress(_ address: String) -> AnyPublisher<CLLocationCoordinate2D, Error> {
        return Future<CLLocationCoordinate2D, Error> { promise in
            let geocoder = CLGeocoder()
            geocoder.geocodeAddressString(address) { placemarks, error in
                if let error = error {
                    promise(.failure(error))
                    return
                }
                
                guard let placemark = placemarks?.first,
                      let location = placemark.location else {
                    promise(.failure(NSError(domain: "MapKitService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No location found for address"])))
                    return
                }
                
                promise(.success(location.coordinate))
            }
        }
        .eraseToAnyPublisher()
    }
}
