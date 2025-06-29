import Foundation
import CoreLocation
import Combine

class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate, LocationServiceProtocol {
    static let shared = LocationService()
    
    private let locationManager = CLLocationManager()
    
    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var locationError: Error?
    @Published var isUpdatingLocation = false
    
    var currentLocationPublisher: AnyPublisher<CLLocation?, Never> {
        $currentLocation.eraseToAnyPublisher()
    }

    var authorizationStatusPublisher: AnyPublisher<CLAuthorizationStatus, Never> {
        $authorizationStatus.eraseToAnyPublisher()
    }

    var locationErrorPublisher: AnyPublisher<Error?, Never> {
        $locationError.eraseToAnyPublisher()
    }

    var isUpdatingLocationPublisher: AnyPublisher<Bool, Never> {
        $isUpdatingLocation.eraseToAnyPublisher()
    }

    override private init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        checkPermission()
    }

    func checkPermission() {
        authorizationStatus = locationManager.authorizationStatus
    }

    func requestLocationPermissions() {
        locationManager.requestWhenInUseAuthorization()
    }

    func startUpdatingLocation() {
        isUpdatingLocation = true
        locationManager.startUpdatingLocation()
    }

    func stopUpdatingLocation() {
        isUpdatingLocation = false
        locationManager.stopUpdatingLocation()
    }

    func updateBackendWithLocation() {
        guard let location = currentLocation else { return }
        Task {
            do {
                let _ = try await NetworkingService.shared.updateUserLocation(
                    lat: location.coordinate.latitude,
                    lon: location.coordinate.longitude
                )
            } catch {
                locationError = error
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        authorizationStatus = status
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let age = location.timestamp.timeIntervalSinceNow
        if abs(age) < 5 {
            currentLocation = location
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationError = error
        isUpdatingLocation = false
    }
}

