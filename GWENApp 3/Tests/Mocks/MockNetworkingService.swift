import Foundation
import Combine // Still needed if any part of the app uses Combine interfaces from NetworkingService, though protocol is async
@testable import GWENApp_3 // Replace GWENApp_3 with your actual app module name

class MockNetworkingService: NetworkingServiceProtocol {
    // MARK: - Call Tracking
    var sendGwenPromptCalled = false
    var fetchTimeCapsulesCalled = false
    var createTimeCapsuleCalled = false
    var deleteTimeCapsuleCalled = false
    var fetchLocationRemindersCalled = false
    var createLocationReminderCalled = false
    var deleteLocationReminderCalled = false
    var updateUserLocationCalled = false
    var searchPlacesCalled = false
    var getPlaceDetailsCalled = false
    var geocodeAddressCalled = false
    var checkBackendHealthCalled = false

    // MARK: - Input Tracking
    var lastPromptSent: String?
    var lastTimeCapsuleNote: String?
    var lastTimeCapsuleTimestamp: Double?
    var lastDeletedCapsuleID: Int?
    var lastReminderPlace: String?
    var lastReminderLat: Double?
    var lastReminderLon: Double?
    var lastReminderNote: String?
    var lastReminderRadius: Int?
    var lastDeletedReminderID: Int?
    var lastUserLocationLat: Double?
    var lastUserLocationLon: Double?
    var lastSearchPlacesLat: Double?
    var lastSearchPlacesLon: Double?
    var lastSearchPlacesType: String?
    var lastSearchPlacesRadius: Int?
    var lastPlaceDetailsID: String?
    var lastGeocodeAddress: String?

    // MARK: - Mock Results & Errors
    var sendGwenPromptResult: Result<(Data, String), NetworkError>?
    var fetchTimeCapsulesResult: Result<[TimeCapsule], NetworkError>?
    var createTimeCapsuleResult: Result<TimeCapsule, NetworkError>? // Protocol returns TimeCapsule
    var deleteTimeCapsuleResult: Result<Void, NetworkError>?
    var fetchLocationRemindersResult: Result<[LocationReminder], NetworkError>?
    var createLocationReminderResult: Result<LocationReminder, NetworkError>? // Protocol returns LocationReminder
    var deleteLocationReminderResult: Result<Void, NetworkError>?
    var updateUserLocationResult: Result<[LocationReminder], NetworkError>? // Protocol returns [LocationReminder]
    var searchPlacesResult: Result<[Place], NetworkError>?
    var getPlaceDetailsResult: Result<PlaceDetail, NetworkError>?
    var geocodeAddressResult: Result<GeocodingResult, NetworkError>?
    var checkBackendHealthResult: Result<HealthCheckResponse, NetworkError>?

    func reset() {
        sendGwenPromptCalled = false
        fetchTimeCapsulesCalled = false
        createTimeCapsuleCalled = false
        // ... reset all tracking vars and results
    }

    // MARK: - Protocol Implementation
    func sendGwenPrompt(prompt: String) async throws -> (Data, String) {
        sendGwenPromptCalled = true
        lastPromptSent = prompt
        guard let result = sendGwenPromptResult else { throw NetworkError.unknown } // Should be configured in test
        return try result.get()
    }

    func fetchTimeCapsules() async throws -> [TimeCapsule] {
        fetchTimeCapsulesCalled = true
        guard let result = fetchTimeCapsulesResult else { throw NetworkError.unknown }
        return try result.get()
    }

    func createTimeCapsule(note: String, timestamp: Double) async throws -> TimeCapsule {
        createTimeCapsuleCalled = true
        lastTimeCapsuleNote = note
        lastTimeCapsuleTimestamp = timestamp
        guard let result = createTimeCapsuleResult else { throw NetworkError.unknown }
        return try result.get()
    }

    func deleteTimeCapsule(capsuleID: Int) async throws -> Void {
        deleteTimeCapsuleCalled = true
        lastDeletedCapsuleID = capsuleID
        guard let result = deleteTimeCapsuleResult else { throw NetworkError.unknown }
        return try result.get()
    }

    func fetchLocationReminders() async throws -> [LocationReminder] {
        fetchLocationRemindersCalled = true
        guard let result = fetchLocationRemindersResult else { throw NetworkError.unknown }
        return try result.get()
    }

    func createLocationReminder(place: String, lat: Double, lon: Double, note: String, radius: Int) async throws -> LocationReminder {
        createLocationReminderCalled = true
        lastReminderPlace = place
        lastReminderLat = lat
        lastReminderLon = lon
        lastReminderNote = note
        lastReminderRadius = radius
        guard let result = createLocationReminderResult else { throw NetworkError.unknown }
        return try result.get()
    }

    func deleteLocationReminder(reminderID: Int) async throws -> Void {
        deleteLocationReminderCalled = true
        lastDeletedReminderID = reminderID
        guard let result = deleteLocationReminderResult else { throw NetworkError.unknown }
        return try result.get()
    }

    func updateUserLocation(lat: Double, lon: Double) async throws -> [LocationReminder] {
        updateUserLocationCalled = true
        lastUserLocationLat = lat
        lastUserLocationLon = lon
        guard let result = updateUserLocationResult else { throw NetworkError.unknown }
        return try result.get()
    }

    func searchPlaces(lat: Double, lon: Double, type: String, radius: Int) async throws -> [Place] {
        searchPlacesCalled = true
        lastSearchPlacesLat = lat
        lastSearchPlacesLon = lon
        lastSearchPlacesType = type
        lastSearchPlacesRadius = radius
        guard let result = searchPlacesResult else { throw NetworkError.unknown }
        return try result.get()
    }

    func getPlaceDetails(placeId: String) async throws -> PlaceDetail {
        getPlaceDetailsCalled = true
        lastPlaceDetailsID = placeId
        guard let result = getPlaceDetailsResult else { throw NetworkError.unknown }
        return try result.get()
    }

    func geocodeAddress(address: String) async throws -> GeocodingResult {
        geocodeAddressCalled = true
        lastGeocodeAddress = address
        guard let result = geocodeAddressResult else { throw NetworkError.unknown }
        return try result.get()
    }

    func checkBackendHealth() async throws -> HealthCheckResponse {
        checkBackendHealthCalled = true
        guard let result = checkBackendHealthResult else { throw NetworkError.unknown }
        return try result.get()
    }
}
