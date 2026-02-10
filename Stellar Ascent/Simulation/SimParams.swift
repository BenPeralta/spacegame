import Foundation
import simd

struct SimParams {
    // Gravity (Tuned for stable orbits, not death spirals)
    static let G: Float = 80000.0  // Lower: Prevents death spirals (was 500k)
    static let softening: Float = 120.0  // Softer close-in (was 60)
    static let influenceRadius: Float = 1200.0  // Wider pull for "vastness" (was 800)
    
    // Orbit System
    static let captureRange: Float = 3.5  // Distance multiplier for manual capture
    static let minOrbitRadius: Float = 1.8  // Prevent overlap
    static let orbitDecay: Float = 0.995  // Slight inspiral for accretion
    
    // Movement
    static let playerMaxSpeed: Float = 900.0
    static let playerAccel: Float = 1400.0
    static let drag: Float = 0.04  // Reduced from 0.08 for smoother orbit following
    
    // Collision - Break-And-Accrete Model
    // Small objects (< 35% mass) merge directly and attach visually
    // Medium objects (35-80%) BREAK into smaller pieces first
    // Large objects (> 80%) are deadly
    static let absorbRatio: Float = 0.42  // Objects < 42% merge (stricter)
    static let shatterRatio: Float = 0.75   // Shatter zone 50-75%
    static let crushRatio: Float = 0.80   // Danger zone
    static let damageScale: Float = 0.22  // Reduced from 0.30
    static let knockbackScale: Float = 0.45  // Slightly increased
    static let minFragmentMass: Float = 1.5  // Always < 30% player for mass < 50
    static let shatterImpactThreshold: Float = 160.0  // Velocity threshold for shatter
    static let entityHardLimit: Int = 180  // Before 200 cap
    
    // Clamps
    static let maxEntitySpeed: Float = 1200.0
    static let maxAccel: Float = 4000.0
    
    // Size Formula
    static let baseRadius: Float = 10.0
    
    // Helper
    @inline(__always)
    static func radiusForMass(_ mass: Float) -> Float {
        // Fallback or generic usage
        return 9.0 * pow(max(mass, 0.001), 0.4)
    }
    
    // Variable Density based on Type
    static func radiusForMass(_ mass: Float, kind: EntityKind) -> Float {
        switch kind {
        case .hazard: // Gas Giants / Stars (Fluffy/Huge)
            // If mass is high enough to be a giant (e.g. > 300), use fluffy formula
            if mass > 250.0 {
                return 6.0 * pow(mass, 0.55) // Fluffier!
            }
            return 9.0 * pow(mass, 0.4) // Standard Hazard
        case .matter: // Rocky (Dense)
            return 9.0 * pow(mass, 0.38) // Denser
        case .player:
            return 9.0 * pow(mass, 0.4) // Player standard
        case .projectile:
            return 5.0 * pow(mass, 0.33)
        }
    }
}
