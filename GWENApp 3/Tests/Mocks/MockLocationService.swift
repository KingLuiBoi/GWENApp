import Foundation
import Combine
import CoreLocation
@testable import GWENApp_3 // Replace GWENApp_3 with your actual app module name

class MockLocationService: LocationServiceProtocol {
    // MARK: - Published Property Mocking
    private let _currentLocation = CurrentValueSubject<CLLocationCoordinate2D?, Never>(nil)
    var currentLocation: AnyPublisher<CLLocationCoordinate2D?, Never> { _currentLocation.eraseToAnyPublisher() }

    private let _authorizationStatus = CurrentValueSubject<CLAuthorizationStatus, Never>(.notDetermined)
    var authorizationStatus: AnyPublisher<CLAuthorizationStatus, Never> { _authorizationStatus.eraseToAnyPublisher() }

    private let _locationError = CurrentValueSubject<Error?, Never>(nil)
    var locationError: AnyPublisher<Error?, Never> { _locationError.eraseToAnyPublisher() }

    private let _isUpdatingLocation = CurrentValueSubject<Bool, Never>(false)
    var isUpdatingLocation: AnyPublisher<Bool, Never> { _isUpdatingLocation.eraseToAnyPublisher() }

    // MARK: - Current Value Getters Mocking
    var authorizationStatusValue: CLAuthorizationStatus = .notDetermined {
        didSet { _authorizationStatus.send(authorizationStatusValue) }
    }
    var currentLocationValue: CLLocationCoordinate2D? {
        didSet { _currentLocation.send(currentLocationValue) }
    }

    // MARK: - Call Tracking
    var requestLocationPermissionsCalled = false
    var startUpdatingLocationCalled = false
    var stopUpdatingLocationCalled = false

    func reset() {
        requestLocationPermissionsCalled = false
        startUpdatingLocationCalled = false
        stopUpdatingLocationCalled = false
        _currentLocation.send(nil)
        _authorizationStatus.send(.notDetermined)
        authorizationStatusValue = .notDetermined
        currentLocationValue = nil
        _locationError.send(nil)
        _isUpdatingLocation.send(false)
    }

    // MARK: - Protocol Implementation
    func requestLocationPermissions() {
        requestLocationPermissionsCalled = true
        // Simulate permission change if needed for tests
        // For example: self.authorizationStatusValue = .authorizedWhenInUse
    }

    func startUpdatingLocation() {
        startUpdatingLocationCalled = true
        _isUpdatingLocation.send(true)
    }

    func stopUpdatingLocation() {
        stopUpdatingLocationCalled = true
        _isUpdatingLocation.send(false)
    }

    // MARK: - Helper methods to manually push values for testing
    func setCurrentLocation(to location: CLLocationCoordinate2D?) {
        self.currentLocationValue = location // This will trigger the subject via didSet
    }

    func setAuthorizationStatus(to status: CLAuthorizationStatus) {
        self.authorizationStatusValue = status // This will trigger the subject via didSet
    }

    func setLocationError(to error: Error?) {
        _locationError.send(error)
    }
}
