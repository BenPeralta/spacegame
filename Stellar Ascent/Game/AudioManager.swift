import AVFoundation
import UIKit

class AudioManager {
    static let shared = AudioManager()
    
    // Haptics
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let notification = UINotificationFeedbackGenerator()
    
    // Audio Players
    // var bgmPlayer: AVAudioPlayer?
    // var sfxPlayers: [String: AVAudioPlayer] = [:]
    
    init() {
        impactLight.prepare()
        impactMedium.prepare()
        impactHeavy.prepare()
    }
    
    func playEvent(_ event: String) {
        switch event {
        case "absorb":
            playHaptic(style: .light)
            // playSound("pop.wav")
        case "damage":
            playHaptic(style: .heavy)
            // playSound("crash.wav")
        case "tier_up":
            notification.notificationOccurred(.success)
             // playSound("powerup.wav")
        case "game_over":
            notification.notificationOccurred(.error)
        default: break
        }
    }
    
    func playHaptic(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        switch style {
        case .light: impactLight.impactOccurred()
        case .medium: impactMedium.impactOccurred()
        case .heavy: impactHeavy.impactOccurred()
        case .soft: impactLight.impactOccurred() // Fallback
        case .rigid: impactHeavy.impactOccurred() // Fallback
        @unknown default: break
        }
    }
    
    func startBGM() {
        // Placeholder for background music load
        print("AudioManager: Start BGM")
    }
}
