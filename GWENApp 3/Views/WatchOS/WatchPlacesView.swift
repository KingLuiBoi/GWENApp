//
//  WatchPlacesView.swift
//  GWENAppWatchOS
//
//  Created by Manus on 5/15/25.
//

import SwiftUI
import MapKit

struct WatchPlacesView: View {
    @StateObject private var viewModel = PlacesViewModel()
    @State private var showingSearchOptions = false
    @State private var selectedSearchType: String = "cafe" // Default or last used
    
    // Predefined search types for quick selection on WatchOS
    let searchTypes = ["cafe", "restaurant", "park", "atm", "pharmacy"]

    var body: some View {
        VStack {
            // Map View
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
                                .font(.headline)
                            Text(place.name)
                                .font(.caption2)
                                .background(Color.black.opacity(0.5))
                                .foregroundColor(.white)
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
            .edgesIgnoringSafeArea(.all)
            .frame(height: 120)
            
            // Search Button
            Button {
                showingSearchOptions = true
            } label: {
                HStack {
                    Image(systemName: "magnifyingglass")
                    Text("Find: \(selectedSearchType)")
                }
                .padding(8)
                .background(Color.gray.opacity(0.3))
                .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.top, 5)
            
            // Status or Results
            if viewModel.isLoading {
                ProgressView()
                    .padding(.top, 5)
            } else if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.caption2)
                    .foregroundColor(.red)
                    .padding(.top, 5)
            } else if viewModel.selectedMapItem != nil {
                // Selected place details
                WatchPlaceDetailView(viewModel: viewModel)
            } else if !viewModel.searchResults.isEmpty {
                // List of search results (limited for watch)
                List {
                    ForEach(viewModel.searchResults.prefix(3)) { place in
                        WatchPlaceRow(place: place)
                            .onTapGesture {
                                if let index = viewModel.searchResults.firstIndex(where: { $0.id == place.id }),
                                   index < viewModel.mapItems.count {
                                    viewModel.selectMapItem(viewModel.mapItems[index])
                                }
                            }
                    }
                }
                .frame(height: 100) // Limit height for watch
            }
        }
        .navigationTitle("Places")
        .onAppear {
            viewModel.requestLocationAccessIfNeeded()
        }
        .sheet(isPresented: $showingSearchOptions) {
            WatchSearchTypeSelectionView(selectedSearchType: $selectedSearchType, searchTypes: searchTypes) {
                viewModel.searchQuery = selectedSearchType
                viewModel.performSearch()
            }
        }
    }
}

struct WatchPlaceDetailView: View {
    @ObservedObject var viewModel: PlacesViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            if let selectedItem = viewModel.selectedMapItem {
                Text(selectedItem.name ?? "Selected Place")
                    .font(.headline)
                    .lineLimit(1)
                
                if let address = selectedItem.placemark.title {
                    Text(address)
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                
                HStack {
                    Button(action: {
                        viewModel.getDirectionsToSelectedItem()
                    }) {
                        Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                    }
                    .buttonStyle(BorderedButtonStyle())
                    
                    Spacer()
                    
                    Button(action: {
                        viewModel.openInMaps(selectedItem)
                    }) {
                        Image(systemName: "map.fill")
                    }
                    .buttonStyle(BorderedButtonStyle())
                    
                    Spacer()
                    
                    Button(action: {
                        viewModel.selectedMapItem = nil
                    }) {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(BorderedButtonStyle())
                }
            }
        }
        .padding(.horizontal, 5)
    }
}

struct WatchPlaceRow: View {
    let place: PlaceSearchResult

    var body: some View {
        VStack(alignment: .leading) {
            Text(place.name)
                .font(.caption)
                .lineLimit(1)
            if let address = place.address, !address.isEmpty {
                Text(address)
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
}

struct WatchSearchTypeSelectionView: View {
    @Binding var selectedSearchType: String
    let searchTypes: [String]
    var onTypeSelected: () -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        List {
            ForEach(searchTypes, id: \.self) { type in
                Button(action: {
                    selectedSearchType = type
                    onTypeSelected()
                    dismiss()
                }) {
                    Text(type.capitalized)
                        .font(.caption)
                }
            }
        }
        .navigationTitle("Select Type")
    }
}

#Preview {
    WatchPlacesView()
}
