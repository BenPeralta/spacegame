import Foundation
import simd

// MARK: - Physics & Collisions
extension World {
    
    func applyHawkingRadiation(dt: Float) {
        if player.hawkingDamage <= 0 { return }
        
        let burnRange = player.radius * 2.5
        for i in 0..<entities.count {
            if !entities[i].alive { continue }
            let dist = distance(player.pos, entities[i].pos)
            if dist < burnRange {
                let burn = player.hawkingDamage * dt * (1.0 - dist / burnRange)
                entities[i].health -= burn
                
                if Float.random(in: 0...1) < 0.1 {
                    events.append(.damage(pos: entities[i].pos))
                }
                
                if entities[i].health <= 0 {
                    let debris = generateDebris(from: entities[i], impactVel: .zero)
                    if entities.count + debris.count < 300 {
                        entities.append(contentsOf: debris)
                        nextEntityId += debris.count
                    }
                    entities[i].alive = false
                    events.append(.shatter(pos: entities[i].pos, color: entities[i].color))
                }
            }
        }
    }
    
    func triggerGammaRayBurst(at pos: SIMD2<Float>) {
        events.append(.shatter(pos: pos, color: SIMD4(1, 0.8, 0.2, 1)))
        AudioManager.shared.playEvent("damage")
        
        let range: Float = 400.0
        for i in 0..<entities.count {
            if !entities[i].alive { continue }
            if distance(pos, entities[i].pos) < range {
                entities[i].vel += normalize(entities[i].pos - pos) * 800.0
                entities[i].health -= 50.0
            }
        }
    }
    
    // MARK: Player Movement
    func applyPlayerMovement(dt: Float, input: SIMD2<Float>) {
        let accel = input * (SimParams.playerAccel * (1.0 + player.accelBonus))
        player.vel += accel * dt
        player.vel *= (1.0 - SimParams.drag)
        
        let speed = length(player.vel)
        let maxSpeed = SimParams.playerMaxSpeed * (1.0 + player.speedBonus)
        if speed > maxSpeed {
            player.vel *= (maxSpeed / speed)
        }
        
        player.pos += player.vel * dt
        
        // Apply spin
        player.rotation += player.spin * dt
        player.spin *= 0.98
    }
    
    // MARK: Gravity
    func applyGravity(targetIndex: Int, dt: Float) {
        let r = player.pos - entities[targetIndex].pos
        let dist = length(r)
        
        let effectiveRange = SimParams.influenceRadius * player.gravityMultiplier
        if dist < 1.0 || dist > effectiveRange { return }
        
        let dir = r / dist
        
        let denom = (dist * dist) + (SimParams.softening * SimParams.softening)
        var accelMag = SimParams.G * player.mass / denom
        
        accelMag /= sqrt(entities[targetIndex].mass)
        
        if player.evoPath == .cradleOfLife {
            accelMag *= 1.5
        }
        
        let accelRad = dir * accelMag
        
        let tangent = SIMD2<Float>(-dir.y, dir.x)
        let tangentMag = accelMag * 1.2
        let accelTan = tangent * tangentMag
        
        let totalAccel = accelRad + accelTan
        
        let aLen = length(totalAccel)
        if aLen > SimParams.maxAccel {
             entities[targetIndex].vel += (totalAccel / aLen) * SimParams.maxAccel * dt
        } else {
             entities[targetIndex].vel += totalAccel * dt
        }
    }
    
    // MARK: Roche Limit
    func checkRocheLimit(targetIndex: Int) {
        let e = entities[targetIndex]
        let dist = distance(player.pos, e.pos)
        let baseLimit = player.radius * 1.5
        let rocheLimit = baseLimit * player.shatterRangeMultiplier
        
        if dist < rocheLimit && e.mass < player.mass * 0.2 {
            let debris = generateDebris(from: entities[targetIndex], impactVel: player.vel * 0.1)
            if entities.count + debris.count < 300 {
                entities.append(contentsOf: debris)
                nextEntityId += debris.count
            }
            entities[targetIndex].alive = false
            events.append(.shatter(pos: e.pos, color: e.color))
        }
    }
    
