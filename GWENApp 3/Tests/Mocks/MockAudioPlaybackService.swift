import Foundation
@testable import GWENApp_3 // Replace with your app module name

class MockAudioPlaybackService: AudioPlaybackServiceProtocol {
    var playAudioCalled = false
    var lastPlayedAudioData: Data?
    var stopAudioCalled = false

    func reset() {
        playAudioCalled = false
        lastPlayedAudioData = nil
        stopAudioCalled = false
    }

    func playAudio(data: Data) {
        playAudioCalled = true
        lastPlayedAudioData = data
        // Simulate playing audio: can add a delay or a callback if needed for tests
        print("MockAudioPlaybackService: Playing audio data of size \(data.count)")
    }

    func stopAudio() {
        stopAudioCalled = true
        print("MockAudioPlaybackService: Stopping audio")
    }
}
