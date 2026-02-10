import Foundation
import simd

enum EvoPath: Int {
    case none = 0
    // Planet tier branches (Tier 2 - mass 40+)
    case frozenFortress  // +50% defense
    case cradleOfLife    // +50% gravity
    case warPlanet       // +50% damage
    case lava            // +20% damage-to-mass recovery
    case rings           // +30% ramming damage
    // Star tier branches (Tier 4 - mass 1000+)
    case redDwarf        // +20% speed
    case yellowStar      // +15% resource spawn
    case blueGiant       // +30% gravity strength
}

// Orbiter: Captured entities in stable circular orbits
struct Orbiter {
    var entityIndex: Int  // Reference to entities[] array
    var orbitRadius: Float
    var angle: Float = 0.0
    var omega: Float  // Angular speed (rad/s)
}

struct Player {
    var pos: SIMD2<Float> = .zero
    var vel: SIMD2<Float> = .zero
    
    // Rotation physics
    var rotation: Float = 0.0
    var spin: Float = 0.0
    var mass: Float = 1.0
    var radius: Float = SimParams.baseRadius
    var health: Float = 100.0
    var maxHealth: Float = 100.0
    var tier: Int = 0
    var evoPath: EvoPath = .none
    var invulnTime: Float = 0.0 // post-hit grace period
    var color: SIMD4<Float> = SIMD4<Float>(0.55, 0.5, 0.45, 1.0) // Match environment meteors
    
    // Evolution Stats
    var defenseMultiplier: Float = 1.0
    var gravityMultiplier: Float = 1.0
    var damageMultiplier: Float = 1.0
    var damageToMassRecovery: Float = 0.0  // Lava path bonus
    var rammingDamageBonus: Float = 0.0    // Rings path bonus
    var speedBonus: Float = 0.0            // Red Dwarf bonus
    
    // Evolution tracking
    var evoHistory: [EvoPath] = []  // Track path for endings
    
    // Visual evolution (cracks)
    var crackColor: SIMD4<Float> = .zero
    var crackIntensity: Float = 0.0
    
    // Power-up trigger flags (prevent spam)
    var hasTriggeredPowerUp1: Bool = false  // Mass 25
    var hasTriggeredPowerUp2: Bool = false  // Mass 60
    var hasTriggeredPowerUp3: Bool = false  // Mass 1000
    
    // Ability
    var abilityCooldown: Float = 0.0
    var maxAbilityCooldown: Float = 5.0 // Default 5s
    var abilityActiveTime: Float = 0.0  // Active window for abilities
    
    // Accretion (Visual Clumping)
    var attachments: [Attachment] = []
    var isCompact: Bool = false // Hydrostatic Equilibrium (Smooth Sphere) flag
    
    // Orbit System (Manual Capture)
    var orbiters: [Orbiter] = []  // Max 12 for perf/mobile
    var captureCooldown: Float = 0.0
    
    mutating func updateRadius() {
        self.radius = SimParams.radiusForMass(self.mass)
    }
}
