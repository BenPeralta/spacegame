import AVFoundation
import QuartzCore
import UIKit

class AudioManager {
    static let shared = AudioManager()
    
    // Haptics
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let notification = UINotificationFeedbackGenerator()
    private var lastLightHapticTime: CFTimeInterval = 0
    private var lastHeavyHapticTime: CFTimeInterval = 0
    
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
        let now = CACurrentMediaTime()
        switch style {
        case .light:
            if now - lastLightHapticTime < 0.12 { return }
            lastLightHapticTime = now
            impactLight.impactOccurred()
        case .medium:
            if now - lastLightHapticTime < 0.12 { return }
            lastLightHapticTime = now
            impactMedium.impactOccurred()
        case .heavy:
            if now - lastHeavyHapticTime < 0.20 { return }
            lastHeavyHapticTime = now
            impactHeavy.impactOccurred()
        case .soft:
            if now - lastLightHapticTime < 0.12 { return }
            lastLightHapticTime = now
            impactLight.impactOccurred() // Fallback
        case .rigid:
            if now - lastHeavyHapticTime < 0.20 { return }
            lastHeavyHapticTime = now
            impactHeavy.impactOccurred() // Fallback
        @unknown default: break
        }
    }
    
    func startBGM() {
        // Placeholder for background music load
        print("AudioManager: Start BGM")
    }
}
