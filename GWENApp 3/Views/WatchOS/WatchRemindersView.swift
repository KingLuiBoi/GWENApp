//
//  WatchRemindersView.swift
//  GWENAppWatchOS
//
//  Created by Manus on 5/15/25.
//

import SwiftUI
import MapKit

struct WatchRemindersView: View {
    @StateObject private var viewModel = RemindersViewModel()
    @State private var showingAddSheet = false
    
    var body: some View {
        VStack {
            // Map showing reminders
            Map(coordinateRegion: $viewModel.region,
                showsUserLocation: true,
                userTrackingMode: .constant(.none),
                annotationItems: viewModel.reminders.compactMap { reminder in
                    guard let lat = Double(reminder.lat), let lon = Double(reminder.lon) else { return nil }
                    return ReminderAnnotation(id: reminder.id, reminder: reminder, coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon))
                }) { annotation in
                    MapAnnotation(coordinate: annotation.coordinate) {
                        VStack {
                            Image(systemName: "bell.fill")
                                .foregroundColor(.red)
                                .font(.headline)
                            Text(annotation.reminder.place)
                                .font(.caption2)
                                .background(Color.black.opacity(0.5))
                                .foregroundColor(.white)
                                .cornerRadius(4)
                        }
                    }
                }
            .edgesIgnoringSafeArea(.all)
            .frame(height: 120)
            
            // Add Reminder Button
            Button {
                showingAddSheet = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle")
                    Text("Add Reminder")
                }
                .padding(8)
                .background(Color.blue.opacity(0.3))
                .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.top, 5)
            
            // Reminders List
            if viewModel.isLoading {
                ProgressView()
                    .padding(.top, 5)
            } else if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.caption2)
                    .foregroundColor(.red)
                    .padding(.top, 5)
            } else if viewModel.reminders.isEmpty {
                Text("No reminders yet")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.top, 5)
            } else {
                List {
                    ForEach(viewModel.reminders.prefix(5)) { reminder in
                        WatchReminderRow(reminder: reminder)
                    }
                }
                .frame(height: 100) // Limit height for watch
            }
        }
        .navigationTitle("Reminders")
        .onAppear {
            viewModel.requestLocationAccessIfNeeded()
            viewModel.fetchReminders()
        }
        .sheet(isPresented: $showingAddSheet) {
            WatchAddReminderView(viewModel: viewModel)
        }
    }
}

struct WatchReminderRow: View {
    let reminder: LocationReminder
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(reminder.note)
                .font(.caption)
                .lineLimit(1)
            Text(reminder.place)
                .font(.caption2)
                .foregroundColor(.gray)
                .lineLimit(1)
        }
        .padding(.vertical, 2)
    }
}

struct WatchAddReminderView: View {
    @ObservedObject var viewModel: RemindersViewModel
    @Environment(\.dismiss) var dismiss
    @State private var showingLocationPicker = false
    
    var body: some View {
        VStack {
            TextField("Note", text: $viewModel.newReminderNote)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
            
            TextField("Place", text: $viewModel.newReminderPlace)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
            
            // Location Selection
            if viewModel.newReminderCoordinates != nil {
                HStack {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(.red)
                    Text("Location set")
                        .font(.caption)
                    
                    Button("Change") {
                        showingLocationPicker = true
                    }
                    .font(.caption)
                }
                .padding(.top, 5)
            } else {
                Button("Select Location") {
                    showingLocationPicker = true
                }
                .padding(.top, 5)
            }
            
            // Add Button
            Button("Add Reminder") {
                viewModel.addReminder()
                dismiss()
            }
            .disabled(viewModel.newReminderNote.isEmpty || viewModel.newReminderPlace.isEmpty || viewModel.newReminderCoordinates == nil)
            .padding(.top, 10)
            
            // Cancel Button
            Button("Cancel") {
                dismiss()
            }
            .padding(.top, 5)
        }
        .padding()
        .navigationTitle("New Reminder")
        .sheet(isPresented: $showingLocationPicker) {
            WatchLocationPickerView(viewModel: viewModel)
        }
    }
}

struct WatchLocationPickerView: View {
    @ObservedObject var viewModel: RemindersViewModel
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    
    var body: some View {
        VStack {
            // Map for location selection
            Map(coordinateRegion: $viewModel.region,
                showsUserLocation: true,
                userTrackingMode: .constant(.none))
            .edgesIgnoringSafeArea(.all)
            .frame(height: 120)
            .overlay(
                Image(systemName: "mappin.circle.fill")
                    .foregroundColor(.red)
                    .font(.title3),
                alignment: .center
            )
            
            // Search field
            TextField("Search location", text: $searchText, onCommit: {
                viewModel.searchQuery = searchText
                viewModel.searchLocations()
            })
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .padding(.horizontal)
            
            // Search results
            if !viewModel.searchResults.isEmpty {
                List {
                    ForEach(viewModel.searchResults, id: \.self) { mapItem in
                        Button(action: {
                            viewModel.selectMapItem(mapItem)
                            dismiss()
                        }) {
                            Text(mapItem.name ?? "Unknown Location")
                                .font(.caption)
                                .lineLimit(1)
                        }
                    }
                }
                .frame(height: 80)
            }
            
            // Select current location button
            Button("Use Map Center") {
                viewModel.selectLocation(viewModel.region.center)
                dismiss()
            }
            .padding(.top, 5)
            
            // Cancel button
            Button("Cancel") {
                dismiss()
            }
            .padding(.top, 5)
        }
        .navigationTitle("Pick Location")
    }
}

// Helper struct for map annotations
struct ReminderAnnotation: Identifiable {
    let id: String
    let reminder: LocationReminder
    let coordinate: CLLocationCoordinate2D
}

#Preview {
    WatchRemindersView()
}
