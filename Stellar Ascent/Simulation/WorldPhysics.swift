import Foundation
import simd

// MARK: - Physics & Collisions
extension World {
    
    // MARK: Player Movement
    func applyPlayerMovement(dt: Float, input: SIMD2<Float>) {
        let accel = input * SimParams.playerAccel
        player.vel += accel * dt
        player.vel *= (1.0 - SimParams.drag)
        
        let speed = length(player.vel)
        if speed > SimParams.playerMaxSpeed {
            player.vel *= (SimParams.playerMaxSpeed / speed)
        }
        
        player.pos += player.vel * dt
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
        let rocheLimit = player.radius * 2.5
        
        if dist < rocheLimit && e.mass < player.mass * 0.1 {
            entities[targetIndex].alive = false
            events.append(.shatter(pos: e.pos, color: e.color))
            
            let dustCount = Int.random(in: 2...3)
            let dustMass = e.mass / Float(dustCount)
            let entityLimit = 200
            
            for _ in 0..<dustCount {
                if entities.count >= entityLimit { break }
                let angle = Float.random(in: 0...(2.0 * .pi))
                let ringRadius = dist + Float.random(in: -5...5)
                let offset = SIMD2<Float>(cos(angle), sin(angle)) * ringRadius
                
                let orbitSpeed = sqrt(SimParams.G * player.mass / ringRadius)
                let tangent = SIMD2<Float>(-offset.y, offset.x) / ringRadius
                let ringVel = player.vel + tangent * orbitSpeed
                
                let dust = Entity(
                    id: nextEntityId,
                    kind: .matter,
                    pos: player.pos + offset,
                    vel: ringVel,
                    mass: dustMass,
                    radius: SimParams.radiusForMass(dustMass),
                    health: dustMass,
                    color: e.color,
                    alive: true
                )
                entities.append(dust)
                nextEntityId += 1
            }
        }
    }
    
