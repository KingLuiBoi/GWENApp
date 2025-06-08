import XCTest
import Combine
@testable import GWENApp_3 // Replace with your app module name

@MainActor
class TimeCapsuleViewModelTests: XCTestCase {

    var viewModel: TimeCapsuleViewModel!
    var mockNetworkingService: MockNetworkingService!
    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        mockNetworkingService = MockNetworkingService()
        viewModel = TimeCapsuleViewModel(networkingService: mockNetworkingService)
        cancellables = []
    }

    override func tearDown() {
        viewModel = nil
        mockNetworkingService = nil
        cancellables = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests
    func testInitialization_DefaultStates() {
        XCTAssertTrue(viewModel.timeCapsules.isEmpty)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.newCapsuleNote.isEmpty)
        // newCapsuleOpenDate is initialized to 1 day from now, can test if specific default is critical
        XCTAssertFalse(viewModel.addCapsuleSuccess)
    }

    // MARK: - Fetch Time Capsules Tests
    func testFetchTimeCapsules_Success() {
        let mockCapsules = [
            TimeCapsule(id: 1, note: "Capsule 1", timestamp: Date().timeIntervalSince1970 + 1000, created_at: Date().timeIntervalSince1970)
        ]
        mockNetworkingService.fetchTimeCapsulesResult = .success(mockCapsules)

        let expectation = XCTestExpectation(description: "Fetch time capsules success")

        viewModel.fetchTimeCapsules()

        XCTAssertTrue(mockNetworkingService.fetchTimeCapsulesCalled)
        XCTAssertTrue(viewModel.isLoading)

        viewModel.$timeCapsules.dropFirst().sink { capsules in
            if !capsules.isEmpty {
                XCTAssertFalse(self.viewModel.isLoading)
                XCTAssertEqual(self.viewModel.timeCapsules.count, 1)
                XCTAssertEqual(self.viewModel.timeCapsules.first?.note, "Capsule 1")
                XCTAssertNil(self.viewModel.errorMessage)
                expectation.fulfill()
            }
        }.store(in: &cancellables)

        wait(for: [expectation], timeout: 1.0)
    }

    func testFetchTimeCapsules_Failure() {
        mockNetworkingService.fetchTimeCapsulesResult = .failure(NetworkError.serverError("Fetch failed"))

        let expectation = XCTestExpectation(description: "Fetch time capsules failure")

        viewModel.fetchTimeCapsules()

        XCTAssertTrue(mockNetworkingService.fetchTimeCapsulesCalled)
        XCTAssertTrue(viewModel.isLoading)

        viewModel.$errorMessage.dropFirst().sink { errorMsg in
            if errorMsg != nil {
                XCTAssertFalse(self.viewModel.isLoading)
                XCTAssertNotNil(self.viewModel.errorMessage)
                XCTAssertTrue(self.viewModel.errorMessage!.contains("Fetch failed"))
                XCTAssertTrue(self.viewModel.timeCapsules.isEmpty)
                expectation.fulfill()
            }
        }.store(in: &cancellables)

        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - Add Time Capsule Tests
    func testAddTimeCapsule_Success() {
        viewModel.newCapsuleNote = "Future Note"
        let futureDate = Date().addingTimeInterval(10000) // Ensure it's in the future
        viewModel.newCapsuleOpenDate = futureDate

        let createdCapsule = TimeCapsule(id: 2, note: "Future Note", timestamp: futureDate.timeIntervalSince1970, created_at: Date().timeIntervalSince1970)
        mockNetworkingService.createTimeCapsuleResult = .success(createdCapsule)

        let expectation = XCTestExpectation(description: "Add time capsule success")

        viewModel.addTimeCapsule()

        XCTAssertTrue(mockNetworkingService.createTimeCapsuleCalled)
        XCTAssertEqual(mockNetworkingService.lastTimeCapsuleNote, "Future Note")
        XCTAssertEqual(mockNetworkingService.lastTimeCapsuleTimestamp, futureDate.timeIntervalSince1970)
        XCTAssertTrue(viewModel.isLoading)

        viewModel.$addCapsuleSuccess.filter { $0 == true }.sink { success in
            XCTAssertFalse(self.viewModel.isLoading)
            XCTAssertEqual(self.viewModel.timeCapsules.count, 1)
            XCTAssertEqual(self.viewModel.timeCapsules.first?.id, 2)
            XCTAssertTrue(self.viewModel.newCapsuleNote.isEmpty) // Note should be cleared
            XCTAssertNil(self.viewModel.errorMessage)
            expectation.fulfill()
        }.store(in: &cancellables)

        wait(for: [expectation], timeout: 1.0)
    }

    func testAddTimeCapsule_Failure() {
        viewModel.newCapsuleNote = "Test Fail Note"
        viewModel.newCapsuleOpenDate = Date().addingTimeInterval(1000)
        mockNetworkingService.createTimeCapsuleResult = .failure(NetworkError.serverError("Create failed"))

        viewModel.addTimeCapsule()

        let expectation = XCTestExpectation(description: "Add time capsule failure")
        viewModel.$errorMessage.dropFirst().sink { errorMsg in
            if errorMsg != nil {
                XCTAssertFalse(self.viewModel.isLoading)
                XCTAssertFalse(self.viewModel.addCapsuleSuccess)
                XCTAssertNotNil(self.viewModel.errorMessage)
                XCTAssertTrue(self.viewModel.errorMessage!.contains("Create failed"))
                expectation.fulfill()
            }
        }.store(in: &cancellables)
        wait(for: [expectation], timeout: 1.0)
    }

    func testAddTimeCapsule_EmptyNote() {
        viewModel.newCapsuleNote = ""
        viewModel.addTimeCapsule()
        XCTAssertFalse(mockNetworkingService.createTimeCapsuleCalled)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.errorMessage, "Please enter a note for your time capsule.")
    }

    func testAddTimeCapsule_DateInPast() {
        viewModel.newCapsuleNote = "Past Note"
        viewModel.newCapsuleOpenDate = Date().addingTimeInterval(-1000) // Date in the past

        viewModel.addTimeCapsule()

        XCTAssertFalse(mockNetworkingService.createTimeCapsuleCalled)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.errorMessage, "The open date must be in the future.")
    }

    // MARK: - Delete Time Capsule Tests
    func testDeleteTimeCapsule() {
        let capsule1 = TimeCapsule(id: 1, note: "Delete Me", timestamp: 0, created_at: 0)
        let capsule2 = TimeCapsule(id: 2, note: "Keep Me", timestamp: 0, created_at: 0)
        viewModel.timeCapsules = [capsule1, capsule2]

        mockNetworkingService.deleteTimeCapsuleResult = .success(()) // Successful deletion

        let expectation = XCTestExpectation(description: "Delete time capsule")

        // Call delete on the first item
        viewModel.deleteTimeCapsule(at: IndexSet(integer: 0))

        // Check that the correct method was called on the mock service
        XCTAssertTrue(mockNetworkingService.deleteTimeCapsuleCalled)
        XCTAssertEqual(mockNetworkingService.lastDeletedCapsuleID, 1)

        // Check that the item was removed from the ViewModel's array
        XCTAssertEqual(viewModel.timeCapsules.count, 1)
        XCTAssertEqual(viewModel.timeCapsules.first?.id, 2)

        // Simulate async completion of deletion if needed, or simply check state
        // For this mock, the deletion is synchronous on the array, async for backend call
        expectation.fulfill() // Fulfill immediately as local array is modified sync

        wait(for: [expectation], timeout: 1.0)
    }
}
