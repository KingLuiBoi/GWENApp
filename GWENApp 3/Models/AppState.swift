import Foundation
import SwiftUI
import AVFoundation
import Speech
import CoreLocation

class AppState: ObservableObject {
    @Published var isFirstLaunch: Bool = false  // Set to false to skip onboarding for now
    @Published var hasCompletedOnboarding: Bool = true  // Set to true to skip onboarding for now
    @Published var isBackendConnected: Bool = false
    @Published var hasRequiredPermissions: Bool = false
    
    init() {
        checkPermissions()
    }
    
    private func checkPermissions() {
        let micPermission = AVAudioSession.sharedInstance().recordPermission
        let speechPermission = SFSpeechRecognizer.authorizationStatus()
        let locationPermission = CLLocationManager().authorizationStatus
        
        hasRequiredPermissions = (micPermission == .granted &&
                                speechPermission == .authorized &&
                                (locationPermission == .authorizedWhenInUse || locationPermission == .authorizedAlways))
    }
    
    func completeOnboarding() {
        hasCompletedOnboarding = true
        checkPermissions()
    }
    
    func setBackendConnectionStatus(_ connected: Bool) {
        isBackendConnected = connected
    }
}
