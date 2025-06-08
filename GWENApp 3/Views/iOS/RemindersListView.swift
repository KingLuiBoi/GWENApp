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
                        .onDelete(perform: viewModel.deleteReminder) // Added swipe to delete
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
    @State private var showingLocationPicker = false // To toggle the map picker sheet

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("New Location Reminder")) {
                    TextField("Note (e.g., Buy milk)", text: $viewModel.newReminderNote)
                    
                    HStack {
                        TextField("Place Name (e.g., Grocery Store)", text: $viewModel.newReminderPlace)
                        Button {
                            viewModel.mapSearchResults = [] // Clear previous search results before showing picker
                            showingLocationPicker = true
                        } label: {
                            Image(systemName: "map.fill")
                        }
                        .disabled(viewModel.locationService.authorizationStatus == .denied)
                    }

                    if let coords = viewModel.newReminderCoordinates {
                        Text("Selected: Lat \(String(format: "%.4f", coords.latitude)), Lon \(String(format: "%.4f", coords.longitude))")
                            .font(.caption)
                        if !viewModel.newReminderPlace.isEmpty {
                             Text("Place: \(viewModel.newReminderPlace)")
                                .font(.caption)
                        }
                    } else {
                        Text("No location selected. Tap the map icon to choose.")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }

                Section {
                    Button(action: {
                        viewModel.addReminder() // ViewModel should handle success and error, then UI updates
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
            .onAppear {
                viewModel.errorMessage = nil // Clear previous errors
                viewModel.addReminderSuccess = false // Reset success flag
            }
            .onChange(of: viewModel.addReminderSuccess) { newValue in // Changed from oldValue, newValue to just newValue for clarity
                if newValue { // If addReminder was successful
                    dismiss()
                    viewModel.addReminderSuccess = false // Reset the flag
                }
            }
            .sheet(isPresented: $showingLocationPicker) {
                LocationPickerView()
                    .environmentObject(viewModel) // Pass the ViewModel
            }
        }
    }
}

// IdentifiableCoordinate struct removed as it's no longer used by the current map implementation.
// MKMapItem is made Identifiable via an extension in PlacesSearchView.swift for map annotations.

#Preview {
    RemindersListView()
}


// MARK: - LocationPickerView (New View)

struct LocationPickerView: View {
    @EnvironmentObject var viewModel: RemindersViewModel
    @Environment(\.dismiss) var dismiss

    // No need for @State region if viewModel.region is used directly.
    @State private var localSearchQuery: String = "" // Keep localSearchQuery for TextField binding

    var body: some View {
        NavigationView {
            VStack {
                // Search bar for locations
                HStack {
                    TextField("Search for a place", text: $localSearchQuery, onCommit: {
                        viewModel.searchQuery = localSearchQuery // Update viewModel's query
                        viewModel.searchLocations() // Use existing VM method
                    })
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    Button {
                        viewModel.searchQuery = localSearchQuery
                        viewModel.searchLocations()
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                }
                .padding()

                // Map view
                ZStack(alignment: .bottom) {
                    // Use viewModel.region, viewModel.searchResults
                    Map(coordinateRegion: $viewModel.region, showsUserLocation: true, annotationItems: viewModel.searchResults) { item in
                        MapAnnotation(coordinate: item.placemark.coordinate) {
                            VStack { // Added VStack for better annotation appearance
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundColor(.red)
                                Text(item.name ?? "")
                                    .font(.caption)
                                    .fixedSize(horizontal: true, vertical: false) // Prevent text from causing excessive height
                            }
                            .onTapGesture {
                                viewModel.selectMapItem(item) // Use existing VM method
                                dismiss() // Dismiss after selection
                            }
                        }
                    }
                    // onTapGesture for direct map tap is complex; "Confirm Map Center" is a good alternative.

                    if viewModel.isLoading { // Use viewModel.isLoading
                        ProgressView("Searching...")
                            .padding()
                            .background(Color.secondary.opacity(0.5)) // Updated background for better visibility
                            .cornerRadius(10)
                    }

                    Button("Confirm Map Center") {
                        let centerCoordinate = viewModel.region.center
                        // Reverse geocode to get a place name
                        let geocoder = CLGeocoder()
                        geocoder.reverseGeocodeLocation(CLLocation(latitude: centerCoordinate.latitude, longitude: centerCoordinate.longitude)) { placemarks, error in
                            let name = placemarks?.first?.name ?? placemarks?.first?.locality ?? "Selected Location"
                            viewModel.selectLocation(centerCoordinate, placeName: name) // Use updated VM method
                            dismiss()
                        }
                    }
                    .padding()
                    .buttonStyle(.borderedProminent) // Modern button style
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Select Location")
            .toolbar { // Use .toolbar for modern NavigationBarItems
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                 // ViewModel's region should be up-to-date via its own location service subscription.
                 // Clear previous search results and query.
                 viewModel.searchResults = []
                 viewModel.searchQuery = "" // Clear search query on appear
                 localSearchQuery = ""   // Clear local search query too
            }
        }
    }
}
