import Foundation
import Combine
import CoreLocation

class MockLocationService: LocationServiceProtocol {
    // MARK: - Private Subjects
    private let _currentLocation = CurrentValueSubject<CLLocation?, Never>(nil)
    private let _authorizationStatus = CurrentValueSubject<CLAuthorizationStatus, Never>(.notDetermined)
    private let _locationError = CurrentValueSubject<Error?, Never>(nil)
    private let _isUpdatingLocation = CurrentValueSubject<Bool, Never>(false)
    
    // MARK: - Published properties
    var currentLocation: CLLocation? {
        get { _currentLocation.value }
        set { _currentLocation.send(newValue) }
    }
    
    var authorizationStatus: CLAuthorizationStatus {
        get { _authorizationStatus.value }
        set { _authorizationStatus.send(newValue) }
    }
    
    var locationError: Error? {
        get { _locationError.value }
        set { _locationError.send(newValue) }
    }
    
    var isUpdatingLocation: Bool {
        get { _isUpdatingLocation.value }
        set { _isUpdatingLocation.send(newValue) }
    }
    
    // MARK: - Publishers
    var currentLocationPublisher: AnyPublisher<CLLocation?, Never> {
        _currentLocation.eraseToAnyPublisher()
    }
    
    var authorizationStatusPublisher: AnyPublisher<CLAuthorizationStatus, Never> {
        _authorizationStatus.eraseToAnyPublisher()
    }
    
    var locationErrorPublisher: AnyPublisher<Error?, Never> {
        _locationError.eraseToAnyPublisher()
    }
    
    var isUpdatingLocationPublisher: AnyPublisher<Bool, Never> {
        _isUpdatingLocation.eraseToAnyPublisher()
    }
    
    // MARK: - Call tracking for tests
    var requestLocationPermissionsCalled = false
    var startUpdatingLocationCalled = false
    var stopUpdatingLocationCalled = false
    var updateBackendWithLocationCalled = false
    
    func requestLocationPermissions() {
        requestLocationPermissionsCalled = true
    }
    
    func startUpdatingLocation() {
        startUpdatingLocationCalled = true
        isUpdatingLocation = true
    }
    
    func stopUpdatingLocation() {
        stopUpdatingLocationCalled = true
        isUpdatingLocation = false
    }
    
    func updateBackendWithLocation() {
        updateBackendWithLocationCalled = true
    }
    
    // MARK: - Test helpers
    func setLocation(_ location: CLLocation?) {
        self.currentLocation = location
    }
    
    func setAuthorizationStatus(_ status: CLAuthorizationStatus) {
        self.authorizationStatus = status
    }
    
    func setError(_ error: Error?) {
        self.locationError = error
    }
    func checkPermission() {
        // Optional: Simulate behavior if needed for tests
    }

}


