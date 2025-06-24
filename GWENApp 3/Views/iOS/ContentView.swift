import SwiftUI

struct ContentView: View {
    @StateObject private var networkingService = NetworkingService.shared
    @StateObject private var locationService = LocationService.shared
    @StateObject private var voiceInputService = VoiceInputService.shared
    @StateObject private var audioPlaybackService = AudioPlaybackService.shared
    @EnvironmentObject var appState: AppState

    @State private var selectedTab = 0
    @State private var showingPermissionsAlert = false
    @State private var showingBackendError = false
    @State private var backendHealthy = false

    var body: some View {
        Group {
            if appState.isFirstLaunch && !appState.hasCompletedOnboarding {
                OnboardingView()
            } else {
                mainTabView
            }
        }
        .onAppear {
            if appState.hasCompletedOnboarding {
                checkPermissionsAndBackend()
            }
        }
        .alert("Permissions Required", isPresented: $showingPermissionsAlert) {
            Button("Settings") {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("GWEN needs microphone and location permissions to function properly.")
        }
        .alert("Backend Connection Error", isPresented: $showingBackendError) {
            Button("Retry") {
                checkBackendHealth()
            }
            Button("Continue Offline", role: .cancel) { }
        } message: {
            Text("Cannot connect to GWEN backend. Please ensure the Flask server is running at \(AppConfig.backendURL)")
        }
    }

    private var mainTabView: some View {
        TabView(selection: $selectedTab) {
            GwenChatView()
                .tabItem {
                    Image(systemName: "message.circle.fill")
                    Text("GWEN")
                }
                .tag(0)

            TimeCapsuleListView()
                .tabItem {
                    Image(systemName: "clock.circle.fill")
                    Text("Time Capsule")
                }
                .tag(1)

            RemindersListView()
                .tabItem {
                    Image(systemName: "location.circle.fill")
                    Text("Reminders")
                }
                .tag(2)

            PlacesView()
                .tabItem {
                    Image(systemName: "map.circle.fill")
                    Text("Places")
                }
                .tag(3)
        }
        .accentColor(.blue)
    }

    private func checkPermissionsAndBackend() {
        checkPermissions()
        checkBackendHealth()

        let authStatus = locationService.authorizationStatus
        if authStatus == .authorizedWhenInUse || authStatus == .authorizedAlways {
            voiceInputService.startWakeWordDetection()
        }
    }

    private func checkPermissions() {
        let authStatus = locationService.authorizationStatus

        if authStatus == .notDetermined {
            locationService.requestLocationPermissions()
        }

        voiceInputService.requestPermissions()

        if authStatus == .denied || authStatus == .restricted {
            showingPermissionsAlert = true
        }
    }

    private func checkBackendHealth() {
        Task {
            do {
                let health = try await networkingService.checkBackendHealth()
                await MainActor.run {
                    backendHealthy = health.isHealthy
                    appState.setBackendConnectionStatus(health.isHealthy)

                    if !health.isHealthy {
                        showingBackendError = true
                    }
                }
            } catch {
                await MainActor.run {
                    backendHealthy = false
                    appState.setBackendConnectionStatus(false)
                    showingBackendError = true
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}

