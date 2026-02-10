import Foundation
import simd
import UIKit

class World {
    var player: Player
    var entities: [Entity] = []
    
    // Systems
    var spatialGrid: SpatialGrid
    
    // Events
    enum GameEvent {
        case absorb(pos: SIMD2<Float>, color: SIMD4<Float>)
        case damage(pos: SIMD2<Float>)
        case shatter(pos: SIMD2<Float>, color: SIMD4<Float>)
        case evolve(tier: Int)
    }
    var events: [GameEvent] = []
    
    // State
    var time: Float = 0.0
    var nextEntityId: Int = 0
    var gameOver: Bool = false
    
    // Callbacks
    var onEvolutionTrigger: (() -> Void)?
    
    // Power-up milestone tracking (ensures exact triggers even if mass jumps)
    var powerUpMilestonesTriggered: Set<Float> = []
    
    init() {
        self.player = Player()
        self.player.mass = 5.0
        self.player.updateRadius()
        self.player.color = SIMD4<Float>(0.55, 0.5, 0.45, 1.0)
        
        self.spatialGrid = SpatialGrid(cellSize: 180.0)
        
        spawnInitialMatter()
    }
    
    func update(dt: Float, input: SIMD2<Float>) {
        time += dt
        
        // 1. Grid Rebuild
        spatialGrid.clear()
        var activeCount = 0
        for i in 0..<entities.count {
            if entities[i].alive {
                spatialGrid.insert(entityIndex: i, pos: entities[i].pos)
                activeCount += 1
            }
        }
        
        // Despawn Far Entities
        let despawnDist: Float = 3500.0
        for i in 0..<entities.count {
            if entities[i].alive {
                if distance(entities[i].pos, player.pos) > despawnDist {
                    entities[i].alive = false
                }
            }
        }

        // Active Count (Difficulty-scaled spawning)
        let difficulty = min(1.0, player.mass / 800.0)
        
        if activeCount < 60 + Int(difficulty * 40) {
            let minR = 1200 + difficulty * 1500
            let maxR = 3500 + difficulty * 2000
            spawnRandomEntity(near: player.pos, minRange: minR, maxRange: maxR)
        }
        
        // More giants late-game to prevent AFK win
        if difficulty > 0.5 && Float.random(in: 0...1) < difficulty * 0.15 {
            spawnRandomEntity(near: player.pos, minRange: 800, maxRange: 1500)
        }
        
        // 2. Player Movement (Only if alive)
        if !gameOver {
            applyPlayerMovement(dt: dt, input: input)
            checkTier()
        }
        
        // 3. Query Neighbors
        let gravityRange = SimParams.influenceRadius
        let gravityCandidates = spatialGrid.query(center: player.pos, radius: gravityRange)
        
        // 4. Entity Update & Interaction
        for i in 0..<entities.count {
            if !entities[i].alive { continue }
            
            // Orbital Decay
            let distToPlayer = distance(entities[i].pos, player.pos)
            if distToPlayer < player.radius * 5.0 && entities[i].mass < player.mass * 0.2 {
                let decayDir = normalize(player.pos - entities[i].pos)
                let decayForce: Float = 15.0
                entities[i].vel += decayDir * decayForce * dt
            }
            
            // Clamp Speed
            let speed = length(entities[i].vel)
            if speed > SimParams.maxEntitySpeed {
                entities[i].vel *= (SimParams.maxEntitySpeed / speed)
            }
            // Move
            entities[i].pos += entities[i].vel * dt
        }
        
        // Entity interactions
        resolveEntityCollisions()
        
        // Physics Interactions (Candidates only)
        for idx in gravityCandidates {
            if idx >= entities.count || !entities[idx].alive { continue }
            
            if !gameOver {
                applyGravity(targetIndex: idx, dt: dt)
                
                if player.mass >= 40.0 {
                    checkRocheLimit(targetIndex: idx)
                }
                
                if entities[idx].alive {
                    resolveCollision(targetIndex: idx)
                }
            }
        }
    }
    
    func getRenderInstances() -> [InstanceData] {
        var instances: [InstanceData] = []
        
        if !gameOver {
            // Player
            instances.append(InstanceData(
                position: player.pos,
                velocity: player.vel,
                radius: player.radius,
                color: player.color,
                glowIntensity: player.evoPath == .none ? 0.0 : (1.0 + Float(player.tier) * 0.2),
                seed: 0.123,
                crackColor: player.crackColor,
                crackIntensity: player.crackIntensity + Float(player.tier) * 0.15
            ))
            
            // Player Attachments
            for att in player.attachments {
                instances.append(InstanceData(
                    position: player.pos + att.offset,
                    velocity: player.vel,
                    radius: att.radius,
                    color: att.color,
                    glowIntensity: 0.0,
                    seed: att.seed,
                    crackColor: .zero,
                    crackIntensity: 0.0
                ))
            }
        }
        
        // Entities
        for e in entities {
            if !e.alive { continue }
            instances.append(InstanceData(
                position: e.pos,
                velocity: e.vel,
                radius: e.radius,
                color: e.color,
                glowIntensity: e.kind == .hazard ? 0.8 : 0.3,
                seed: 0.123,
                crackColor: .zero,
                crackIntensity: 0.0
            ))
        }
        return instances
    }
}