    // MARK: Player Collision (FIXED: No more God Mode)
    func resolveCollision(targetIndex: Int) {
        let dist = distance(player.pos, entities[targetIndex].pos)
        let combinedRadius = player.radius + entities[targetIndex].radius
        
        if dist < combinedRadius {
            let e = entities[targetIndex]
            let relVel = player.vel - e.vel
            let impactSpeed = length(relVel)
            let massRatio = e.mass / player.mass
            
            // Black hole behavior (Unchanged)
            if player.tier >= 5 {
                let pullDir = normalize(player.pos - e.pos)
                entities[targetIndex].vel += pullDir * 1000.0 * 0.016
                if dist < player.radius * 0.5 {
                    entities[targetIndex].alive = false
                    player.mass += e.mass * 0.1
                    player.updateRadius()
                    return
                }
            }
            
            // Absolute Zero (Blue) active: unstoppable
            let isBlueActive = player.evoPath == .frozenFortress && player.abilityActiveTime > 0
            if isBlueActive {
                let debris = generateDebris(from: entities[targetIndex], impactVel: player.vel * 0.8)
                if entities.count + debris.count < 300 {
                    entities.append(contentsOf: debris)
                    nextEntityId += debris.count
                }
                entities[targetIndex].alive = false
                events.append(.shatter(pos: e.pos, color: e.color))
                return
            }
            
            // Event Horizon upgrade
            if player.hasEventHorizon && e.mass < player.mass * 0.1 {
                player.mass += e.mass
                player.updateRadius()
                entities[targetIndex].alive = false
                return
            }
            
            // Spin physics (Unchanged)
            let normal = normalize(player.pos - e.pos)
            let tangent = SIMD2<Float>(-normal.y, normal.x)
            let torque = dot(relVel, tangent) * 0.05
            player.spin += torque / player.mass
            
            let shatterThreshold: Float = 550.0
            
            if massRatio <= SimParams.absorbRatio && impactSpeed < shatterThreshold {
                if !player.isCompact && player.attachments.count < 30 {
                    let relativePos = e.pos - player.pos
                    let angle = atan2(relativePos.y, relativePos.x)
                    let dist = max(1.0, length(relativePos))
                    let direction: Float = Float.random(in: 0...1) > 0.5 ? 1.0 : -1.0
                    let speed = (Float.random(in: 0.5...1.5) / sqrt(dist / 50.0)) * direction
                    let att = Attachment(
                        offset: relativePos,
                        angle: angle,
                        orbitDist: dist,
                        orbitSpeed: speed,
                        radius: e.radius,
                        color: e.color,
                        seed: Float(e.id),
                        visualType: e.visualType
                    )
                    player.attachments.append(att)
                }
                
                player.mass += e.mass
                player.updateRadius()
                if player.healOnAbsorb > 0 {
                    player.health = min(player.maxHealth, player.health + player.healOnAbsorb)
                } else {
                    player.health = min(player.health + e.mass * 0.1, player.maxHealth)
                }
                entities[targetIndex].alive = false
                events.append(.absorb(pos: e.pos, color: e.color))
                AudioManager.shared.playEvent("absorb")
            } else {
                if massRatio > 1.2 && impactSpeed > 150 {
                    events.append(.shatter(pos: player.pos, color: player.color))
                    createPlayerDebris()
                    player.health = 0
                    gameOver = true
                    AudioManager.shared.playEvent("damage")
                    return
                }
                
                if massRatio > 0.8 {
                    let difficulty = min(1.0, player.mass / 800.0)
                    let dmg = impactSpeed * massRatio * SimParams.damageScale * player.defenseMultiplier * (1.0 + difficulty)
                    
                    if player.invulnTime <= 0 {
                        player.health -= dmg
                        player.invulnTime = 0.2
                        events.append(.damage(pos: (player.pos + e.pos) * 0.5))
                        AudioManager.shared.playEvent("damage")
                    }
                    
                    let impulse = normal * (impactSpeed * 0.8)
                    player.vel += impulse / player.mass
                    entities[targetIndex].vel -= impulse / e.mass
                    
                    let overlap = combinedRadius - dist
                    player.pos += normal * (overlap * 0.5)
                    
                    if player.health <= 0 {
                        createPlayerDebris()
                        gameOver = true
                    }
                    return
                }
                
                if impactSpeed > 100 || massRatio < 0.5 {
                    if player.gammaBurstChance > 0, Float.random(in: 0...1) < player.gammaBurstChance {
                        triggerGammaRayBurst(at: (player.pos + e.pos) * 0.5)
                    }
                    let debris = generateDebris(from: entities[targetIndex], impactVel: player.vel * 0.5)
                    if entities.count + debris.count < 300 {
                        entities.append(contentsOf: debris)
                        nextEntityId += debris.count
                    }
                    entities[targetIndex].alive = false
                    events.append(.shatter(pos: e.pos, color: e.color))
                    player.vel *= 0.95
                }
            }
        }
    }
    
