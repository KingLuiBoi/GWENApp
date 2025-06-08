import Foundation
import Combine
import AVFoundation

class AudioPlaybackService: ObservableObject {
    static let shared = AudioPlaybackService()
    
    private var player: AVAudioPlayer?
    private var cancellables = Set<AnyCancellable>()
    
    @Published var isPlaying = false
    @Published var progress: Float = 0.0
    @Published var duration: TimeInterval = 0.0
    
    private var progressTimer: Timer?
    
    private init() {
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set up audio session: \(error.localizedDescription)")
        }
    }
    
    func playAudio(data: Data) {
        stopAudio()
        
        do {
            player = try AVAudioPlayer(data: data)
            player?.prepareToPlay()
            player?.delegate = self
            
            if let player = player {
                duration = player.duration
                player.play()
                isPlaying = true
                
                // Start progress timer
                progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                    guard let self = self, let player = self.player else { return }
                    self.progress = Float(player.currentTime / player.duration)
                }
            }
        } catch {
            print("Failed to play audio: \(error.localizedDescription)")
        }
    }
    
    func stopAudio() {
        player?.stop()
        player = nil
        isPlaying = false
        progress = 0.0
        duration = 0.0
        
        progressTimer?.invalidate()
        progressTimer = nil
    }
    
    func pauseAudio() {
        player?.pause()
        isPlaying = false
        
        progressTimer?.invalidate()
        progressTimer = nil
    }
    
    func resumeAudio() {
        player?.play()
        isPlaying = true
        
        // Restart progress timer
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let player = self.player else { return }
            self.progress = Float(player.currentTime / player.duration)
        }
    }
    
    func seekTo(percentage: Float) {
        guard let player = player else { return }
        let targetTime = Double(percentage) * player.duration
        player.currentTime = targetTime
        progress = percentage
    }
}

extension AudioPlaybackService: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.isPlaying = false
            self?.progress = 1.0
            
            self?.progressTimer?.invalidate()
            self?.progressTimer = nil
        }
    }
}
