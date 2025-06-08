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
                        annotationItems: viewModel.mapItems) { mapItem in
                        MapAnnotation(coordinate: mapItem.placemark.coordinate) {
                            VStack {
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundColor(viewModel.selectedMapItem?.id == mapItem.id ? .blue : .red) // Highlight selected
                                    .font(.title)
                                Text(mapItem.name ?? "Place")
                                    .font(.caption)
                                    .background(Color.white.opacity(0.7))
                                    .cornerRadius(4)
                            }
                            .onTapGesture {
                                viewModel.selectMapItem(mapItem)
                            }
                        }
                    }
                    .overlay(
                        Group {
                            if let route = viewModel.route {
                                MapPolylineView(route: route)
                            }
                        }
                    )
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
                } else if !viewModel.mapItems.isEmpty { // Changed from searchResults to mapItems for consistency
                    // List of search results
                    List {
                        ForEach(viewModel.mapItems) { mapItem in // Changed from searchResults to mapItems
                            PlaceRow(mapItem: mapItem) // Assuming PlaceRow can take MKMapItem or we adapt it
                                .onTapGesture {
                                    viewModel.selectMapItem(mapItem)
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
                Text(selectedItem.name ?? "Selected Place") // MKMapItem's name
                    .font(.headline)
                
                // Attempt to display address more reliably
                let addressString = [selectedItem.placemark.subThoroughfare, selectedItem.placemark.thoroughfare, selectedItem.placemark.locality, selectedItem.placemark.administrativeArea, selectedItem.placemark.postalCode]
                    .compactMap { $0 }
                    .joined(separator: ", ")

                if !addressString.isEmpty {
                    Text(addressString)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                } else if let address = selectedItem.placemark.title {
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

struct MapPolylineView: UIViewRepresentable {
    let route: MKRoute

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.addOverlay(route.polyline)
        mapView.setVisibleMapRect(route.polyline.boundingMapRect, edgePadding: UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20), animated: false)
        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        if uiView.overlays.count > 0 {
            uiView.removeOverlays(uiView.overlays)
        }
        uiView.addOverlay(route.polyline)
        uiView.setVisibleMapRect(route.polyline.boundingMapRect, edgePadding: UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20), animated: true)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapPolylineView

        init(_ parent: MapPolylineView) {
            self.parent = parent
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = .blue
                renderer.lineWidth = 3
                return renderer
            }
            return MKOverlayRenderer()
        }
    }
}


struct PlaceRow: View {
    let mapItem: MKMapItem // Changed from PlaceSearchResult to MKMapItem

    var body: some View {
        VStack(alignment: .leading) {
            Text(mapItem.name ?? "Unknown Place")
                .font(.headline)

            let addressString = [mapItem.placemark.subThoroughfare, mapItem.placemark.thoroughfare, mapItem.placemark.locality]
                .compactMap { $0 }
                .joined(separator: " ")

            if !addressString.isEmpty {
                Text(addressString)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            } else if let title = mapItem.placemark.title {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 4)
    }
}

// Extension to make MKMapItem Identifiable for ForEach
extension MKMapItem: Identifiable {
    public var id: UUID {
        return UUID() // Simple unique ID; consider stability if items are frequently reordered/replaced
    }
}


#Preview {
    PlacesSearchView()
}