    // MARK: Player Collision
    func resolveCollision(targetIndex: Int) {
        let dist = distance(player.pos, entities[targetIndex].pos)
        let combinedRadius = player.radius + entities[targetIndex].radius
        
        if dist < combinedRadius {
            let e = entities[targetIndex]
            let relVel = player.vel - e.vel
            let impactSpeed = length(relVel)
            let massRatio = e.mass / player.mass
            
            // Scale absorb down with mass (harder late-game)
            let difficulty = min(1.0, player.mass / 800.0)
            let effectiveAbsorb = SimParams.absorbRatio * (1.0 - difficulty * 0.4)  // 0.50 → 0.30 at high mass
            
            if massRatio <= effectiveAbsorb {
                // ABSORB
                if !player.isCompact && player.attachments.count < 30 {
                    let goldenAngle: Float = 137.5 * .pi / 180.0
                    let index = Float(player.attachments.count)
                    let angle = index * goldenAngle
                    
                    let radiusVariation = Float.random(in: 0.9...1.1)
                    let attachDist = player.radius * radiusVariation
                    let attachPos = SIMD2<Float>(cos(angle), sin(angle)) * attachDist
                    
                    let att = Attachment(
                        offset: attachPos,
                        radius: e.radius,
                        color: e.color,
                        seed: Float(e.id)
                    )
                    player.attachments.append(att)
                }
                
                player.mass += e.mass
                player.updateRadius()
                player.health = min(player.health + e.mass * 0.1, player.maxHealth)
                
                entities[targetIndex].alive = false
                events.append(.absorb(pos: e.pos, color: e.color))
                AudioManager.shared.playEvent("absorb")
                return
            }
            
            // TIDAL DISRUPTION (Spaghettification)
            // Pre-600: Stretch bounces on mid-sized hazards (teaches speed requirement)
            // Post-600: Full shred on slow grazes of massive objects
            if massRatio >= 0.5 && massRatio <= 0.8 && impactSpeed < 300 {
                if player.mass < 600 {
                    // Pre-600: Stretch bounce (chip damage + knockback)
                    let dir = normalize(player.pos - e.pos)
                    player.vel += dir * -300.0  // Strong bounce
                    player.health -= 10.0
                    player.invulnTime = 0.3
                    
                    events.append(.damage(pos: player.pos))
                    AudioManager.shared.playEvent("damage")
                    return
                } else if massRatio > 0.6 {
                    // Post-600: Full shred (50% mass loss + debris)
                    player.mass *= 0.5
                    player.updateRadius()
                    player.health -= 50.0
                    
                    // Scatter debris
                    createPlayerDebris()
                    createPlayerDebris()
                    
                    events.append(.shatter(pos: player.pos, color: player.color))
                    AudioManager.shared.playEvent("damage")
                    
                    if player.health <= 0 {
                        gameOver = true
                    }
                    return
                }
            }
            
            if massRatio >= SimParams.crushRatio {
                // CRUSH
                events.append(.shatter(pos: player.pos, color: player.color))
                createPlayerDebris()
                
                player.health = 0
                gameOver = true
                AudioManager.shared.playEvent("damage")
                
            } else {
                // IMPACT
                if player.invulnTime <= 0 {
                    let impactForce = impactSpeed * massRatio
                    // Scale damage with difficulty for late-game challenge
                    let difficulty = min(1.0, player.mass / 800.0)
                    let playerDamage = impactForce * SimParams.damageScale * player.defenseMultiplier * (1.0 + difficulty)
                    player.health -= playerDamage
                    player.invulnTime = 0.3
                    
                    let dir = normalize(player.pos - e.pos)
                    player.vel += dir * (SimParams.knockbackScale * 600.0 * massRatio)
                    
                    events.append(.damage(pos: (player.pos + e.pos) * 0.5))
                    
                    if player.health <= 0 {
                        createPlayerDebris()
                        gameOver = true
                        return
                    }
                }
                
                // SHATTER
                var remainingMass = e.mass
                var debrisList: [Float] = []
                
                let pieceCount = min(3, max(2, Int(e.mass / 8.0)))
                
                for i in 0..<pieceCount {
                    if i == pieceCount - 1 {
                        debrisList.append(remainingMass)
                    } else {
                        let portion = Float.random(in: 0.2...0.5)
                        let pieceMass = remainingMass * portion
                        let clampedMass = max(1.0, min(pieceMass, remainingMass * 0.8))
                        debrisList.append(clampedMass)
                        remainingMass -= clampedMass
                    }
                }
                
                let impactDir = length(player.vel) > 0.01 ? normalize(player.vel) : SIMD2<Float>(1, 0)
                let entityLimit = 200
                
                for debrisMass in debrisList {
                    if entities.count >= entityLimit { break }
                    
                    let baseAngle = atan2(impactDir.y, impactDir.x)
                    let spreadAngle = Float.random(in: -Float.pi * 0.7 ... Float.pi * 0.7)
                    let scatterAngle = baseAngle + spreadAngle
                    let scatterDir = SIMD2<Float>(cos(scatterAngle), sin(scatterAngle))
                    
                    let offset = scatterDir * e.radius * 1.2
                    
                    let scatterSpeed = Float.random(in: 80...200)
                    var debrisVel = scatterDir * scatterSpeed
                    debrisVel += e.vel * 0.5
                    debrisVel += player.vel * 0.3
                    
                    let debris = Entity(
                        id: nextEntityId,
                        kind: .matter,
                        pos: e.pos + offset,
                        vel: debrisVel,
                        mass: debrisMass,
                        radius: SimParams.radiusForMass(debrisMass, kind: .matter),
                        health: debrisMass * 1.5,
                        color: e.color,
                        alive: true
                    )
                    entities.append(debris)
                    nextEntityId += 1
                }
                
                entities[targetIndex].alive = false
                events.append(.shatter(pos: e.pos, color: e.color))
                AudioManager.shared.playEvent("damage")
            }
        }
    }
    
    // MARK: Entity-Entity Collisions
    func resolveEntityCollisions() {
        for i in 0..<entities.count {
            if !entities[i].alive { continue }
            
            for j in (i+1)..<entities.count {
                if !entities[j].alive { continue }
                
                let dist = distance(entities[i].pos, entities[j].pos)
                let combinedRadius = entities[i].radius + entities[j].radius
                
                if dist < combinedRadius {
                    let massRatio = entities[j].mass / entities[i].mass
                    
                    if massRatio < 0.5 {
                        entities[i].mass += entities[j].mass
                        entities[j].alive = false
                    } else if massRatio > 2.0 {
                        entities[j].mass += entities[i].mass
                        entities[i].alive = false
                    } else {
                        let normal = normalize(entities[j].pos - entities[i].pos)
                        let relVel = entities[j].vel - entities[i].vel
                        let velAlongNormal = dot(relVel, normal)
                        
                        if velAlongNormal < 0 {
                            let restitution: Float = 0.3
                            let impulse = -(1.0 + restitution) * velAlongNormal
                            let impulsePerMass = impulse / (1.0/entities[i].mass + 1.0/entities[j].mass)
                            
                            entities[i].vel -= normal * (impulsePerMass / entities[i].mass)
                            entities[j].vel += normal * (impulsePerMass / entities[j].mass)
                        }
                        
                        let overlap = combinedRadius - dist
                        if overlap > 0 {
                            let separation = normal * (overlap * 0.5)
                            entities[i].pos -= separation
                            entities[j].pos += separation
                        }
                    }
                }
            }
        }
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
                alive: true
            )
            entities.append(debris)
            nextEntityId += 1
        }
    }
}
