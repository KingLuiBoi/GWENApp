import Foundation
import MapKit

// MARK: - GWEN Chat Models
struct GwenMessage: Identifiable {
    let id = UUID()
    let text: String
    let isUser: Bool
    let timestamp: Date
    var audioData: Data?
}

// MARK: - Time Capsule Models
struct TimeCapsule: Codable, Identifiable {
    let id: Int
    let note: String
    let timestamp: Double
    let created_at: Double
    
    var createdDate: Date {
        return Date(timeIntervalSince1970: created_at)
    }
    
    var targetDate: Date {
        return Date(timeIntervalSince1970: timestamp)
    }
}

struct TimeCapsuleResponse: Codable {
    let success: Bool
    let id: Int
}

// MARK: - Reminder Models
struct LocationReminder: Codable, Identifiable {
    let id: Int
    let reminder: String
    let latitude: Double
    let longitude: Double
    let place_name: String
    let radius: Int
    let created_at: Double
    
    var coordinate: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    var createdDate: Date {
        return Date(timeIntervalSince1970: created_at)
    }
}

struct ReminderResponse: Codable {
    let success: Bool
    let id: Int
}

struct LocationUpdateResponse: Codable {
    let success: Bool
    let nearby_reminders: [LocationReminder]
}

// MARK: - Places Models
struct Place: Codable, Identifiable {
    let name: String
    let place_id: String
    let vicinity: String
    let latitude: Double
    let longitude: Double
    let rating: Double?
    let types: [String]?
    
    var id: String { place_id }
    
    var coordinate: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct PlaceDetail: Codable {
    let name: String
    let address: String
    let phone: String?
    let latitude: Double
    let longitude: Double
    let website: String?
    let rating: Double?
    let opening_hours: [String]?
    let reviews: [PlaceReview]?
    
    var coordinate: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct PlaceReview: Codable {
    let author: String
    let rating: Int
    let text: String
    let time: Int
    
    var date: Date {
        return Date(timeIntervalSince1970: Double(time))
    }
}

struct GeocodingResult: Codable {
    let address: String
    let latitude: Double
    let longitude: Double
    
    var coordinate: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

// MARK: - Health Check Model
struct HealthCheckResponse: Codable {
    let status: String
    let openai_api_key_set: Bool
    let elevenlabs_api_key_set: Bool
    let gwen_voice_id_set: Bool
    let google_api_key_set: Bool
    
    var isHealthy: Bool {
        return status == "healthy"
    }
    
    var allKeysSet: Bool {
        return openai_api_key_set && elevenlabs_api_key_set && gwen_voice_id_set && google_api_key_set
    }
}
