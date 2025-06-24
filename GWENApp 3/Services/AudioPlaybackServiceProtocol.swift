import Foundation

protocol AudioPlaybackServiceProtocol: AnyObject {
    func playAudio(data: Data) async throws
    func stopAudio()
    func pauseAudio()
    func resumeAudio()
    func seekTo(percentage: Float)
}


