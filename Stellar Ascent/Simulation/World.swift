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
    
    // Endgame State
    var isBigBangActive: Bool = false
    var bigBangTimer: Float = 0.0
    var flashIntensity: Float = 0.0
    let blackHoleCriticalMass: Float = Progression.winMass
    
    // Callbacks
    var onEvolutionTrigger: (() -> Void)?
    
    // Progression tracking
    var lastTriggeredThreshold: Float = 0.0
    
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
        
        // Endgame sequence (Implosion -> Flash -> Reset)
        if player.currentStage.visualType == .blackHole && player.mass >= blackHoleCriticalMass {
            if !isBigBangActive {
                triggerBigBang()
            }
        }
        
        if isBigBangActive {
            updateBigBang(dt: dt)
            return
        }
        
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
        let despawnDist: Float = 2000.0
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
            let minR: Float = 700 + difficulty * 200
            let maxR: Float = 1400 + difficulty * 500
            if Float.random(in: 0...1) < 0.4 {
                spawnRandomEntity(near: player.pos, minRange: minR, maxRange: maxR, forceSmall: true)
            } else {
                spawnRandomEntity(near: player.pos, minRange: minR, maxRange: maxR)
            }
        }
        
        // More giants late-game to prevent AFK win
        if difficulty > 0.5 && Float.random(in: 0...1) < difficulty * 0.15 {
            spawnRandomEntity(near: player.pos, minRange: 800, maxRange: 1500)
        }
        
        // 2. Player Movement (Only if alive)
        if !gameOver {
            applyPlayerMovement(dt: dt, input: input)
            checkTier()
            
            // Update orbiting attachments
            for i in 0..<player.attachments.count {
                var att = player.attachments[i]
                att.angle += att.orbitSpeed * dt
                att.offset = SIMD2<Float>(
                    cos(att.angle) * att.orbitDist,
                    sin(att.angle) * att.orbitDist
                )
                player.attachments[i] = att
            }
        }
        
        // 3. Query Neighbors
        let gravityRange = SimParams.influenceRadius
        let gravityCandidates = spatialGrid.query(center: player.pos, radius: gravityRange)
        
        // 4. Entity Update & Interaction
        for i in 0..<entities.count {
            if !entities[i].alive { continue }
            
            // Apply spin to rotation
            entities[i].rotation += entities[i].spin * dt

            // AI: Chaser behavior for hazards
            if entities[i].kind == .hazard {
                let distToPlayer = distance(entities[i].pos, player.pos)
                if distToPlayer < 1200.0 {
                    let dir = normalize(player.pos - entities[i].pos)
                    let chaseSpeed: Float = 80.0
                    entities[i].vel += dir * chaseSpeed * dt
                    
                    if length(entities[i].vel) > 0.01 {
                        entities[i].rotation = atan2(entities[i].vel.y, entities[i].vel.x)
                    }
                }
            }
            
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
        applyHawkingRadiation(dt: dt)
        
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
            let playerType = player.currentStage.visualType
            let stageIndex = player.stageIndex
            
            // Player
            var glow = player.evoPath == .none ? 0.0 : (1.0 + Float(stageIndex) * 0.2)
            if player.hawkingDamage > 0 {
                glow += 0.5 + sin(time * 10.0) * 0.2
            }
            if player.mass >= 12000 && player.mass < 25000 {
                glow += sin(time * 5.0) * 0.3
            }
            instances.append(InstanceData(
                position: player.pos,
                velocity: player.vel,
                radius: player.radius,
                color: player.color,
                glowIntensity: glow,
                seed: 0.123,
                crackColor: player.crackColor,
                crackIntensity: player.crackIntensity + Float(stageIndex) * 0.15,
                rotation: player.rotation,
                type: Int32(playerType.rawValue),
                time: time
            ))
            
            if player.defenseMultiplier < 0.8 {
                instances.append(InstanceData(
                    position: player.pos,
                    velocity: player.vel,
                    radius: player.radius * 1.2,
                    color: SIMD4<Float>(0.0, 0.5, 1.0, 0.2),
                    glowIntensity: 1.0,
                    seed: 0,
                    crackColor: .zero,
                    crackIntensity: 0.0,
                    rotation: -player.rotation,
                    type: Int32(VisualType.trail.rawValue),
                    time: time
                ))
            }
            
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
                    crackIntensity: 0.0,
                    rotation: player.rotation,
                    type: Int32(att.visualType.rawValue),
                    time: time
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
                seed: Float(e.id),
                crackColor: .zero,
                crackIntensity: 0.0,
                rotation: e.rotation,
                type: Int32(e.visualType.rawValue),
                time: time
            ))
        }
        return instances
    }
    
    // MARK: - Big Bang
    func triggerBigBang() {
        isBigBangActive = true
        AudioManager.shared.playEvent("absorb")
        
        // Violent pull towards center
        for i in 0..<entities.count {
            if entities[i].alive {
                let dir = normalize(player.pos - entities[i].pos)
                entities[i].vel = dir * 2000.0
            }
        }
    }
    
    func updateBigBang(dt: Float) {
        bigBangTimer += dt
        
        // Flash ramps from 3s to 5s
        if bigBangTimer > 3.0 {
            flashIntensity = min(1.0, (bigBangTimer - 3.0) / 2.0)
        }
        
        if bigBangTimer > 6.0 {
            resetGame()
        }
    }
    
    func resetGame() {
        player = Player()
        player.mass = 5.0
        player.updateRadius()
        player.color = SIMD4<Float>(0.55, 0.5, 0.45, 1.0)
        
        entities.removeAll(keepingCapacity: true)
        spatialGrid.clear()
        
        isBigBangActive = false
        bigBangTimer = 0.0
        flashIntensity = 0.0
        nextEntityId = 0
        time = 0.0
        gameOver = false
        lastTriggeredThreshold = 0.0
        
        spawnInitialMatter()
    }
}
