import Foundation
import Combine // Keep for now if any ViewModel still uses it, but aim for async/await

// Define NetworkError if it's not globally available
// Assuming NetworkError is defined in NetworkingService.swift or a shared location.
// If not, it should be moved to its own file or a shared error file.
/*
enum NetworkError: Error {
    case invalidURL
    case requestFailed(Error)
    case invalidResponse
    case decodingFailed(Error)
    case serverError(String)
    case unknown
}
*/

protocol NetworkingServiceProtocol {
    // GWEN Chat
    // The original sendGwenPrompt returns a publisher. For async/await, it would be:
    func sendGwenPrompt(prompt: String) async throws -> (Data, String) // (audioData, gwenTranscript)

    // Time Capsule
    func fetchTimeCapsules() async throws -> [TimeCapsule]
    func createTimeCapsule(note: String, timestamp: Double) async throws -> TimeCapsule // Changed from TimeCapsuleResponse
    func deleteTimeCapsule(capsuleID: Int) async throws -> Void

    // Reminders
    func fetchLocationReminders() async throws -> [LocationReminder]
    func createLocationReminder(place: String, lat: Double, lon: Double, note: String, radius: Int) async throws -> LocationReminder // Changed from ReminderResponse
    func deleteLocationReminder(reminderID: Int) async throws -> Void
    func updateUserLocation(lat: Double, lon: Double) async throws -> [LocationReminder] // Changed from LocationUpdateResponse

    // Places
    // Assuming PlaceSearchResult can be directly used or mapped to Place for watchOS simplicity if needed
    func searchPlaces(lat: Double, lon: Double, type: String, radius: Int) async throws -> [Place] // Using Place directly
    func getPlaceDetails(placeId: String) async throws -> PlaceDetail
    func geocodeAddress(address: String) async throws -> GeocodingResult

    // Health Check
    func checkBackendHealth() async throws -> HealthCheckResponse
}
