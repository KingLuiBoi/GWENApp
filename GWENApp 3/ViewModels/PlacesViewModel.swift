//
//  PlacesViewModel.swift
//  GWENApp
//
//  Created by Manus on 5/14/25.
//

import Foundation
import Combine
import CoreLocation
import MapKit

class PlacesViewModel: ObservableObject {
    @Published var searchResults: [PlaceSearchResult] = []
    @Published var mapItems: [MKMapItem] = []
    @Published var selectedMapItem: MKMapItem?
    @Published var region: MKCoordinateRegion
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var searchQuery: String = ""
    @Published var showDirections: Bool = false
    @Published var route: MKRoute?
    
    private let networkingService: NetworkingServiceProtocol
    private let locationService: LocationServiceProtocol
    private let mapKitService: MapKitServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    private var lastSearchedLocation: CLLocationCoordinate2D? = nil

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
            .compactMap { $0 }
            .sink { [weak self] coordinates in
                guard let self = self else { return }
                self.lastSearchedLocation = coordinates
                
                // Update the map region to center on the user's location
                self.region = MKCoordinateRegion(
                    center: coordinates,
                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                )
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

    func performSearch() {
        guard !searchQuery.isEmpty else {
            errorMessage = "Please enter a search query (e.g., cafe, park)."
            searchResults = []
            mapItems = []
            return
        }
        
        guard let coordinates = lastSearchedLocation ?? locationService.currentLocation.value else {
            errorMessage = "Could not determine your current location. Please ensure location services are enabled."
            if locationService.authorizationStatus.value == .authorizedWhenInUse || locationService.authorizationStatus.value == .authorizedAlways {
                locationService.startUpdatingLocation()
            } else {
                locationService.requestLocationPermissions()
            }
            searchResults = []
            mapItems = []
            return
        }

        isLoading = true
        errorMessage = nil
        
        // First, try to search using MapKit
        mapKitService.searchForPlaces(near: coordinates, query: searchQuery)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        print("MapKit search failed, falling back to backend: \(error.localizedDescription)")
                        // If MapKit search fails, fall back to backend search
                        self?.searchUsingBackend(coordinates: coordinates)
                    }
                },
                receiveValue: { [weak self] mapItems in
                    guard let self = self else { return }
                    self.isLoading = false
                    
                    if mapItems.isEmpty {
                        // If no results from MapKit, try backend
                        self.searchUsingBackend(coordinates: coordinates)
                    } else {
                        self.mapItems = mapItems
                        
                        // Convert MKMapItems to PlaceSearchResults for compatibility
                        self.searchResults = mapItems.map { self.mapKitService.convertMapItemToPlaceSearchResult(mapItem: $0) }
                        
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
    
    private func searchUsingBackend(coordinates: CLLocationCoordinate2D) {
        Task {
            do {
                let results = try await networkingService.searchPlaces(
                    lat: coordinates.latitude,
                    lon: coordinates.longitude,
                    type: searchQuery
                )
                DispatchQueue.main.async {
                    self.searchResults = results
                    
                    // Convert backend results to MKMapItems
                    self.mapItems = results.compactMap { self.mapKitService.convertPlaceSearchResultToMapItem(place: $0) }
                    
                    self.isLoading = false
                    if results.isEmpty {
                        self.errorMessage = "No places found matching your query near your location."
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.searchResults = []
                    self.mapItems = []
                    if let networkError = error as? NetworkError {
                        self.errorMessage = networkError.localizedDescription
                    } else {
                        self.errorMessage = "Failed to search for places: \(error.localizedDescription)"
                    }
                    print("Error searching places: \(error)")
                }
            }
        }
    }
    
    func selectMapItem(_ mapItem: MKMapItem) {
        self.selectedMapItem = mapItem
        
        // Center the map on the selected item
        self.region = MKCoordinateRegion(
            center: mapItem.placemark.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01) // Zoom in closer
        )
    }
    
    func getDirectionsToSelectedItem() {
        guard let selectedMapItem = selectedMapItem,
              let userLocation = lastSearchedLocation ?? locationService.currentLocation.value else {
            errorMessage = "Cannot get directions. Make sure location services are enabled."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        mapKitService.getDirections(from: userLocation, to: selectedMapItem.placemark.coordinate)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.isLoading = false
                        self?.errorMessage = "Failed to get directions: \(error.localizedDescription)"
                    }
                },
                receiveValue: { [weak self] route in
                    guard let self = self else { return }
                    self.isLoading = false
                    self.route = route
                    self.showDirections = true
                }
            )
            .store(in: &cancellables)
    }
    
    func openInMaps(_ mapItem: MKMapItem) {
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }
    
    func requestLocationAccessIfNeeded() {
        locationService.requestLocationPermissions()
        if locationService.authorizationStatus.value == .authorizedWhenInUse || locationService.authorizationStatus.value == .authorizedAlways {
            locationService.startUpdatingLocation()
        }
    }
}

