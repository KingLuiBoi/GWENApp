import Foundation
import Combine

class NetworkingService {
    static let shared = NetworkingService()
    
    private let baseURL = "http://127.0.0.1:5050" // Default placeholder
    
    private init() {}
    
    // MARK: - GWEN Chat
    func sendPromptToGwen(prompt: String) -> AnyPublisher<(Data, String), NetworkError> {
        guard let url = URL(string: "\(baseURL)/gwen") else {
            return Fail(error: NetworkError.invalidURL).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = ["prompt": prompt]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NetworkError.invalidResponse
                }
                
                if httpResponse.statusCode >= 400 {
                    let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown server error"
                    throw NetworkError.serverError(errorMessage)
                }
                
                // Extract the text response from the header
                let textResponse = httpResponse.value(forHTTPHeaderField: "X-GWEN-Response-Text") ?? ""
                
                return (data, textResponse)
            }
            .mapError { error in
                if let networkError = error as? NetworkError {
                    return networkError
                }
                return NetworkError.requestFailed(error)
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Time Capsule
    func getTimeCapsules() -> AnyPublisher<[TimeCapsule], NetworkError> {
        guard let url = URL(string: "\(baseURL)/timecapsule") else {
            return Fail(error: NetworkError.invalidURL).eraseToAnyPublisher()
        }
        
        return URLSession.shared.dataTaskPublisher(for: url)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    throw NetworkError.invalidResponse
                }
                return data
            }
            .decode(type: [TimeCapsule].self, decoder: JSONDecoder())
            .mapError { error in
                if let decodingError = error as? DecodingError {
                    return NetworkError.decodingFailed(decodingError)
                } else if let networkError = error as? NetworkError {
                    return networkError
                }
                return NetworkError.requestFailed(error)
            }
            .eraseToAnyPublisher()
    }
    
    func createTimeCapsule(note: String, timestamp: Double? = nil) -> AnyPublisher<TimeCapsuleResponse, NetworkError> {
        guard let url = URL(string: "\(baseURL)/timecapsule") else {
            return Fail(error: NetworkError.invalidURL).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var body: [String: Any] = ["note": note]
        if let timestamp = timestamp {
            body["timestamp"] = timestamp
        }
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 201 else {
                    let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown server error"
                    throw NetworkError.serverError(errorMessage)
                }
                return data
            }
            .decode(type: TimeCapsuleResponse.self, decoder: JSONDecoder())
            .mapError { error in
                if let decodingError = error as? DecodingError {
                    return NetworkError.decodingFailed(decodingError)
                } else if let networkError = error as? NetworkError {
                    return networkError
                }
                return NetworkError.requestFailed(error)
            }
            .eraseToAnyPublisher()
    }
    
    func deleteTimeCapsule(id: Int) -> AnyPublisher<Bool, NetworkError> {
        guard let url = URL(string: "\(baseURL)/timecapsule/\(id)") else {
            return Fail(error: NetworkError.invalidURL).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown server error"
                    throw NetworkError.serverError(errorMessage)
                }
                return true
            }
            .mapError { error in
                if let networkError = error as? NetworkError {
                    return networkError
                }
                return NetworkError.requestFailed(error)
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Reminders
    func getLocationReminders() -> AnyPublisher<[LocationReminder], NetworkError> {
        guard let url = URL(string: "\(baseURL)/reminder/location") else {
            return Fail(error: NetworkError.invalidURL).eraseToAnyPublisher()
        }
        
        return URLSession.shared.dataTaskPublisher(for: url)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    throw NetworkError.invalidResponse
                }
                return data
            }
            .decode(type: [LocationReminder].self, decoder: JSONDecoder())
            .mapError { error in
                if let decodingError = error as? DecodingError {
                    return NetworkError.decodingFailed(decodingError)
                } else if let networkError = error as? NetworkError {
                    return networkError
                }
                return NetworkError.requestFailed(error)
            }
            .eraseToAnyPublisher()
    }
    
    func createLocationReminder(reminder: String, latitude: Double, longitude: Double, placeName: String, radius: Int = 100) -> AnyPublisher<ReminderResponse, NetworkError> {
        guard let url = URL(string: "\(baseURL)/reminder/location") else {
            return Fail(error: NetworkError.invalidURL).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "reminder": reminder,
            "latitude": latitude,
            "longitude": longitude,
            "place_name": placeName,
            "radius": radius
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 201 else {
                    let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown server error"
                    throw NetworkError.serverError(errorMessage)
                }
                return data
            }
            .decode(type: ReminderResponse.self, decoder: JSONDecoder())
            .mapError { error in
                if let decodingError = error as? DecodingError {
                    return NetworkError.decodingFailed(decodingError)
                } else if let networkError = error as? NetworkError {
                    return networkError
                }
                return NetworkError.requestFailed(error)
            }
            .eraseToAnyPublisher()
    }
    
    func deleteLocationReminder(id: Int) -> AnyPublisher<Bool, NetworkError> {
        guard let url = URL(string: "\(baseURL)/reminder/location/\(id)") else {
            return Fail(error: NetworkError.invalidURL).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown server error"
                    throw NetworkError.serverError(errorMessage)
                }
                return true
            }
            .mapError { error in
                if let networkError = error as? NetworkError {
                    return networkError
                }
                return NetworkError.requestFailed(error)
            }
            .eraseToAnyPublisher()
    }
    
    func updateUserLocation(latitude: Double, longitude: Double) -> AnyPublisher<LocationUpdateResponse, NetworkError> {
        guard let url = URL(string: "\(baseURL)/location/update") else {
            return Fail(error: NetworkError.invalidURL).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "latitude": latitude,
            "longitude": longitude
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown server error"
                    throw NetworkError.serverError(errorMessage)
                }
                return data
            }
            .decode(type: LocationUpdateResponse.self, decoder: JSONDecoder())
            .mapError { error in
                if let decodingError = error as? DecodingError {
                    return NetworkError.decodingFailed(decodingError)
                } else if let networkError = error as? NetworkError {
                    return networkError
                }
                return NetworkError.requestFailed(error)
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Places
    func searchPlaces(latitude: Double, longitude: Double, type: String = "restaurant", radius: Int = 1000) -> AnyPublisher<[Place], NetworkError> {
        guard var urlComponents = URLComponents(string: "\(baseURL)/places/search") else {
            return Fail(error: NetworkError.invalidURL).eraseToAnyPublisher()
        }
        
        urlComponents.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "type", value: type),
            URLQueryItem(name: "radius", value: String(radius))
        ]
        
        guard let url = urlComponents.url else {
            return Fail(error: NetworkError.invalidURL).eraseToAnyPublisher()
        }
        
        return URLSession.shared.dataTaskPublisher(for: url)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown server error"
                    throw NetworkError.serverError(errorMessage)
                }
                return data
            }
            .decode(type: [Place].self, decoder: JSONDecoder())
            .mapError { error in
                if let decodingError = error as? DecodingError {
                    return NetworkError.decodingFailed(decodingError)
                } else if let networkError = error as? NetworkError {
                    return networkError
                }
                return NetworkError.requestFailed(error)
            }
            .eraseToAnyPublisher()
    }
    
    func getPlaceDetails(placeId: String) -> AnyPublisher<PlaceDetail, NetworkError> {
        guard let url = URL(string: "\(baseURL)/places/detail/\(placeId)") else {
            return Fail(error: NetworkError.invalidURL).eraseToAnyPublisher()
        }
        
        return URLSession.shared.dataTaskPublisher(for: url)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown server error"
                    throw NetworkError.serverError(errorMessage)
                }
                return data
            }
            .decode(type: PlaceDetail.self, decoder: JSONDecoder())
            .mapError { error in
                if let decodingError = error as? DecodingError {
                    return NetworkError.decodingFailed(decodingError)
                } else if let networkError = error as? NetworkError {
                    return networkError
                }
                return NetworkError.requestFailed(error)
            }
            .eraseToAnyPublisher()
    }
    
    func geocodeAddress(address: String) -> AnyPublisher<GeocodingResult, NetworkError> {
        guard var urlComponents = URLComponents(string: "\(baseURL)/geocode") else {
            return Fail(error: NetworkError.invalidURL).eraseToAnyPublisher()
        }
        
        urlComponents.queryItems = [
            URLQueryItem(name: "address", value: address)
        ]
        
        guard let url = urlComponents.url else {
            return Fail(error: NetworkError.invalidURL).eraseToAnyPublisher()
        }
        
        return URLSession.shared.dataTaskPublisher(for: url)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown server error"
                    throw NetworkError.serverError(errorMessage)
                }
                return data
            }
            .decode(type: GeocodingResult.self, decoder: JSONDecoder())
            .mapError { error in
                if let decodingError = error as? DecodingError {
                    return NetworkError.decodingFailed(decodingError)
                } else if let networkError = error as? NetworkError {
                    return networkError
                }
                return NetworkError.requestFailed(error)
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Health Check
    func checkBackendHealth() -> AnyPublisher<HealthCheckResponse, NetworkError> {
        guard let url = URL(string: "\(baseURL)/health") else {
            return Fail(error: NetworkError.invalidURL).eraseToAnyPublisher()
        }
        
        return URLSession.shared.dataTaskPublisher(for: url)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    throw NetworkError.invalidResponse
                }
                return data
            }
            .decode(type: HealthCheckResponse.self, decoder: JSONDecoder())
            .mapError { error in
                if let decodingError = error as? DecodingError {
                    return NetworkError.decodingFailed(decodingError)
                } else if let networkError = error as? NetworkError {
                    return networkError
                }
                return NetworkError.requestFailed(error)
            }
            .eraseToAnyPublisher()
    }
}

// MARK: - NetworkError Enum
enum NetworkError: Error {
    case invalidURL
    case requestFailed(Error)
    case invalidResponse
    case decodingFailed(Error)
    case serverError(String)
    case unknown
}
