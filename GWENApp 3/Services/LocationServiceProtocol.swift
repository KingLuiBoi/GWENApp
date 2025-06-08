import Foundation
import Combine
import CoreLocation

protocol LocationServiceProtocol {
    // Published properties
    var currentLocation: AnyPublisher<CLLocationCoordinate2D?, Never> { get } // Expose as CLLocationCoordinate2D
    var authorizationStatus: AnyPublisher<CLAuthorizationStatus, Never> { get }
    var locationError: AnyPublisher<Error?, Never> { get }
    var isUpdatingLocation: AnyPublisher<Bool, Never> { get }

    // Getter for current value of authorizationStatus (needed by ViewModels)
    var authorizationStatusValue: CLAuthorizationStatus { get }
    // Getter for current value of currentLocation (needed by ViewModels)
    var currentLocationValue: CLLocationCoordinate2D? { get }

    // Methods
    func requestLocationPermissions() // Renamed from requestPermission for consistency
    func startUpdatingLocation()
    func stopUpdatingLocation()

    // updateBackendWithLocation is a specific implementation detail,
    // may not need to be in protocol unless other services need to trigger it.
    // For now, keep it out of the protocol for stricter ViewModel dependencies.
}

extension LocationService: LocationServiceProtocol {
    var currentLocation: AnyPublisher<CLLocationCoordinate2D?, Never> {
        $currentLocation.map { $0?.coordinate }.eraseToAnyPublisher()
    }

    var authorizationStatus: AnyPublisher<CLAuthorizationStatus, Never> {
        $authorizationStatus.eraseToAnyPublisher()
    }

    var locationError: AnyPublisher<Error?, Never> {
        $locationError.eraseToAnyPublisher()
    }

    var isUpdatingLocation: AnyPublisher<Bool, Never> {
        $isUpdatingLocation.eraseToAnyPublisher()
    }

    var authorizationStatusValue: CLAuthorizationStatus {
        return authorizationStatus // The @Published property itself
    }

    var currentLocationValue: CLLocationCoordinate2D? {
        return currentLocation?.coordinate // The @Published property's coordinate
    }

    // Ensure method names in LocationService match if they differ from protocol
    func requestLocationPermissions() { // Ensure this matches if actual method is requestPermission()
        self.requestPermission() // Call the existing method
    }
}
