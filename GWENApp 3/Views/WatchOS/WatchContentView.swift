//
//  WatchContentView.swift
//  GWENAppWatchOS
//
//  Created by Manus on 5/14/25.
//

import SwiftUI

struct WatchContentView: View {
    var body: some View {
        TabView {
            WatchGwenChatView()
                .tabItem {
                    Label("GWEN", systemImage: "message.fill")
                }

            WatchTimeCapsuleView()
                .tabItem {
                    Label("Capsule", systemImage: "archivebox.fill") // Shorter label for Watch
                }

            WatchRemindersView()
                .tabItem {
                    Label("Reminders", systemImage: "list.bullet.rectangle.fill")
                }

            WatchPlacesView()
                .tabItem {
                    Label("Places", systemImage: "map.fill")
                }
        }
        // .tabViewStyle(.page(indexDisplayMode: .automatic)) // For swipe navigation
        // Note: For watchOS, TabView defaults to page-based navigation if not nested in NavigationView.
        // If direct views are used, this should work as expected for swiping.
    }
}

// MARK: - Placeholder WatchOS Views

struct WatchGwenChatView: View {
    // Will use a simplified version of GwenChatViewModel or a dedicated WatchOS one
    // @StateObject private var viewModel = GwenChatViewModel() // Or a WatchGwenChatViewModel
    var body: some View {
        // Simplified UI for GWEN interaction
        // Focus on voice input and quick display of last response
        VStack {
            Text("GWEN Chat")
            // Placeholder for microphone button and response display
            Image(systemName: "mic.fill")
                .font(.largeTitle)
                .padding()
            Text("Tap to speak to GWEN")
                .font(.caption)
        }
        .navigationTitle("GWEN") // This might not be visible depending on TabView style
    }
}

struct WatchTimeCapsuleView: View {
    // @StateObject private var viewModel = TimeCapsuleViewModel() // Or a WatchTimeCapsuleViewModel
    var body: some View {
        VStack {
            Text("Time Capsule")
            // Simplified UI for adding/viewing time capsules
            Image(systemName: "plus.circle.fill")
                .font(.largeTitle)
                .padding()
            Text("Add new entry")
                .font(.caption)
        }
    }
}

struct WatchRemindersView: View {
    // @StateObject private var viewModel = RemindersViewModel() // Or a WatchRemindersViewModel
    var body: some View {
        VStack {
            Text("Reminders")
            // Simplified UI for viewing upcoming/triggered reminders
            Image(systemName: "bell.fill")
                .font(.largeTitle)
                .padding()
            Text("View reminders")
                .font(.caption)
        }
    }
}

struct WatchPlacesView: View {
    // @StateObject private var viewModel = PlacesViewModel() // Or a WatchPlacesViewModel
    var body: some View {
        VStack {
            Text("Places")
            // Simplified UI for quick place searches
            Image(systemName: "location.magnifyingglass")
                .font(.largeTitle)
                .padding()
            Text("Search nearby")
                .font(.caption)
        }
    }
}


#Preview {
    WatchContentView()
}

