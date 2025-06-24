import Foundation
import Combine
import CoreLocation

protocol LocationServiceProtocol: AnyObject {
    var currentLocation: CLLocation? { get }
    var authorizationStatus: CLAuthorizationStatus { get }
    var locationError: Error? { get }
    var isUpdatingLocation: Bool { get }

    var currentLocationPublisher: AnyPublisher<CLLocation?, Never> { get }
    var authorizationStatusPublisher: AnyPublisher<CLAuthorizationStatus, Never> { get }
    var locationErrorPublisher: AnyPublisher<Error?, Never> { get }
    var isUpdatingLocationPublisher: AnyPublisher<Bool, Never> { get }

    func checkPermission()
    func requestLocationPermissions()
    func startUpdatingLocation()
    func stopUpdatingLocation()
    func updateBackendWithLocation()
}



