//
//  RemindersViewModel.swift
//  GWENApp
//
//  Created by Manus on 5/14/25.
//

import Foundation
import Combine
import CoreLocation
import MapKit

class RemindersViewModel: ObservableObject {
    @Published var reminders: [LocationReminder] = []
    @Published var triggeredReminders: [LocationReminder] = [] // For reminders triggered by location updates
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    // For creating a new reminder
    @Published var newReminderPlace: String = ""
    @Published var newReminderNote: String = ""
    @Published var newReminderCoordinates: CLLocationCoordinate2D? = nil // User might pick from a map or enter manually
    
    // MapKit related properties
    @Published var region: MKCoordinateRegion
    @Published var searchResults: [MKMapItem] = []
    @Published var searchQuery: String = ""
    @Published var showLocationPicker: Bool = false
    @Published var selectedMapItem: MKMapItem?
    @Published var addReminderSuccess: Bool = false // For UI to react to successful save

    private let networkingService: NetworkingServiceProtocol
    private let locationService: LocationServiceProtocol
    private let mapKitService: MapKitServiceProtocol
    private var cancellables = Set<AnyCancellable>()

    init(
        networkingService: NetworkingServiceProtocol = NetworkingService.shared,
        locationService: LocationServiceProtocol = LocationService.shared,
        mapKitService: MapKitServiceProtocol = MapKitService.shared
    ) {
        self.networkingService = networkingService
        self.locationService = locationService
        self.mapKitService = mapKitService
        
        // Initialize with a default region (will be updated with user's location)
        self.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194), // Default to San Francisco
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
        
        subscribeToLocationUpdates()
    }

    private func subscribeToLocationUpdates() {
        locationService.currentLocation
            .compactMap { $0 } // Ignore nil values
            .sink { [weak self] coordinates in
                guard let self = self else { return }
                
                // Update the map region to center on the user's location
                self.region = MKCoordinateRegion(
                    center: coordinates,
                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                )
                
                // Check for nearby reminders
                self.checkLocationForTriggers(coordinates: coordinates)
            }
            .store(in: &cancellables)
            
        locationService.authorizationStatus
            .sink { [weak self] status in
                if status == .authorizedWhenInUse || status == .authorizedAlways {
                    self?.locationService.startUpdatingLocation()
                } else {
                    self?.locationService.stopUpdatingLocation()
                    // Optionally inform user if permissions change and affect functionality
                }
            }
            .store(in: &cancellables)
    }

    func fetchReminders() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let fetchedReminders = try await networkingService.fetchLocationReminders()
                DispatchQueue.main.async {
                    self.reminders = fetchedReminders.sorted(by: { $0.timestamp > $1.timestamp })
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.errorMessage = "Failed to fetch reminders: \(error.localizedDescription)"
                    print("Error fetching reminders: \(error)")
                }
            }
        }
    }

    func addReminder() {
        guard !newReminderPlace.isEmpty, !newReminderNote.isEmpty, let coordinates = newReminderCoordinates else {
            errorMessage = "Place, note, and coordinates are required for a reminder."
            return
        }
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let newReminder = try await networkingService.createLocationReminder(
                    place: newReminderPlace,
                    lat: coordinates.latitude,
                    lon: coordinates.longitude,
                    note: newReminderNote
                )
                DispatchQueue.main.async {
                    self.reminders.insert(newReminder, at: 0)
                    self.reminders.sort(by: { $0.timestamp > $1.timestamp })
                    self.newReminderPlace = ""
                    self.newReminderNote = ""
                    self.newReminderCoordinates = nil
                    self.selectedMapItem = nil
                    self.isLoading = false
                    self.addReminderSuccess = true // Signal success to UI
                }
            } catch {
                DispatchQueue.main.async {
                    self.addReminderSuccess = false // Ensure it's false on error
                    self.isLoading = false
                    self.errorMessage = "Failed to add reminder: \(error.localizedDescription)"
                    print("Error adding reminder: \(error)")
                }
            }
        }
    }

    func checkLocationForTriggers(coordinates: CLLocationCoordinate2D) {
        // This function is called when location updates.
        // It will call the backend to see if any reminders are triggered.
        print("Checking for location triggers at lat: \(coordinates.latitude), lon: \(coordinates.longitude)")
        Task {
            do {
                let triggered = try await networkingService.updateUserLocation(lat: coordinates.latitude, lon: coordinates.longitude)
                DispatchQueue.main.async {
                    self.triggeredReminders = triggered
                    if !triggered.isEmpty {
                        // Handle triggered reminders - e.g., show a notification, update UI
                        print("Triggered reminders: \(triggered.map { $0.note })")
                        // You might want to present these to the user prominently.
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    // Don't necessarily show an error for background checks unless it's persistent
                    print("Error checking location triggers: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func searchLocations() {
        guard !searchQuery.isEmpty else {
            errorMessage = "Please enter a location to search."
            searchResults = []
            return
        }
        
        guard let coordinates = locationService.currentLocation.value else {
            errorMessage = "Could not determine your current location. Please ensure location services are enabled."
            if locationService.authorizationStatus.value == .authorizedWhenInUse || locationService.authorizationStatus.value == .authorizedAlways {
                locationService.startUpdatingLocation()
            } else {
                locationService.requestLocationPermissions()
            }
            searchResults = []
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        mapKitService.searchForPlaces(near: coordinates, query: searchQuery)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.isLoading = false
                        self?.errorMessage = "Failed to search locations: \(error.localizedDescription)"
                        self?.searchResults = []
                    }
                },
                receiveValue: { [weak self] mapItems in
                    guard let self = self else { return }
                    self.isLoading = false
                    self.searchResults = mapItems
                    
                    if mapItems.isEmpty {
                        self.errorMessage = "No locations found matching your query."
                    } else {
                        // Update the map region to show all results
                        if let firstItem = mapItems.first {
                            self.region = MKCoordinateRegion(
                                center: firstItem.placemark.coordinate,
                                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                            )
                        }
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    func selectMapItem(_ mapItem: MKMapItem) {
        self.selectedMapItem = mapItem
        self.newReminderCoordinates = mapItem.placemark.coordinate
        self.newReminderPlace = mapItem.name ?? "Selected Location"
        self.showLocationPicker = false
    }
    
    func selectLocation(_ coordinate: CLLocationCoordinate2D, placeName: String? = nil) {
        self.newReminderCoordinates = coordinate
        if let name = placeName, !name.isEmpty {
            self.newReminderPlace = name
        } else if self.newReminderPlace.isEmpty { // Fallback if no name provided and current place is empty
            self.newReminderPlace = "Location (\(String(format: "%.4f", coordinate.latitude)), \(String(format: "%.4f", coordinate.longitude)))"
        }
        // self.showLocationPicker = false // Picker dismissal is handled by the view itself
    }
    
    func requestLocationAccessIfNeeded() {
        locationService.requestLocationPermissions()
    }
    
    func startMonitoringLocation() {
        locationService.startUpdatingLocation()
    }
    
    func stopMonitoringLocation() {
        locationService.stopUpdatingLocation()
    }
}
