import Foundation
import CoreLocation
import Combine

class LocationService: NSObject, ObservableObject, LocationServiceProtocol { // Added LocationServiceProtocol
    static let shared = LocationService()
    
    private let locationManager = CLLocationManager()
    private var cancellables = Set<AnyCancellable>()
    
    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var locationError: Error?
    @Published var isUpdatingLocation = false
    
    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        checkPermission()
    }
    
    func checkPermission() {
        authorizationStatus = locationManager.authorizationStatus
    }
    
    // requestPermission() is called by requestLocationPermissions() from protocol extension if names differ
    // Or, rename this to requestLocationPermissions() to match protocol directly.
    // For now, assuming protocol extension handles it, or we rename.
    // Let's make it direct for clarity:
    func requestLocationPermissions() { // Renamed from requestPermission
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
                let nearbyReminders = try await NetworkingService.shared.updateUserLocation(
                    lat: location.coordinate.latitude,
                    lon: location.coordinate.longitude
                )
                print("Location updated on backend. Nearby reminders: \(nearbyReminders.count)")
            } catch {
                print("Failed to update location on backend: \(error)")
            }
        }
    }
}

extension LocationService: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        
        if manager.authorizationStatus == .authorizedWhenInUse || 
           manager.authorizationStatus == .authorizedAlways {
            startUpdatingLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // Only update if the location is recent
        let eventAge = location.timestamp.timeIntervalSinceNow
        if abs(eventAge) < 5.0 {
            currentLocation = location
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationError = error
        isUpdatingLocation = false
    }
}
