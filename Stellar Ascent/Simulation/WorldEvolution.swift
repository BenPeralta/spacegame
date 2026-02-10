import Foundation
import simd

// MARK: - Evolution & Progression
extension World {
    
    // MARK: Tier Progression
    func checkTier() {
        let mass = player.mass
        let oldTier = player.tier
        var newTier = 0
        
        if mass >= 8000 { newTier = 8 }      // Universe
        else if mass >= 5000 { newTier = 7 } // Black Hole
        else if mass >= 2500 { newTier = 6 }
        else if mass >= 1000 { newTier = 5 } // Star
        else if mass >= 600 { newTier = 4 }  // Gas Giant
        else if mass >= 250 { newTier = 3 }  // Large Planet
        else if mass >= 60 { newTier = 2 }   // Planet
        else if mass >= 25 { newTier = 1 }   // Asteroid
        else { newTier = 0 }                 // Meteor
        
        if newTier != oldTier {
            player.tier = newTier
            events.append(.evolve(tier: newTier))
            
            // Compact at Asteroid+ (tier 1+) for clean sphere
            if newTier >= 1 && !player.isCompact {
                compactAttachments()
            }
            
            updatePlayerVisualsForTier(newTier)
            
            // === POWER-UP TRIGGERS (milestone-based, fires exactly once) ===
            let milestones: [Float] = [25, 60, 1000, 8000]
            for milestone in milestones {
                if mass >= milestone && !powerUpMilestonesTriggered.contains(milestone) {
                    if milestone < 8000 {
                        onEvolutionTrigger?()
                    } else {
                        triggerPathEnding()
                    }
                    powerUpMilestonesTriggered.insert(milestone)
                    break  // One at a time
                }
            }
            
            // Supernova chance increases with tier
            if newTier >= 5 && Float.random(in: 0...1) < Float(newTier - 4) * 0.25 {
                supernova()
            }
        }
    }
    
    // MARK: Power-Up Selection
    func selectPath(_ path: EvoPath) {
        player.evoPath = path
        player.evoHistory.append(path)  // Track for endings & star evo
        player.attachments.removeAll() // Merge debris into new form
        
        switch path {
        case .frozenFortress:
            player.defenseMultiplier = 0.35      // 65% less damage
            player.mass *= 1.35
            player.maxHealth *= 2.0
            player.health = player.maxHealth
            player.crackColor = SIMD4<Float>(0.4, 0.9, 1.0, 1.0)
        case .cradleOfLife:
            player.gravityMultiplier = 2.8
            player.damageToMassRecovery = 0.25   // Absorb gives extra mass
            player.crackColor = SIMD4<Float>(0.2, 1.0, 0.4, 1.0)
        case .warPlanet:
            player.damageMultiplier = 2.5
            player.rammingDamageBonus = 1.8      // Orbiters hit harder
            player.abilityCooldown = 0.0
            player.crackColor = SIMD4<Float>(1.0, 0.4, 0.2, 1.0)
        case .lava:
            player.damageToMassRecovery = 0.45   // Shatter → 45% mass recovery
            player.crackColor = SIMD4<Float>(1.0, 0.6, 0.1, 1.0)
        case .rings:
            player.rammingDamageBonus = 2.5
            player.crackColor = SIMD4<Float>(0.8, 0.8, 1.0, 1.0)
        case .redDwarf:
            player.speedBonus = 0.3  // 30% speed boost
            player.crackColor = SIMD4<Float>(1.0, 0.4, 0.2, 1.0)
        case .yellowStar:
            player.crackColor = SIMD4<Float>(1.0, 1.0, 0.7, 1.0)
        case .blueGiant:
            player.gravityMultiplier = 3.5
            player.crackColor = SIMD4<Float>(0.7, 0.9, 1.0, 1.0)
        default: break
        }
        
        // Set color based on path (with hybrid blending if multiple choices)
        let newColor = pathColor(for: path)
        if player.evoHistory.count > 1, let lastPath = player.evoHistory.dropLast().last {
            let lastColor = pathColor(for: lastPath)
            player.color = mix(lastColor, newColor, t: 0.5)  // 50/50 hybrid for clear evolution
        } else {
            player.color = newColor  // First choice - pure color
        }
        
        player.crackIntensity = 0.7 + Float(player.tier) * 0.1
        player.updateRadius()
    }
    
    // MARK: Helper Functions
    private func pathColor(for path: EvoPath) -> SIMD4<Float> {
        switch path {
        case .frozenFortress: return SIMD4<Float>(0.6, 0.8, 1.0, 1.0)
        case .cradleOfLife: return SIMD4<Float>(0.3, 0.8, 0.4, 1.0)
        case .warPlanet: return SIMD4<Float>(0.9, 0.3, 0.2, 1.0)
        case .lava: return SIMD4<Float>(0.9, 0.5, 0.2, 1.0)
        case .rings: return SIMD4<Float>(0.7, 0.7, 0.9, 1.0)
        case .redDwarf: return SIMD4<Float>(0.9, 0.3, 0.2, 1.0)
        case .yellowStar: return SIMD4<Float>(1.0, 0.9, 0.6, 1.0)
        case .blueGiant: return SIMD4<Float>(0.6, 0.8, 1.0, 1.0)
        default: return SIMD4<Float>(0.5, 0.5, 0.55, 1.0)
        }
    }
    
