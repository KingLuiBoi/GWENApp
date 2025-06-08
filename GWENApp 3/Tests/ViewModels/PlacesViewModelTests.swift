import XCTest
import Combine
import MapKit // For MKMapItem, MKCoordinateRegion, MKRoute
@testable import GWENApp_3 // Replace with your app module name

@MainActor
class PlacesViewModelTests: XCTestCase {

    var viewModel: PlacesViewModel!
    var mockNetworkingService: MockNetworkingService!
    var mockLocationService: MockLocationService!
    var mockMapKitService: MockMapKitService!
    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        mockNetworkingService = MockNetworkingService()
        mockLocationService = MockLocationService()
        mockMapKitService = MockMapKitService()

        viewModel = PlacesViewModel(
            networkingService: mockNetworkingService,
            locationService: mockLocationService,
            mapKitService: mockMapKitService
        )
        cancellables = []
    }

    override func tearDown() {
        viewModel = nil
        mockNetworkingService = nil
        mockLocationService = nil
        mockMapKitService = nil
        cancellables = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests
    func testInitialization_DefaultStates() {
        XCTAssertTrue(viewModel.searchResults.isEmpty)
        XCTAssertTrue(viewModel.mapItems.isEmpty)
        XCTAssertNil(viewModel.selectedMapItem)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.searchQuery.isEmpty)
        XCTAssertFalse(viewModel.showDirections)
        XCTAssertNil(viewModel.route)
        // Region is initialized to a default value, can check if needed but less critical
    }

    // MARK: - Search Tests
    func testPerformSearch_Success_MapKitResults() {
        viewModel.searchQuery = "cafe"
        mockLocationService.setCurrentLocation(to: CLLocationCoordinate2D(latitude: 37.0, longitude: -122.0))

        let mockMKMapItem = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: 37.1, longitude: -122.1)))
        mockMKMapItem.name = "Mock Cafe"
        let mockMapItems = [mockMKMapItem]
        mockMapKitService.searchForPlacesResult = .success(mockMapItems)

        let mockPlaceSearchResult = PlaceSearchResult(id: "mock1", name: "Mock Cafe", address: "123 Mock St", lat: "37.1", lon: "-122.1")
        mockMapKitService.mockPlaceSearchResult = mockPlaceSearchResult // Used by convertMapItemToPlaceSearchResult

        let expectation = XCTestExpectation(description: "Perform search with MapKit success")

        viewModel.performSearch()

        XCTAssertTrue(mockMapKitService.searchForPlacesCalled)
        XCTAssertEqual(mockMapKitService.lastSearchQuery, "cafe")
        XCTAssertTrue(viewModel.isLoading)

        viewModel.$mapItems.dropFirst().sink { items in
            if !items.isEmpty {
                XCTAssertFalse(self.viewModel.isLoading)
                XCTAssertEqual(self.viewModel.mapItems.count, 1)
                XCTAssertEqual(self.viewModel.mapItems.first?.name, "Mock Cafe")
                XCTAssertEqual(self.viewModel.searchResults.count, 1)
                XCTAssertEqual(self.viewModel.searchResults.first?.name, "Mock Cafe")
                XCTAssertNil(self.viewModel.errorMessage)
                expectation.fulfill()
            }
        }.store(in: &cancellables)

        wait(for: [expectation], timeout: 1.0)
    }

    func testPerformSearch_Success_BackendResultsAfterMapKitEmpty() {
        viewModel.searchQuery = "park"
        mockLocationService.setCurrentLocation(to: CLLocationCoordinate2D(latitude: 37.0, longitude: -122.0))

        // MapKit returns empty
        mockMapKitService.searchForPlacesResult = .success([])

        // Backend returns results
        let backendPlaces = [Place(name: "Backend Park", place_id: "bp1", vicinity: "Backend Ave", latitude: 37.2, longitude: -122.2, rating: 4.0, types: ["park"])]
        mockNetworkingService.searchPlacesResult = .success(backendPlaces)

        // Mock conversion from Place to MKMapItem
        let mockMKMapItem = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: 37.2, longitude: -122.2)))
        mockMKMapItem.name = "Backend Park"
        mockMapKitService.mockMapItemFromResult = mockMKMapItem // Used by convertPlaceSearchResultToMapItem

        let expectation = XCTestExpectation(description: "Perform search with backend success")

        viewModel.performSearch()

        XCTAssertTrue(mockMapKitService.searchForPlacesCalled)
        XCTAssertTrue(viewModel.isLoading)

        // Expectation for mapItems update (from backend)
        viewModel.$mapItems.dropFirst().sink { items in
            if !items.isEmpty && items.first?.name == "Backend Park" {
                XCTAssertFalse(self.viewModel.isLoading)
                XCTAssertTrue(self.mockNetworkingService.searchPlacesCalled)
                XCTAssertEqual(self.viewModel.mapItems.count, 1)
                XCTAssertEqual(self.viewModel.mapItems.first?.name, "Backend Park")
                XCTAssertEqual(self.viewModel.searchResults.count, 1) // searchResults also updated from backend
                XCTAssertEqual(self.viewModel.searchResults.first?.name, "Backend Park")
                XCTAssertNil(self.viewModel.errorMessage)
                expectation.fulfill()
            }
        }.store(in: &cancellables)

        wait(for: [expectation], timeout: 1.0)
    }

    func testPerformSearch_MapKitError_FallbackToBackend_BackendError() {
        viewModel.searchQuery = "store"
        mockLocationService.setCurrentLocation(to: CLLocationCoordinate2D(latitude: 37.0, longitude: -122.0))

        mockMapKitService.searchForPlacesResult = .failure(NSError(domain: "MapKitError", code: 1))
        mockNetworkingService.searchPlacesResult = .failure(NetworkError.serverError("Backend down"))

        let expectation = XCTestExpectation(description: "Perform search with MapKit and Backend errors")

        viewModel.performSearch()

        XCTAssertTrue(mockMapKitService.searchForPlacesCalled)
        XCTAssertTrue(viewModel.isLoading)

        viewModel.$errorMessage.dropFirst().sink { errorMsg in
            if errorMsg != nil {
                XCTAssertFalse(self.viewModel.isLoading)
                XCTAssertTrue(self.mockNetworkingService.searchPlacesCalled) // Backend search was attempted
                XCTAssertNotNil(self.viewModel.errorMessage)
                XCTAssertTrue(self.viewModel.errorMessage!.contains("Backend down"))
                XCTAssertTrue(self.viewModel.searchResults.isEmpty)
                XCTAssertTrue(self.viewModel.mapItems.isEmpty)
                expectation.fulfill()
            }
        }.store(in: &cancellables)

        wait(for: [expectation], timeout: 1.0)
    }

    func testPerformSearch_NoLocation() {
        viewModel.searchQuery = "anything"
        mockLocationService.setCurrentLocation(to: nil) // No current location
        mockLocationService.authorizationStatusValue = .denied // And no permission to get it

        viewModel.performSearch()

        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.errorMessage!.contains("Could not determine your current location"))
        XCTAssertFalse(mockMapKitService.searchForPlacesCalled)
        XCTAssertFalse(mockNetworkingService.searchPlacesCalled)
    }

    func testPerformSearch_EmptyQuery() {
        viewModel.searchQuery = ""
        viewModel.performSearch()
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.errorMessage, "Please enter a search query (e.g., cafe, park).")
    }

    // MARK: - Directions Tests
    func testGetDirectionsToSelectedItem_Success() {
        let mockSelectedItem = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: 37.1, longitude: -122.1)))
        mockSelectedItem.name = "Destination Cafe"
        viewModel.selectedMapItem = mockSelectedItem

        mockLocationService.setCurrentLocation(to: CLLocationCoordinate2D(latitude: 37.0, longitude: -122.0))

        let mockRoute = MKRoute() // Basic mock route
        mockMapKitService.getDirectionsResult = .success(mockRoute)

        let expectation = XCTestExpectation(description: "Get directions success")

        viewModel.getDirectionsToSelectedItem()

        XCTAssertTrue(mockMapKitService.getDirectionsCalled)
        XCTAssertTrue(viewModel.isLoading)

        viewModel.$route.dropFirst().sink { route in
            if route != nil {
                XCTAssertFalse(self.viewModel.isLoading)
                XCTAssertNotNil(self.viewModel.route)
                XCTAssertTrue(self.viewModel.showDirections)
                XCTAssertNil(self.viewModel.errorMessage)
                expectation.fulfill()
            }
        }.store(in: &cancellables)

        wait(for: [expectation], timeout: 1.0)
    }

    func testGetDirectionsToSelectedItem_NoSelectedItem() {
        viewModel.selectedMapItem = nil
        viewModel.getDirectionsToSelectedItem()
        XCTAssertFalse(mockMapKitService.getDirectionsCalled)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.errorMessage!.contains("Cannot get directions"))
    }

    func testGetDirectionsToSelectedItem_NoUserLocation() {
        viewModel.selectedMapItem = MKMapItem() // Dummy item
        mockLocationService.setCurrentLocation(to: nil)
        mockLocationService.authorizationStatusValue = .denied

        viewModel.getDirectionsToSelectedItem()

        XCTAssertFalse(mockMapKitService.getDirectionsCalled)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.errorMessage!.contains("Cannot get directions"))
    }

    // MARK: - Other Functionality
    func testSelectMapItem() {
        let mockMapItem = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: 37.1, longitude: -122.1)))
        mockMapItem.name = "Selected Item"

        viewModel.selectMapItem(mockMapItem)

        XCTAssertEqual(viewModel.selectedMapItem, mockMapItem)
        XCTAssertEqual(viewModel.region.center.latitude, mockMapItem.placemark.coordinate.latitude)
        XCTAssertEqual(viewModel.region.center.longitude, mockMapItem.placemark.coordinate.longitude)
        XCTAssertEqual(viewModel.region.span.latitudeDelta, 0.01, accuracy: 0.001) // Zoomed in span
    }

    func testRequestLocationAccessIfNeeded() {
        mockLocationService.authorizationStatusValue = .notDetermined
        viewModel.requestLocationAccessIfNeeded()
        XCTAssertTrue(mockLocationService.requestLocationPermissionsCalled)

        mockLocationService.reset()
        mockLocationService.authorizationStatusValue = .authorizedWhenInUse
        viewModel.requestLocationAccessIfNeeded()
        XCTAssertTrue(mockLocationService.startUpdatingLocationCalled)
    }
}
