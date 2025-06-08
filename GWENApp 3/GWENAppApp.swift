//
//  GWENAppApp.swift
//  GWENApp
//
//  Created by Manus on 5/14/25.
//

import SwiftUI

@main
struct GWENAppApp: App {
    // Initialize services here if they need to be app-wide singletons
    // and are not already handled by their own static shared instances.
    // For example, requesting permissions early.
    
    init() {
        // You might want to request permissions early in the app lifecycle
        // or let individual views/viewmodels handle it when features are accessed.
        // VoiceInputService.shared.requestPermissions()
        // LocationService.shared.requestLocationPermissions()
    }

    var body: some Scene {
        WindowGroup {
            // This will be the main entry point for the iOS app.
            // We can start with GwenChatView or a more complex TabView later.
            ContentView() // Let's create a ContentView that can host the TabView
        }
    }
}

// ContentView will act as the root view, potentially holding a TabView for different sections.
struct ContentView: View {
    var body: some View {
        // For now, let's directly show GwenChatView.
        // Later, this can be replaced with a TabView to navigate to other features
        // like Time Capsule, Reminders, Places as per the architecture.
        GwenChatView()
    }
}

