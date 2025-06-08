//
//  RemindersListView.swift
//  GWENApp
//
//  Created by Manus on 5/14/25.
//

import SwiftUI
import CoreLocation // For CLLocationCoordinate2D
import MapKit // For Map view if we add it

struct RemindersListView: View {
    @StateObject private var viewModel = RemindersViewModel()
    @State private var showingAddSheet = false

    var body: some View {
        NavigationView {
            VStack {
                // Display triggered reminders prominently if any
                if !viewModel.triggeredReminders.isEmpty {
                    Section(header: Text("Triggered Reminders!").font(.headline).foregroundColor(.orange)) {
                        List(viewModel.triggeredReminders) { reminder in
                            ReminderRow(reminder: reminder, isTriggered: true)
                        }
                        .frame(maxHeight: 200) // Limit height of triggered reminders list
                    }
                }
                
                if viewModel.isLoading && viewModel.reminders.isEmpty {
                    ProgressView("Loading Reminders...")
                } else if let errorMessage = viewModel.errorMessage {
                    Text("Error: \(errorMessage)")
                        .foregroundColor(.red)
                        .padding()
                    Button("Retry") {
                        viewModel.fetchReminders()
                    }
                } else if viewModel.reminders.isEmpty {
                    Text("No active location reminders. Tap + to add one!")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    List {
                        ForEach(viewModel.reminders) { reminder in
                            ReminderRow(reminder: reminder)
                        }
                    }
                }
            }
            .navigationTitle("Location Reminders")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    if viewModel.isLoading {
                        ProgressView()
                    } else {
                        Button {
                            viewModel.fetchReminders() // Manual refresh
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddReminderView()
                    .environmentObject(viewModel)
            }
            .onAppear {
                // Fetch reminders when the view appears
                // Backend doesn_t currently have a GET /reminders/location endpoint
                // So, fetchReminders() will print a warning and return an empty array.
                // This UI is built assuming the endpoint could be added later.
                if viewModel.reminders.isEmpty {
                    viewModel.fetchReminders()
                }
                viewModel.requestLocationAccessIfNeeded()
                viewModel.startMonitoringLocation() // Start monitoring when view appears
            }
            .onDisappear {
                // viewModel.stopMonitoringLocation() // Stop monitoring when view disappears, or manage based on app state
            }
        }
    }
}

struct ReminderRow: View {
    let reminder: LocationReminder
    var isTriggered: Bool = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text(reminder.note)
                    .font(.headline)
                    .foregroundColor(isTriggered ? .orange : .primary)
                Text("At: \(reminder.place)")
                    .font(.subheadline)
                Text("Set: \(reminder.displayDate)")
                    .font(.footnote)
                    .foregroundColor(.gray)
                Text("Coords: Lat \(String(format: "%.4f", reminder.lat)), Lon \(String(format: "%.4f", reminder.lon))")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            if isTriggered {
                Spacer()
                Image(systemName: "bell.badge.fill")
                    .foregroundColor(.orange)
                    .font(.title2)
            }
        }
        .padding(.vertical, 4)
    }
}

struct AddReminderView: View {
    @EnvironmentObject var viewModel: RemindersViewModel
    @Environment(\.dismiss) var dismiss
    
    // For map interaction if we add it
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.334_900, longitude: -122.009_020), // Default to Apple Park
        span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
    )
    @State private var selectedCoordinates: CLLocationCoordinate2D? = nil

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("New Location Reminder")) {
                    TextField("Note (e.g., Buy milk)", text: $viewModel.newReminderNote)
                    TextField("Place Name (e.g., Grocery Store)", text: $viewModel.newReminderPlace)
                    
                    // Simple Coordinate Input (can be enhanced with a map view)
                    VStack(alignment: .leading) {
                        Text("Location Coordinates:")
                            .font(.caption)
                        if let coords = viewModel.newReminderCoordinates {
                            Text("Lat: \(coords.latitude), Lon: \(coords.longitude)")
                        } else {
                            Text("Tap on map or enter manually (coming soon)")
                                .foregroundColor(.gray)
                        }
                        // Basic Map for selection - can be made more interactive
                        Map(coordinateRegion: $region, interactionModes: .all, showsUserLocation: true, annotationItems: [IdentifiableCoordinate(coord: selectedCoordinates)]) {
                            item in MapMarker(coordinate: item.coord, tint: .blue)
                        }
                        .frame(height: 200)
                        .onTapGesture(perform: {
                            // This tap gesture on the map itself is not ideal for precise point selection.
                            // A better approach would be a draggable pin or a search bar for places.
                            // For now, let_s use the map_s center as the selected point if user interacts.
                            // This is a placeholder for better map interaction.
                        })
                        .overlay(alignment: .center) {
                             Image(systemName: "plus.circle.fill") // Center marker
                                 .foregroundColor(.red)
                                 .opacity(0.5)
                                 .allowsHitTesting(false)
                        }
                        Button("Set Location to Map Center") {
                            viewModel.newReminderCoordinates = region.center
                            selectedCoordinates = region.center
                        }
                        .padding(.top, 5)
                    }
                }

                Section {
                    Button(action: {
                        viewModel.addReminder()
                    }) {
                        HStack {
                            Spacer()
                            if viewModel.isLoading {
                                ProgressView()
                            } else {
                                Text("Save Reminder")
                            }
                            Spacer()
                        }
                    }
                    .disabled(viewModel.newReminderNote.isEmpty || viewModel.newReminderPlace.isEmpty || viewModel.newReminderCoordinates == nil || viewModel.isLoading)
                }
                
                if let errorMessage = viewModel.errorMessage {
                    Section {
                        Text("Error: \(errorMessage)")
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Add Reminder")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear { viewModel.errorMessage = nil }
            .onChange(of: viewModel.reminders.count) { _, _ in
                if !viewModel.isLoading {
                    dismiss()
                }
            }
        }
    }
}

// Helper for map annotations
struct IdentifiableCoordinate: Identifiable {
    let id = UUID()
    var coord: CLLocationCoordinate2D
    init?(coord: CLLocationCoordinate2D?) {
        guard let coord = coord else { return nil }
        self.coord = coord
    }
}

#Preview {
    RemindersListView()
}

