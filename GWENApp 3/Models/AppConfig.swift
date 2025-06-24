import Foundation

struct AppConfig {
    static let defaultBackendURL = "http://127.0.0.1:5050"
    
    static var backendURL: String {
        return UserDefaults.standard.string(forKey: "BackendURL") ?? defaultBackendURL
    }
    
    static func setBackendURL(_ url: String) {
        UserDefaults.standard.set(url, forKey: "BackendURL")
    }
    
    static let enableLogging = true
}
