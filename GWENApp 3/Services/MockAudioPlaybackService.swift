import Foundation

class MockAudioPlaybackService: AudioPlaybackServiceProtocol {
    func playAudio(data: Data) async throws {
        print("[Mock] Playing audio (mock).")
    }

    func stopAudio() {
        print("[Mock] Stopping audio.")
    }

    func pauseAudio() {
        print("[Mock] Pausing audio.")
    }

    func resumeAudio() {
        print("[Mock] Resuming audio.")
    }

    func seekTo(percentage: Float) {
        print("[Mock] Seeking to \(percentage * 100)%")
    }
}