    // MARK: Tier Transitions
    func supernova() {
        // Mass loss
        player.mass *= 0.7
        player.updateRadius()
        
        // Power gains
        player.gravityMultiplier += 0.5
        player.defenseMultiplier *= 1.3
        
        // Scatter fragments
        for _ in 0..<8 {
            let angle = Float.random(in: 0...2 * .pi)
            let dir = SIMD2<Float>(cos(angle), sin(angle))
            let fragMass = player.mass * 0.05
            
            let frag = Entity(
                id: nextEntityId,
                kind: .matter,
                pos: player.pos + dir * player.radius * 1.5,
                vel: dir * Float.random(in: 300...600) + player.vel,
                mass: fragMass,
                radius: SimParams.radiusForMass(fragMass, kind: .matter),
                health: fragMass * 2,
                color: player.color,
                alive: true
            )
            entities.append(frag)
            nextEntityId += 1
        }
        
        // Visual explosion
        events.append(.shatter(pos: player.pos, color: SIMD4<Float>(1, 0.5, 0, 1)))
        AudioManager.shared.playEvent("damage")  // Epic boom
    }
    
    func triggerPathEnding() {
        gameOver = true
        
        switch player.evoPath {
        case .cradleOfLife:
            // Spawn friendly life entities
            for _ in 0..<12 {
                let angle = Float.random(in: 0...2 * .pi)
                let offset = SIMD2<Float>(cos(angle), sin(angle)) * player.radius * 2.5
                let life = Entity(
                    id: nextEntityId, kind: .matter, pos: player.pos + offset,
                    vel: .zero, mass: 5, radius: 12, health: 100,
                    color: SIMD4(0.2, 0.8, 0.3, 1.0), alive: true
                )
                entities.append(life)
                nextEntityId += 1
            }
        case .warPlanet:
            // Explosive chain supernova
            for _ in 0..<20 {
                let dir = SIMD2<Float>(Float.random(in: -1...1), Float.random(in: -1...1))
                let frag = Entity(
                    id: nextEntityId, kind: .matter, pos: player.pos,
                    vel: normalize(dir) * 800, mass: 20,
                    radius: 30, health: 50, color: SIMD4(1, 0.3, 0.1, 1), alive: true
                )
                entities.append(frag)
                nextEntityId += 1
            }
            events.append(.shatter(pos: player.pos, color: SIMD4(1, 0.2, 0, 1)))
        default:
            break
        }
    }
    
    func compactAttachments() {
        player.isCompact = true
        
        // Blend attachment colors into player base color
        if !player.attachments.isEmpty {
            var totalR: Float = 0, totalG: Float = 0, totalB: Float = 0
            for att in player.attachments {
                totalR += att.color.x * att.color.w
                totalG += att.color.y * att.color.w
                totalB += att.color.z * att.color.w
            }
            let count = Float(player.attachments.count)
            let blend = SIMD4<Float>(totalR / count, totalG / count, totalB / count, 1.0)
            player.color = mix(player.color, blend, t: 0.4)  // 40% blend for subtle influence
        }
        
        player.attachments.removeAll()
        
        // Visual "melt" poof
        events.append(.shatter(pos: player.pos, color: player.color))
        events.append(.absorb(pos: player.pos, color: player.color))  // Inward suck effect
    }
    
    func updatePlayerVisualsForTier(_ tier: Int) {
        // Removed - color now handled only in selectPath for persistence
    }
    
    // MARK: Abilities
    func useAbility() {
        if player.evoPath == .warPlanet && player.abilityCooldown <= 0 {
            player.abilityCooldown = player.maxAbilityCooldown
            
            events.append(.absorb(pos: player.pos, color: SIMD4<Float>(1, 0, 0, 1)))
            events.append(.shatter(pos: player.pos, color: player.color))
            
            let shockwaveRange: Float = 800.0
            for i in 0..<entities.count {
                if !entities[i].alive { continue }
                let dist = distance(entities[i].pos, player.pos)
                if dist < shockwaveRange {
                    let dir = normalize(entities[i].pos - player.pos)
                    let force = (1.0 - dist / shockwaveRange) * 2000.0
                    entities[i].vel += dir * force
                    
                    entities[i].health -= player.damageMultiplier * 50.0
                    if entities[i].health <= 0 {
                        entities[i].alive = false
                        events.append(.shatter(pos: entities[i].pos, color: entities[i].color))
                    }
                }
            }
            AudioManager.shared.playEvent("damage")
        }
    }
}
