//
//  PlacesSearchView.swift
//  GWENApp
//
//  Created by Manus on 5/14/25.
//

import SwiftUI
import MapKit

struct PlacesSearchView: View {
    @StateObject private var viewModel = PlacesViewModel()
    @State private var mapType: MKMapType = .standard

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                HStack {
                    TextField("Search (e.g., cafe, park)", text: $viewModel.searchQuery, onCommit: {
                        viewModel.performSearch()
                    })
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    
                    Button(action: {
                        viewModel.performSearch()
                    }) {
                        Image(systemName: "magnifyingglass")
                    }
                }
                .padding()
                
                // Map Type Picker
                Picker("Map Type", selection: $mapType) {
                    Text("Standard").tag(MKMapType.standard)
                    Text("Satellite").tag(MKMapType.satellite)
                    Text("Hybrid").tag(MKMapType.hybrid)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                
                // Map View
                ZStack {
                    Map(coordinateRegion: $viewModel.region, 
                        showsUserLocation: true,
                        userTrackingMode: .constant(.none),
                        annotationItems: viewModel.searchResults) { place in
                        MapAnnotation(coordinate: CLLocationCoordinate2D(
                            latitude: Double(place.lat) ?? 0,
                            longitude: Double(place.lon) ?? 0)) {
                                VStack {
                                    Image(systemName: "mappin.circle.fill")
                                        .foregroundColor(.red)
                                        .font(.title)
                                    Text(place.name)
                                        .font(.caption)
                                        .background(Color.white.opacity(0.7))
                                        .cornerRadius(4)
                                }
                                .onTapGesture {
                                    if let index = viewModel.searchResults.firstIndex(where: { $0.id == place.id }),
                                       index < viewModel.mapItems.count {
                                        viewModel.selectMapItem(viewModel.mapItems[index])
                                    }
                                }
                        }
                    }
                    .mapType(mapType)
                    .edgesIgnoringSafeArea(.bottom)
                    
                    // User location button
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button(action: {
                                if let location = viewModel.lastSearchedLocation ?? viewModel.locationService.currentLocation.value {
                                    viewModel.region = MKCoordinateRegion(
                                        center: location,
                                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                                    )
                                }
                            }) {
                                Image(systemName: "location.fill")
                                    .padding()
                                    .background(Color.white)
                                    .clipShape(Circle())
                                    .shadow(radius: 2)
                            }
                            .padding()
                        }
                    }
                }
                
                // Status or Results List
                if viewModel.isLoading {
                    ProgressView("Searching for places...")
                        .padding()
                } else if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding()
                } else if viewModel.searchResults.isEmpty && !viewModel.searchQuery.isEmpty {
                    Text("No places found matching \"\(viewModel.searchQuery)\".")
                        .foregroundColor(.secondary)
                        .padding()
                } else if viewModel.selectedMapItem != nil {
                    // Selected place details
                    PlaceDetailView(viewModel: viewModel)
                } else if !viewModel.searchResults.isEmpty {
                    // List of search results
                    List {
                        ForEach(viewModel.searchResults) { place in
                            PlaceRow(place: place)
                                .onTapGesture {
                                    if let index = viewModel.searchResults.firstIndex(where: { $0.id == place.id }),
                                       index < viewModel.mapItems.count {
                                        viewModel.selectMapItem(viewModel.mapItems[index])
                                    }
                                }
                        }
                    }
                    .frame(height: 200) // Limit the height of the list
                }
            }
            .navigationTitle("Nearby Places")
            .onAppear {
                viewModel.requestLocationAccessIfNeeded()
            }
            .sheet(isPresented: $viewModel.showDirections) {
                if let route = viewModel.route {
                    DirectionsView(route: route)
                }
            }
        }
    }
}

struct PlaceDetailView: View {
    @ObservedObject var viewModel: PlacesViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let selectedItem = viewModel.selectedMapItem {
                Text(selectedItem.name ?? "Selected Place")
                    .font(.headline)
                
                if let address = selectedItem.placemark.title {
                    Text(address)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                HStack {
                    Button(action: {
                        viewModel.getDirectionsToSelectedItem()
                    }) {
                        Label("Directions", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                    }
                    .buttonStyle(BorderedButtonStyle())
                    
                    Spacer()
                    
                    Button(action: {
                        viewModel.openInMaps(selectedItem)
                    }) {
                        Label("Open in Maps", systemImage: "map.fill")
                    }
                    .buttonStyle(BorderedButtonStyle())
                    
                    Spacer()
                    
                    Button(action: {
                        viewModel.selectedMapItem = nil
                    }) {
                        Label("Close", systemImage: "xmark.circle.fill")
                    }
                    .buttonStyle(BorderedButtonStyle())
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 2)
        .padding()
    }
}

struct DirectionsView: View {
    let route: MKRoute
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack {
                // Route information
                VStack(alignment: .leading, spacing: 8) {
                    Text("Estimated Travel Time: \(formatTime(route.expectedTravelTime))")
                        .font(.headline)
                    
                    Text("Distance: \(formatDistance(route.distance))")
                        .font(.subheadline)
                    
                    Divider()
                    
                    Text("Route Steps:")
                        .font(.headline)
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(0..<route.steps.count, id: \.self) { index in
                                let step = route.steps[index]
                                HStack(alignment: .top) {
                                    Text("\(index + 1).")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    Text(step.instructions)
                                        .font(.subheadline)
                                }
                            }
                        }
                        .padding(.vertical)
                    }
                }
                .padding()
                
                Spacer()
            }
            .navigationTitle("Directions")
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: seconds) ?? "Unknown"
    }
    
    private func formatDistance(_ meters: CLLocationDistance) -> String {
        let formatter = MKDistanceFormatter()
        formatter.unitStyle = .abbreviated
        return formatter.string(fromDistance: meters)
    }
}

struct PlaceRow: View {
    let place: PlaceSearchResult

    var body: some View {
        VStack(alignment: .leading) {
            Text(place.name)
                .font(.headline)
            if let address = place.address, !address.isEmpty {
                Text(place.address ?? "No address available")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    PlacesSearchView()
}

