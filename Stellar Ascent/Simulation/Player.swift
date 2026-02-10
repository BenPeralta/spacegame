import Foundation
import simd

// MARK: - Progression Constants
struct Progression {
    struct Stage {
        let name: String
        let threshold: Float
        let visualType: VisualType
        let scale: Float
    }
    
    static let stages: [Stage] = [
        Stage(name: "Meteor",           threshold: 0,      visualType: .rock,      scale: 1.0),
        Stage(name: "Asteroid",         threshold: 25,     visualType: .rock,      scale: 1.5),
        Stage(name: "Dwarf Planet",     threshold: 80,     visualType: .ice,       scale: 2.0),
        Stage(name: "Rocky Planet",     threshold: 200,    visualType: .lava,      scale: 2.5),
        Stage(name: "Gas Giant",        threshold: 500,    visualType: .gas,       scale: 3.5),
        Stage(name: "Dwarf Star",       threshold: 1200,   visualType: .star,      scale: 4.5),
        Stage(name: "Star",             threshold: 3000,   visualType: .star,      scale: 5.5),
        Stage(name: "Giant Star",       threshold: 6000,   visualType: .star,      scale: 7.0),
        Stage(name: "Super Giant",      threshold: 12000,  visualType: .star,      scale: 9.0),
        Stage(name: "Neutron Star",     threshold: 25000,  visualType: .neutron,   scale: 2.0),
        Stage(name: "Black Hole",       threshold: 50000,  visualType: .blackHole, scale: 4.0)
    ]
    
    static let winMass: Float = 60000.0
    
    static func getStage(mass: Float) -> Stage {
        return stages.last { mass >= $0.threshold } ?? stages[0]
    }
    
    static func getNextStage(mass: Float) -> Stage? {
        return stages.first { mass < $0.threshold }
    }
    
    static func getStageIndex(mass: Float) -> Int {
        let stage = getStage(mass: mass)
        return stages.firstIndex(where: { $0.threshold == stage.threshold }) ?? 0
    }
}

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
    
    // Upgrade Stats
    var activeUpgrades: [UpgradeType: Int] = [:]
    var shatterRangeMultiplier: Float = 1.0
    var hawkingDamage: Float = 0.0
    var gammaBurstChance: Float = 0.0
    var knockbackResist: Float = 0.0
    var healOnAbsorb: Float = 0.0
    var orbitDamageMultiplier: Float = 1.0
    var rareSpawnChance: Float = 0.0
    var accelBonus: Float = 0.0
    var hasEventHorizon: Bool = false
    
    var currentStage: Progression.Stage {
        return Progression.getStage(mass: mass)
    }
    
    var stageIndex: Int {
        return Progression.getStageIndex(mass: mass)
    }
    
    mutating func updateRadius() {
        if mass >= 25000 && mass < 50000 {
            self.radius = 40.0
        } else {
            self.radius = SimParams.radiusForMass(self.mass)
        }
    }
}
