import Foundation

protocol AudioPlaybackServiceProtocol {
    func playAudio(data: Data)
    func stopAudio()
    // Optional: Add publishers for playback state if UI needs to react (e.g., isPlaying)
    // var isPlaying: AnyPublisher<Bool, Never> { get }
}
