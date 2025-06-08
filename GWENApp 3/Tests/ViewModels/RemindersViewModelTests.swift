import XCTest
import Combine
import CoreLocation
import MapKit
@testable import GWENApp_3 // Replace with your app module name

@MainActor
class RemindersViewModelTests: XCTestCase {

    var viewModel: RemindersViewModel!
    var mockNetworkingService: MockNetworkingService!
    var mockLocationService: MockLocationService!
    var mockMapKitService: MockMapKitService!
    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        mockNetworkingService = MockNetworkingService()
        mockLocationService = MockLocationService()
        mockMapKitService = MockMapKitService()

        viewModel = RemindersViewModel(
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
        XCTAssertTrue(viewModel.reminders.isEmpty)
        XCTAssertTrue(viewModel.triggeredReminders.isEmpty)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.newReminderPlace.isEmpty)
        XCTAssertTrue(viewModel.newReminderNote.isEmpty)
        XCTAssertNil(viewModel.newReminderCoordinates)
        XCTAssertTrue(viewModel.searchResults.isEmpty)
        XCTAssertTrue(viewModel.searchQuery.isEmpty)
        XCTAssertFalse(viewModel.showLocationPicker)
        XCTAssertNil(viewModel.selectedMapItem)
        XCTAssertFalse(viewModel.addReminderSuccess)
    }

    // MARK: - Fetch Reminders Tests
    func testFetchReminders_Success() {
        let mockReminders = [
            LocationReminder(id: 1, reminder: "Test Reminder 1", latitude: 0, longitude: 0, place_name: "Place 1", radius: 100, created_at: Date().timeIntervalSince1970)
        ]
        mockNetworkingService.fetchLocationRemindersResult = .success(mockReminders)

        let expectation = XCTestExpectation(description: "Fetch reminders success")

        viewModel.fetchReminders()

        XCTAssertTrue(mockNetworkingService.fetchLocationRemindersCalled)
        XCTAssertTrue(viewModel.isLoading)

        viewModel.$reminders.dropFirst().sink { reminders in
            if !reminders.isEmpty {
                XCTAssertFalse(self.viewModel.isLoading)
                XCTAssertEqual(self.viewModel.reminders.count, 1)
                XCTAssertEqual(self.viewModel.reminders.first?.reminder, "Test Reminder 1")
                XCTAssertNil(self.viewModel.errorMessage)
                expectation.fulfill()
            }
        }.store(in: &cancellables)

        wait(for: [expectation], timeout: 1.0)
    }

    func testFetchReminders_Failure() {
        mockNetworkingService.fetchLocationRemindersResult = .failure(NetworkError.serverError("Fetch failed"))

        let expectation = XCTestExpectation(description: "Fetch reminders failure")

        viewModel.fetchReminders()

        XCTAssertTrue(mockNetworkingService.fetchLocationRemindersCalled)
        XCTAssertTrue(viewModel.isLoading)

        viewModel.$errorMessage.dropFirst().sink { errorMsg in
            if errorMsg != nil {
                XCTAssertFalse(self.viewModel.isLoading)
                XCTAssertNotNil(self.viewModel.errorMessage)
                XCTAssertTrue(self.viewModel.errorMessage!.contains("Fetch failed"))
                XCTAssertTrue(self.viewModel.reminders.isEmpty)
                expectation.fulfill()
            }
        }.store(in: &cancellables)

        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - Add Reminder Tests
    func testAddReminder_Success() {
        viewModel.newReminderPlace = "New Place"
        viewModel.newReminderNote = "New Note"
        viewModel.newReminderCoordinates = CLLocationCoordinate2D(latitude: 10, longitude: 10)

        let createdReminder = LocationReminder(id: 2, reminder: "New Note", latitude: 10, longitude: 10, place_name: "New Place", radius: 100, created_at: Date().timeIntervalSince1970)
        mockNetworkingService.createLocationReminderResult = .success(createdReminder)

        let expectation = XCTestExpectation(description: "Add reminder success")

        viewModel.addReminder()

        XCTAssertTrue(mockNetworkingService.createLocationReminderCalled)
        XCTAssertEqual(mockNetworkingService.lastReminderPlace, "New Place")
        XCTAssertEqual(mockNetworkingService.lastReminderNote, "New Note")
        XCTAssertTrue(viewModel.isLoading)

        viewModel.$addReminderSuccess.filter { $0 == true }.sink { success in
            XCTAssertFalse(self.viewModel.isLoading)
            XCTAssertEqual(self.viewModel.reminders.count, 1)
            XCTAssertEqual(self.viewModel.reminders.first?.id, 2)
            XCTAssertTrue(self.viewModel.newReminderPlace.isEmpty) // Fields should be cleared
            XCTAssertTrue(self.viewModel.newReminderNote.isEmpty)
            XCTAssertNil(self.viewModel.newReminderCoordinates)
            XCTAssertNil(self.viewModel.errorMessage)
            expectation.fulfill()
        }.store(in: &cancellables)

        wait(for: [expectation], timeout: 1.0)
    }

    func testAddReminder_Failure() {
        viewModel.newReminderPlace = "Test"
        viewModel.newReminderNote = "Test"
        viewModel.newReminderCoordinates = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        mockNetworkingService.createLocationReminderResult = .failure(NetworkError.serverError("Create failed"))

        viewModel.addReminder()

        let expectation = XCTestExpectation(description: "Add reminder failure")
        viewModel.$errorMessage.dropFirst().sink { errorMsg in
            if errorMsg != nil {
                XCTAssertFalse(self.viewModel.isLoading)
                XCTAssertFalse(self.viewModel.addReminderSuccess)
                XCTAssertNotNil(self.viewModel.errorMessage)
                XCTAssertTrue(self.viewModel.errorMessage!.contains("Create failed"))
                expectation.fulfill()
            }
        }.store(in: &cancellables)
        wait(for: [expectation], timeout: 1.0)
    }

    func testAddReminder_MissingData() {
        viewModel.newReminderNote = "" // Missing note
        viewModel.newReminderPlace = "Some Place"
        viewModel.newReminderCoordinates = CLLocationCoordinate2D(latitude: 0, longitude: 0)

        viewModel.addReminder()

        XCTAssertFalse(mockNetworkingService.createLocationReminderCalled)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.errorMessage, "Place, note, and coordinates are required for a reminder.")
    }

    // MARK: - Location Search Tests (for LocationPicker)
    func testSearchLocations_Success() {
        viewModel.searchQuery = "Library"
        mockLocationService.setCurrentLocation(to: CLLocationCoordinate2D(latitude: 0, longitude: 0))

        let mockMapItem = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: 0.1, longitude: 0.1)))
        mockMapItem.name = "Mock Library"
        mockMapKitService.searchForPlacesResult = .success([mockMapItem])

        let expectation = XCTestExpectation(description: "Search locations success")

        viewModel.searchLocations()

        XCTAssertTrue(mockMapKitService.searchForPlacesCalled)
        XCTAssertEqual(mockMapKitService.lastSearchQuery, "Library")
        XCTAssertTrue(viewModel.isLoading)

        viewModel.$searchResults.dropFirst().sink { results in
            if !results.isEmpty {
                XCTAssertFalse(self.viewModel.isLoading)
                XCTAssertEqual(self.viewModel.searchResults.count, 1)
                XCTAssertEqual(self.viewModel.searchResults.first?.name, "Mock Library")
                expectation.fulfill()
            }
        }.store(in: &cancellables)
        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - Select Location / MapItem
    func testSelectMapItem() {
        let mockCoordinate = CLLocationCoordinate2D(latitude: 12.34, longitude: 56.78)
        let mockPlacemark = MKPlacemark(coordinate: mockCoordinate)
        let mockMapItem = MKMapItem(placemark: mockPlacemark)
        mockMapItem.name = "Selected Mock Place"

        viewModel.selectMapItem(mockMapItem)

        XCTAssertEqual(viewModel.selectedMapItem, mockMapItem)
        XCTAssertEqual(viewModel.newReminderCoordinates?.latitude, mockCoordinate.latitude)
        XCTAssertEqual(viewModel.newReminderCoordinates?.longitude, mockCoordinate.longitude)
        XCTAssertEqual(viewModel.newReminderPlace, "Selected Mock Place")
        XCTAssertFalse(viewModel.showLocationPicker) // Should hide picker after selection
    }

    func testSelectLocation_WithPlaceName() {
        let mockCoordinate = CLLocationCoordinate2D(latitude: 1.1, longitude: 2.2)
        let placeName = "Custom Place Name"

        viewModel.selectLocation(mockCoordinate, placeName: placeName)

        XCTAssertEqual(viewModel.newReminderCoordinates?.latitude, mockCoordinate.latitude)
        XCTAssertEqual(viewModel.newReminderPlace, placeName)
    }

    func testSelectLocation_WithoutPlaceName_UsesGeneric() {
        let mockCoordinate = CLLocationCoordinate2D(latitude: 3.3, longitude: 4.4)
        viewModel.newReminderPlace = "" // Ensure it's empty to test fallback

        viewModel.selectLocation(mockCoordinate, placeName: nil)

        XCTAssertEqual(viewModel.newReminderCoordinates?.latitude, mockCoordinate.latitude)
        XCTAssertTrue(viewModel.newReminderPlace.contains("Location (3.3000, 4.4000)"))
    }
}