    // MARK: Entity-Entity Collisions (CRASH FIXED)
    func resolveEntityCollisions() {
        var newDebris: [Entity] = []
        
        for i in 0..<entities.count {
            if !entities[i].alive { continue }
            
            for j in (i+1)..<entities.count {
                if !entities[j].alive { continue }
                
                let dist = distance(entities[i].pos, entities[j].pos)
                let combinedRadius = entities[i].radius + entities[j].radius
                
                if dist < combinedRadius {
                    let mi = entities[i].mass
                    let mj = entities[j].mass
                    let relVel = entities[i].vel - entities[j].vel
                    let impactSpeed = length(relVel)
                    
                    // Spin transfer
                    let normal = normalize(entities[i].pos - entities[j].pos)
                    let tangent = SIMD2<Float>(-normal.y, normal.x)
                    let torque = dot(relVel, tangent) * 0.1
                    
                    entities[i].spin -= torque / mi
                    entities[j].spin += torque / mj
                    
                    if impactSpeed > 200 {
                        if mi > mj {
                            let debris = generateDebris(from: entities[j], impactVel: entities[i].vel * 0.5)
                            newDebris.append(contentsOf: debris)
                            entities[j].alive = false
                        } else {
                            let debris = generateDebris(from: entities[i], impactVel: entities[j].vel * 0.5)
                            newDebris.append(contentsOf: debris)
                            entities[i].alive = false
                        }
                        events.append(.shatter(pos: (entities[i].pos + entities[j].pos) * 0.5, color: SIMD4(1, 1, 1, 1)))
                    } else {
                        let restitution: Float = 0.5
                        let velAlongNormal = dot(relVel, normal)
                        
                        if velAlongNormal < 0 {
                            let impulse = -(1.0 + restitution) * velAlongNormal
                            let impulsePerMass = impulse / (1.0/mi + 1.0/mj)
                            
                            entities[i].vel += normal * (impulsePerMass / mi)
                            entities[j].vel -= normal * (impulsePerMass / mj)
                        }
                        
                        let overlap = combinedRadius - dist
                        if overlap > 0 {
                            let separation = normal * (overlap * 0.5)
                            entities[i].pos += separation
                            entities[j].pos -= separation
                        }
                    }
                }
            }
        }
        
        if !newDebris.isEmpty {
            if entities.count + newDebris.count < 300 {
                entities.append(contentsOf: newDebris)
                nextEntityId += newDebris.count
            }
        }
    }
    
    // MARK: Safe Debris Generator
    func generateDebris(from e: Entity, impactVel: SIMD2<Float>) -> [Entity] {
        var debrisList: [Entity] = []
        let pieces = Int.random(in: 2...4)
        let pieceMass = e.mass / Float(pieces)
        
        if pieceMass < 0.5 { return [] }
        
        var idBase = nextEntityId
        for _ in 0..<pieces {
            let angle = Float.random(in: 0...Float.pi * 2.0)
            let dir = SIMD2<Float>(cos(angle), sin(angle))
            let speed = Float.random(in: 50...200)
            let spawnPos = e.pos + dir * (e.radius * 0.8)
            
            let debris = Entity(
                id: idBase,
                kind: .matter,
                pos: spawnPos,
                vel: e.vel + impactVel * 0.3 + dir * speed,
                mass: pieceMass,
                radius: SimParams.radiusForMass(pieceMass),
                health: pieceMass,
                color: e.color,
                alive: true,
                rotation: Float.random(in: 0...Float.pi * 2.0),
                spin: Float.random(in: -5...5),
                visualType: e.visualType
            )
            debrisList.append(debris)
            idBase += 1
        }
        return debrisList
    }
    
    // MARK: Player Death
    func createPlayerDebris() {
        let debrisCount = Int.random(in: 3...5)
        let debrisMass = player.mass / Float(debrisCount)
        
        for _ in 0..<debrisCount {
            let angle = Float.random(in: 0...(2.0 * .pi))
            let scatterDir = SIMD2<Float>(cos(angle), sin(angle))
            let explosionSpeed = Float.random(in: 200...500)
            
            let debris = Entity(
                id: nextEntityId,
                kind: .matter,
                pos: player.pos + scatterDir * player.radius,
                vel: player.vel + scatterDir * explosionSpeed,
                mass: debrisMass,
                radius: SimParams.radiusForMass(debrisMass, kind: .matter),
                health: debrisMass,
                color: player.color,
                alive: true,
                rotation: Float.random(in: 0...Float.pi * 2.0),
                spin: Float.random(in: -5...5),
                visualType: .rock
            )
            entities.append(debris)
            nextEntityId += 1
        }
    }
}
