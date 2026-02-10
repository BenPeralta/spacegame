import Foundation
import simd

// MARK: - Entity Spawning
extension World {
    
    func spawnInitialMatter() {
        for _ in 0..<80 {
            spawnRandomEntity(near: .zero, minRange: 400, maxRange: 1200)
        }
        for _ in 0..<20 {
            spawnRandomEntity(near: .zero, minRange: 1500, maxRange: 2500)
        }
    }
    
    func spawnRandomEntity(near center: SIMD2<Float> = .zero, minRange: Float = 600, maxRange: Float = 1400, forceSmall: Bool = false, scaledTo: Float? = nil) {
        // GIANT IMPACTS: Rogue asteroids on collision course
        let rogueChance: Float = player.mass < 600 ? 0.05 : 0.03
        var isRogue = Float.random(in: 0...1) < rogueChance
        if scaledTo != nil {
            isRogue = false
        }
        
        let roll = Float.random(in: 0...100)
        var mass: Float = 1.0
        var kind: EntityKind = .matter
        var baseColor: SIMD4<Float> = SIMD4<Float>(0.8, 0.4, 0.9, 1.0)
        let midGame = player.mass >= 450.0 && player.mass < 900.0
        
        if let playerMass = scaledTo {
            let scaleRoll = Float.random(in: 0...100)
            if scaleRoll < 50 {
                mass = playerMass * Float.random(in: 0.1...0.3)
                kind = .matter
                baseColor = SIMD4<Float>(0.4, 0.8, 0.4, 1.0)
            } else if scaleRoll < 80 {
                mass = playerMass * Float.random(in: 0.5...0.9)
                kind = .hazard
                baseColor = SIMD4<Float>(0.8, 0.6, 0.2, 1.0)
            } else {
                mass = playerMass * Float.random(in: 1.2...2.0)
                kind = .hazard
                baseColor = SIMD4<Float>(1.0, 0.2, 0.2, 1.0)
            }
        } else if forceSmall {
            mass = Float.random(in: 3...15)
            kind = .matter
            baseColor = SIMD4<Float>(0.55, 0.5, 0.45, 1.0)
        } else if isRogue {
            // Rogue asteroids
            kind = .hazard
            if player.mass < 600 {
                mass = Float.random(in: 15...30)
                baseColor = SIMD4<Float>(0.9, 0.3, 0.2, 1.0)  // Red warning
            } else {
                mass = Float.random(in: 400...1500)
                baseColor = SIMD4<Float>(1.0, 0.2, 0.1, 1.0)  // Bright red danger
            }
        } else if midGame {
            if roll < 55 {
                mass = Float.random(in: 1...6)
                kind = .matter
                baseColor = SIMD4<Float>(0.55, 0.5, 0.45, 1.0)
            } else if roll < 85 {
                mass = Float.random(in: 12...40)
                kind = .hazard
                baseColor = SIMD4<Float>(0.6, 0.6, 0.65, 1.0)
            } else if roll < 98 {
                mass = Float.random(in: 50...180)
                kind = .hazard
                baseColor = SIMD4<Float>(0.3, 0.6, 0.8, 1.0)
            } else {
                mass = Float.random(in: 250...450)
                kind = .hazard
                baseColor = SIMD4<Float>(0.9, 0.6, 0.3, 1.0)
            }
        } else if roll < 60 {
            mass = Float.random(in: 5...25)
            kind = .matter
            baseColor = SIMD4<Float>(0.55, 0.5, 0.45, 1.0)
        } else if roll < 90 {
            mass = Float.random(in: 30...150)
            kind = .hazard
            baseColor = SIMD4<Float>(0.6, 0.6, 0.65, 1.0)
        } else {
            mass = Float.random(in: 200...600)
            kind = .hazard
            baseColor = SIMD4<Float>(0.9, 0.6, 0.3, 1.0)
        }

        var radius = SimParams.radiusForMass(mass, kind: kind)
        var pos = SIMD2<Float>.zero
        var valid = false
        
        for _ in 0..<10 {
            let angle = Float.random(in: 0...Float.pi * 2)
            let dist = Float.random(in: minRange...maxRange)
            let offset = SIMD2<Float>(cos(angle) * dist, sin(angle) * dist)
            pos = center + offset
            
            var overlap = false
            let minPlayerDist = player.radius + radius + 150.0
            if distance(player.pos, pos) < minPlayerDist {
                overlap = true
            } else {
                for e in entities {
                    if !e.alive { continue }
                    let spacing = max(200.0, max(e.radius, radius) * 3.0)
                    if distance(e.pos, pos) < (e.radius + radius + spacing) {
                        overlap = true
                        break
                    }
                }
            }
            
            if !overlap {
                valid = true
                break
            }
        }
        
        if !valid { return }
        
        if Float.random(in: 0...1) < 0.3 {
            spawnCluster(at: pos)
            return
        }
        
        let colorVar: Float
        if mass <= 5.0 {
            colorVar = 1.0
        } else {
            colorVar = Float.random(in: 0.98...1.02)
        }
        var color = baseColor * colorVar
        color.w = 1.0
        
        radius = SimParams.radiusForMass(mass, kind: kind)
        
        // Velocity: Rogues aim toward player, others drift randomly
        let driftVel: SIMD2<Float>
        if isRogue {
            let toPlayer = normalize(player.pos - pos)
            let rogueSpeed = player.mass < 600 ? Float.random(in: 80...150) : Float.random(in: 200...400)
            driftVel = toPlayer * rogueSpeed
        } else {
            let speed = Float.random(in: 10...50) / sqrt(mass) * 5.0
            let driftDir = SIMD2<Float>(Float.random(in: -1...1), Float.random(in: -1...1))
            driftVel = normalize(driftDir) * speed
        }
        
        var e = Entity(
            id: nextEntityId,
            kind: kind,
            pos: pos,
            vel: driftVel,
            mass: mass,
            radius: radius,
            health: mass * 2.0,
            color: color,
            alive: true,
            rotation: Float.random(in: 0...Float.pi * 2.0),
            spin: Float.random(in: -2.0...2.0),
            visualType: .rock
        )
        
        if e.mass > 800 {
            e.visualType = .star
        } else if e.mass > 300 {
            e.visualType = .gas
        } else if e.mass > 100 {
            e.visualType = .ice
        } else if Float.random(in: 0...1) > 0.7 {
            e.visualType = .lava
        } else {
            e.visualType = .rock
        }
        
        entities.append(e)
        nextEntityId += 1
    }
    
    func spawnCluster(at center: SIMD2<Float>) {
        let count = Int.random(in: 3...6)
        for _ in 0..<count {
            let offset = SIMD2<Float>(Float.random(in: -50...50), Float.random(in: -50...50))
            let mass = Float.random(in: 1...5)
            let vel = SIMD2<Float>(Float.random(in: -20...20), Float.random(in: -20...20))
            
            let e = Entity(
                id: nextEntityId,
                kind: .matter,
                pos: center + offset,
                vel: vel,
                mass: mass,
                radius: SimParams.radiusForMass(mass),
                health: mass,
                color: SIMD4<Float>(0.6, 0.6, 0.6, 1.0),
                alive: true,
                rotation: Float.random(in: 0...Float.pi * 2.0),
                spin: Float.random(in: -3...3),
                visualType: .rock
            )
            entities.append(e)
            nextEntityId += 1
        }
    }
}
