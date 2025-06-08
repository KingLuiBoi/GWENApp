//
//  WatchRemindersViewModel.swift
//  GWENAppWatchOS
//
//  Created by Manus on 5/14/25.
//

import Foundation
import Combine
import CoreLocation

// Reusing the iOS RemindersViewModel for WatchOS for now.
// If significant differences in logic or data presentation are needed,
// a dedicated WatchRemindersViewModel could be created.
// For simplicity, we assume the existing one is mostly compatible for data operations,
// though the UI will be significantly streamlined.

// No new ViewModel needed if RemindersViewModel is suitable.
// A Watch-specific one might focus more on displaying triggered reminders
// and quick actions rather than complex creation UIs.
/*
class WatchRemindersViewModel: ObservableObject {
    @Published var activeReminders: [LocationReminder] = [] // Show a few active ones
    @Published var triggeredReminders: [LocationReminder] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    private let networkingService: NetworkingServiceProtocol
    private let locationService: LocationServiceProtocol
    private var cancellables = Set<AnyCancellable>()

    init(
        networkingService: NetworkingServiceProtocol = NetworkingService.shared,
        locationService: LocationServiceProtocol = LocationService.shared
    ) {
        self.networkingService = networkingService
        self.locationService = locationService
        subscribeToLocationUpdates()
        // fetchActiveReminders() // Fetch on init or let view trigger
    }

    private func subscribeToLocationUpdates() {
        locationService.currentLocation
            .compactMap { $0 }
            .debounce(for: .seconds(20), scheduler: DispatchQueue.main) // Less frequent for watch?
            .sink { [weak self] coordinates in
                self?.checkLocationForTriggers(coordinates: coordinates)
            }
            .store(in: &cancellables)
            
        locationService.authorizationStatus
            .sink { [weak self] status in
                if status == .authorizedWhenInUse || status == .authorizedAlways {
                    self?.locationService.startUpdatingLocation()
                } else {
                    self?.locationService.stopUpdatingLocation()
                }
            }
            .store(in: &cancellables)
    }

    func fetchActiveReminders() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let fetchedReminders = try await networkingService.fetchLocationReminders()
                DispatchQueue.main.async {
                    // Show only a few, or those most relevant
                    self.activeReminders = Array(fetchedReminders.sorted(by: { $0.timestamp > $1.timestamp }).prefix(3))
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.errorMessage = "Failed: \(error.localizedDescription)".prefix(50).description
                }
            }
        }
    }

    func checkLocationForTriggers(coordinates: CLLocationCoordinate2D) {
        Task {
            do {
                let triggered = try await networkingService.updateUserLocation(lat: coordinates.latitude, lon: coordinates.longitude)
                DispatchQueue.main.async {
                    self.triggeredReminders = triggered
                    if !triggered.isEmpty {
                        // Handle triggered reminders - e.g., show a notification
                        print("Watch: Triggered reminders: \(triggered.map { $0.note })")
                        // Potentially send a local notification on the watch
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    print("Watch: Error checking location triggers: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func requestLocationIfNeeded() {
        locationService.requestLocationPermissions()
    }
}
*/

