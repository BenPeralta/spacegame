import Foundation
import simd

enum EntityKind {
    case matter // Absorbed/Crushed
    case hazard // Damages player
    case player // The player entity itself (if treated as an Entity)
    case projectile // Shots fired by player/enemies
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
}
struct Attachment {
    var offset: SIMD2<Float>
    var radius: Float
    var color: SIMD4<Float>
    var seed: Float
}
