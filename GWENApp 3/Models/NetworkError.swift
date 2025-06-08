import Foundation

enum NetworkError: Error, LocalizedError { // Added LocalizedError for better descriptions
    case invalidURL
    case requestFailed(Error)
    case invalidResponse
    case decodingFailed(Error)
    case serverError(String)
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The URL provided was invalid."
        case .requestFailed(let error):
            return "The network request failed: \(error.localizedDescription)"
        case .invalidResponse:
            return "The server returned an invalid response."
        case .decodingFailed(let error):
            // Provide more context for decoding errors if possible
            if let decodingError = error as? DecodingError {
                var context = "Decoding failed."
                switch decodingError {
                case .typeMismatch(let type, let contextPath):
                    context += " Type mismatch for type \(type) at path \(contextPath.codingPath.map { $0.stringValue }.joined(separator: "."))."
                case .valueNotFound(let type, let contextPath):
                    context += " Value not found for type \(type) at path \(contextPath.codingPath.map { $0.stringValue }.joined(separator: "."))."
                case .keyNotFound(let key, let contextPath):
                    context += " Key not found: \(key.stringValue) at path \(contextPath.codingPath.map { $0.stringValue }.joined(separator: "."))."
                case .dataCorrupted(let contextPath):
                    context += " Data corrupted at path \(contextPath.codingPath.map { $0.stringValue }.joined(separator: ".")). \(contextPath.debugDescription)"
                @unknown default:
                    context += " Unknown decoding error."
                }
                return context
            }
            return "Failed to decode the server response: \(error.localizedDescription)"
        case .serverError(let message):
            return "Server error: \(message)"
        case .unknown:
            return "An unknown network error occurred."
        }
    }
}
