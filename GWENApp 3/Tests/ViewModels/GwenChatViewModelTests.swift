import XCTest
import Combine
import AVFoundation // For AVAudioSession status check
import Speech // For SFSpeechRecognizer auth status check
@testable import GWENApp_3 // Replace GWENApp_3 with your actual app module name

@MainActor
class GwenChatViewModelTests: XCTestCase {

    var viewModel: GwenChatViewModel!
    var mockNetworkingService: MockNetworkingService!
    var mockVoiceInputService: MockVoiceInputService!
    var mockAudioPlaybackService: MockAudioPlaybackService! // Assuming this mock will be created
    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        mockNetworkingService = MockNetworkingService()
        mockVoiceInputService = MockVoiceInputService()
        mockAudioPlaybackService = MockAudioPlaybackService() // Create this mock

        // Initialize viewModel with mocks
        viewModel = GwenChatViewModel(
            networkingService: mockNetworkingService,
            voiceInputService: mockVoiceInputService,
            audioPlaybackService: mockAudioPlaybackService
        )
        cancellables = []
    }

    override func tearDown() {
        viewModel = nil
        mockNetworkingService = nil
        mockVoiceInputService = nil
        mockAudioPlaybackService = nil
        cancellables = nil
        super.tearDown()
    }

    // MARK: - Test Initialization
    func testInitialization_DefaultStates() {
        XCTAssertTrue(viewModel.conversation.isEmpty)
        XCTAssertTrue(viewModel.currentInput.isEmpty)
        XCTAssertFalse(viewModel.isThinking)
        XCTAssertNil(viewModel.errorMessage)
        // hasPermissions might be true/false based on current machine state if not fully mocked in init
        // XCTAssertFalse(viewModel.hasPermissions)
        XCTAssertFalse(viewModel.isListeningForHeyGwen)
        XCTAssertFalse(viewModel.isActivelyListening)
    }

    // MARK: - Test Sending Prompt
    func testSendCurrentPrompt_Success() {
        let prompt = "Hello GWEN"
        viewModel.currentInput = prompt

        let mockAudioData = Data("mock_audio".utf8)
        let mockGwenTranscript = "Hello User"
        mockNetworkingService.sendGwenPromptResult = .success((mockAudioData, mockGwenTranscript))

        let expectation = XCTestExpectation(description: "Send prompt success")

        viewModel.sendCurrentPrompt()

        XCTAssertTrue(mockNetworkingService.sendGwenPromptCalled)
        XCTAssertEqual(mockNetworkingService.lastPromptSent, "hey gwen " + prompt) // ViewModel prepends "hey gwen "
        XCTAssertTrue(viewModel.isThinking) // Should be true initially

        // Observe changes to isThinking and conversation
        viewModel.$isThinking.dropFirst().sink { isThinking in
            if !isThinking { // When isThinking becomes false
                XCTAssertEqual(self.viewModel.conversation.count, 1)
                XCTAssertEqual(self.viewModel.conversation.last?.userPrompt, prompt)
                XCTAssertEqual(self.viewModel.conversation.last?.audioData, mockAudioData)
                // XCTAssertEqual(self.viewModel.conversation.last?.gwenTranscript, mockGwenTranscript) // Backend doesn't send this back yet
                XCTAssertTrue(self.mockAudioPlaybackService.playAudioCalled)
                XCTAssertEqual(self.mockAudioPlaybackService.lastPlayedAudioData, mockAudioData)
                expectation.fulfill()
            }
        }.store(in: &cancellables)

        wait(for: [expectation], timeout: 2.0) // Adjust timeout as needed
        XCTAssertTrue(viewModel.currentInput.isEmpty) // Input should be cleared
    }

    func testSendCurrentPrompt_NetworkError() {
        viewModel.currentInput = "Test error"
        mockNetworkingService.sendGwenPromptResult = .failure(NetworkError.serverError("Server down"))

        let expectation = XCTestExpectation(description: "Send prompt network error")

        viewModel.sendCurrentPrompt()

        XCTAssertTrue(mockNetworkingService.sendGwenPromptCalled)
        XCTAssertTrue(viewModel.isThinking)

        viewModel.$errorMessage.dropFirst().sink { errorMessage in
            if errorMessage != nil {
                XCTAssertFalse(self.viewModel.isThinking)
                XCTAssertNotNil(self.viewModel.errorMessage)
                XCTAssertTrue(self.viewModel.errorMessage!.contains("Server down"))
                expectation.fulfill()
            }
        }.store(in: &cancellables)

        wait(for: [expectation], timeout: 1.0)
    }

    func testSendCurrentPrompt_EmptyInput() {
        viewModel.currentInput = "  " // Whitespace only
        viewModel.sendCurrentPrompt()
        XCTAssertFalse(mockNetworkingService.sendGwenPromptCalled)
        XCTAssertFalse(viewModel.isThinking)
    }

    // MARK: - Test Voice Input Service Interactions

    func testToggleHeyGwenListening_StartsWhenPermittedAndOff() {
        viewModel.hasPermissions = true // Assume permissions are granted
        viewModel.isListeningForHeyGwen = false
        mockVoiceInputService.isListeningForWakeWordValue = false

        viewModel.toggleHeyGwenListening()

        XCTAssertTrue(mockVoiceInputService.startListeningForWakeWordCalled)
        // isListeningForHeyGwen will be updated via publisher subscription
    }

    func testToggleHeyGwenListening_StopsWhenOn() {
        viewModel.hasPermissions = true
        viewModel.isListeningForHeyGwen = true // Simulate it's on
        mockVoiceInputService.isListeningForWakeWordValue = true


        viewModel.toggleHeyGwenListening()

        XCTAssertTrue(mockVoiceInputService.stopListeningForWakeWordCalled)
    }

    func testToggleHeyGwenListening_RequestsPermissionsIfNotGranted() {
        viewModel.hasPermissions = false
        viewModel.toggleHeyGwenListening()
        XCTAssertTrue(mockVoiceInputService.requestPermissionsCalled)
        XCTAssertFalse(mockVoiceInputService.startListeningForWakeWordCalled)
    }

    func testWakeWordDetected_TransitionsToActiveListening() {
        // 1. Start "Hey GWEN" listening
        viewModel.hasPermissions = true
        viewModel.toggleHeyGwenListening() // This will set VM's isListeningForHeyGwen via publisher

        // 2. Simulate wake word detected from service
        mockVoiceInputService.setWakeWordDetected(to: true)

        let expectation = XCTestExpectation(description: "Transition to active listening after wake word")

        // Check that ViewModel updates its state accordingly
        // isActivelyListening should become true, currentInput should be cleared
        viewModel.$isActivelyListening.filter { $0 == true }.sink { _ in
             XCTAssertTrue(self.viewModel.isActivelyListening)
             XCTAssertTrue(self.viewModel.currentInput.isEmpty)
             expectation.fulfill()
        }.store(in: &cancellables)

        wait(for: [expectation], timeout: 1.0)
    }

    func testTranscribedTextChanged_UpdatesCurrentInputWhenActivelyListening() {
        viewModel.isActivelyListening = true
        viewModel.isListeningForHeyGwen = false // Ensure not in wake word mode

        let newText = "This is a command"
        mockVoiceInputService.setTranscribedText(to: newText)

        XCTAssertEqual(viewModel.currentInput, newText)
    }

    func testTranscribedTextChanged_DoesNotUpdateCurrentInputWhenNotActivelyListening() {
        viewModel.isActivelyListening = false
        let initialInput = viewModel.currentInput

        mockVoiceInputService.setTranscribedText(to: "Some other text")

        XCTAssertEqual(viewModel.currentInput, initialInput)
    }

    func testRecordingStops_SendsPromptIfInputExists() {
        viewModel.isActivelyListening = true
        viewModel.isListeningForHeyGwen = false
        viewModel.currentInput = "Send this command"
        viewModel.isThinking = false // Ensure not already thinking

        mockNetworkingService.sendGwenPromptResult = .success((Data(), "OK")) // Setup mock response

        // Simulate VoiceInputService stopping recording
        mockVoiceInputService.setIsRecording(to: false)

        let expectation = XCTestExpectation(description: "Send prompt on recording stop")

        // Check if sendCurrentPrompt was called (indirectly by checking network call)
        // And if ViewModel states are updated
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { // Allow sink to fire
            XCTAssertTrue(self.mockNetworkingService.sendGwenPromptCalled)
            XCTAssertFalse(self.viewModel.isActivelyListening) // isActivelyListening should be false now
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    func testStartActiveListening_ManualMicTap() {
        viewModel.hasPermissions = true
        viewModel.isListeningForHeyGwen = true // Simulate Hey GWEN was on
        mockVoiceInputService.isListeningForWakeWordValue = true

        viewModel.startActiveListening() // User taps mic button

        XCTAssertTrue(mockVoiceInputService.stopListeningForWakeWordCalled) // Should turn off Hey GWEN
        XCTAssertTrue(mockVoiceInputService.startRecordingCalled)
        XCTAssertEqual(mockVoiceInputService.lastStartRecordingForWakeWordDetectionParam, false)
        XCTAssertTrue(viewModel.isActivelyListening) // ViewModel state
        XCTAssertTrue(viewModel.currentInput.isEmpty)
    }

    func testStopActiveListening_ManualMicTap() {
        viewModel.isActivelyListening = true
        viewModel.currentInput = "Don't send this yet"

        viewModel.stopActiveListening()

        XCTAssertTrue(mockVoiceInputService.stopRecordingCalled)
        XCTAssertFalse(viewModel.isActivelyListening)
        // Note: auto-send logic on isRecording change might send the prompt if not cleared.
        // The current test assumes stopActiveListening itself doesn't clear currentInput or auto-send.
        // The auto-send is tied to the isRecording publisher.
        XCTAssertEqual(viewModel.currentInput, "Don't send this yet")
    }
}

// MockAudioPlaybackService and its protocol are now in their own files:
// GWENApp 3/Tests/Mocks/MockAudioPlaybackService.swift
// GWENApp 3/Services/AudioPlaybackServiceProtocol.swift
