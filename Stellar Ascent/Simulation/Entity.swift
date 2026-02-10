import Foundation
import simd

enum EntityKind {
    case matter // Absorbed/Crushed
    case hazard // Damages player
    case player // The player entity itself (if treated as an Entity)
    case projectile // Shots fired by player/enemies
}

enum VisualType: Int {
    case rock = 0
    case ice = 1
    case lava = 2
    case gas = 3
    case star = 4
    case blackHole = 5
    case trail = 6
    case jet = 7
    case neutron = 8
    case dwarfStar = 9
}

struct Entity {
    var id: Int
    var kind: EntityKind
    var pos: SIMD2<Float>
    var vel: SIMD2<Float>
    var mass: Float
    var radius: Float
    var health: Float
    var color: SIMD4<Float> // Visuals
    var alive: Bool = true
    
    // Drifter Star mechanics
    var rotation: Float = 0.0 // Angle in radians
    var spin: Float = 0.0     // Angular velocity
    var visualType: VisualType = .rock
}
struct Attachment {
    var offset: SIMD2<Float>
    
    var angle: Float
    var orbitDist: Float
    var orbitSpeed: Float
    
    var radius: Float
    var color: SIMD4<Float>
    var seed: Float
    var visualType: VisualType = .rock
}
