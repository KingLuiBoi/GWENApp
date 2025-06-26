//
//  RemindersListView.swift
//  GWENApp
//
//  Created by Manus on 5/14/25.
//

import SwiftUI
import CoreLocation // For CLLocationCoordinate2D
import MapKit // For Map view if we add it

extension MKMapItem: Identifiable {
    public var id: String { self.placemark.coordinate.latitude.description + "," + self.placemark.coordinate.longitude.description + (self.name ?? "") }
}

struct RemindersListView: View {
    @StateObject private var viewModel = RemindersViewModel()
    @State private var showingAddSheet = false

    var body: some View {
        NavigationStack {
            VStack {
                if !viewModel.triggeredReminders.isEmpty {
                    TriggeredRemindersList(reminders: viewModel.triggeredReminders)
                }
                MainRemindersList(reminders: viewModel.reminders)
                AddReminderButtonSection(showingAddSheet: $showingAddSheet)
            }
            .navigationTitle("Reminders")
        }
    }
}

private struct TriggeredRemindersList: View {
    let reminders: [LocationReminder]
    var body: some View {
        Section(header: Text("Triggered Reminders!").font(.headline).foregroundColor(.orange)) {
            List(reminders) { reminder in
                ReminderRow(reminder: reminder, isTriggered: true)
            }
            .frame(maxHeight: 200)
        }
    }
}

private struct MainRemindersList: View {
    let reminders: [LocationReminder]
    var body: some View {
        Section(header: Text("All Reminders")) {
            List(reminders) { reminder in
                ReminderRow(reminder: reminder, isTriggered: false)
            }
        }
    }
}

private struct AddReminderButtonSection: View {
    @Binding var showingAddSheet: Bool
    var body: some View {
        Button(action: {
            showingAddSheet = true
        }) {
            Label("Add Reminder", systemImage: "plus")
        }
        .buttonStyle(.borderedProminent)
        .padding()
        .sheet(isPresented: $showingAddSheet) {
            AddReminderView()
                .environmentObject(RemindersViewModel())
        }
    }
}

struct ReminderRow: View {
    let reminder: LocationReminder
    var isTriggered: Bool = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text(reminder.reminder)
                    .font(.headline)
                    .foregroundColor(isTriggered ? .orange : .primary)
                Text("At: \(reminder.place_name)")
                    .font(.subheadline)
                Text("Set: \(reminder.createdDate, style: .date)")
                    .font(.footnote)
                    .foregroundColor(.gray)
                Text("Coords: Lat \(String(format: "%.4f", reminder.latitude)), Lon \(String(format: "%.4f", reminder.longitude))")
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
    @State private var showingLocationPicker = false

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("New Location Reminder")) {
                    TextField("Note (e.g., Buy milk)", text: $viewModel.newReminderNote)
                    
                    HStack {
                        TextField("Place Name (e.g., Grocery Store)", text: $viewModel.newReminderPlace)
                        Button {
                            viewModel.searchResults = []
                            showingLocationPicker = true
                        } label: {
                            Image(systemName: "map.fill")
                        }
                        .disabled(viewModel.isLocationDenied)
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
            .onAppear {
                viewModel.errorMessage = nil
                viewModel.addReminderSuccess = false
            }
            .onChange(of: viewModel.addReminderSuccess) { _, newValue in
                if newValue {
                    dismiss()
                    viewModel.addReminderSuccess = false
                }
            }
            .sheet(isPresented: $showingLocationPicker) {
                LocationPickerView()
                    .environmentObject(viewModel)
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

    @State private var localSearchQuery: String = ""

    var body: some View {
        NavigationStack {
            VStack {
                searchBar
                ZStack(alignment: .bottom) {
                    mapView
                    if viewModel.isLoading {
                        loadingView
                    }
                    confirmButton
                }
            }
            .navigationTitle("Select Location")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                viewModel.searchResults = []
                viewModel.searchQuery = ""
                localSearchQuery = ""
            }
        }
    }

    private var searchBar: some View {
        HStack {
            TextField("Search for a place", text: $localSearchQuery, onCommit: {
                viewModel.searchQuery = localSearchQuery
                viewModel.searchLocationsForPicker()
            })
            .textFieldStyle(RoundedBorderTextFieldStyle())
            Button {
                viewModel.searchQuery = localSearchQuery
                viewModel.searchLocationsForPicker()
            } label: {
                Image(systemName: "magnifyingglass")
            }
        }
        .padding()
    }

    private var mapView: some View {
        Map(coordinateRegion: $viewModel.region, showsUserLocation: true, annotationItems: viewModel.searchResults) { item in
            MapAnnotation(coordinate: item.placemark.coordinate) {
                VStack {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(.red)
                        .font(.title)
                    Text(item.name ?? "")
                        .font(.caption)
                        .fixedSize(horizontal: true, vertical: false)
                }
                .onTapGesture {
                    viewModel.selectMapItemForReminder(item)
                    dismiss()
                }
            }
        }
    }

    private var loadingView: some View {
        ProgressView("Searching...")
            .padding()
            .background(Color.secondary.opacity(0.5))
            .cornerRadius(10)
    }

    private var confirmButton: some View {
        Button("Confirm Map Center") {
            let centerCoordinate = viewModel.region.center
            let geocoder = CLGeocoder()
            geocoder.reverseGeocodeLocation(CLLocation(latitude: centerCoordinate.latitude, longitude: centerCoordinate.longitude)) { placemarks, error in
                let name = placemarks?.first?.name ?? placemarks?.first?.locality ?? "Selected Location"
                viewModel.selectCoordinatesForReminder(centerCoordinate, placeNameFromReverseGeocode: name)
                dismiss()
            }
        }
        .padding()
        .buttonStyle(.borderedProminent)
        .padding(.bottom, 30)
    }
}


