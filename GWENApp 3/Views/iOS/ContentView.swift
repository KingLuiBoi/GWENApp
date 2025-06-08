//
//  ContentView.swift
//  GWENApp
//
//  Created by Manus on 5/14/25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            GwenChatView()
                .tabItem {
                    Label("GWEN", systemImage: "message.fill")
                }

            TimeCapsuleListView()
                .tabItem {
                    Label("Time Capsule", systemImage: "archivebox.fill")
                }

            RemindersListView()
                .tabItem {
                    Label("Reminders", systemImage: "list.bullet.rectangle.fill")
                }

            PlacesSearchView()
                .tabItem {
                    Label("Places", systemImage: "map.fill")
                }
            
            // Future Settings Screen
            // SettingsView()
            //     .tabItem {
            //         Label("Settings", systemImage: "gear")
            //     }
        }
    }
}

// Placeholder Views for other main features (iOS)

struct TimeCapsuleListView: View {
    // @StateObject private var viewModel = TimeCapsuleViewModel()
    var body: some View {
        NavigationView {
            Text("Time Capsule Feature - Coming Soon")
                .navigationTitle("Time Capsule")
        }
    }
}

struct RemindersListView: View {
    // @StateObject private var viewModel = RemindersViewModel()
    var body: some View {
        NavigationView {
            Text("Reminders Feature - Coming Soon")
                .navigationTitle("Reminders")
        }
    }
}

struct PlacesSearchView: View {
    // @StateObject private var viewModel = PlacesViewModel()
    var body: some View {
        NavigationView {
            Text("Places Search Feature - Coming Soon")
                .navigationTitle("Places")
        }
    }
}

// struct SettingsView: View {
//     var body: some View {
//         NavigationView {
//             Text("Settings - Coming Soon")
//                 .navigationTitle("Settings")
//         }
//     }
// }

#Preview {
    ContentView()
}

