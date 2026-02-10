import Foundation
import simd

// MARK: - Entity Spawning
extension World {
    
    func spawnInitialMatter() {
        for _ in 0..<40 {
            spawnRandomEntity(near: .zero, minRange: 500, maxRange: 3000)
        }
    }
    
    func spawnRandomEntity(near center: SIMD2<Float> = .zero, minRange: Float = 1000, maxRange: Float = 2000) {
        var pos = SIMD2<Float>.zero
        var radius: Float = 10.0
        var valid = false
        
        for _ in 0..<10 {
            let angle = Float.random(in: 0...Float.pi * 2)
            let dist = Float.random(in: minRange...maxRange)
            let offset = SIMD2<Float>(cos(angle) * dist, sin(angle) * dist)
            pos = center + offset
            
            radius = 150.0
            
            var overlap = false
            for e in entities {
                if !e.alive { continue }
                let spacing = max(200.0, e.radius * 3.0)
                if distance(e.pos, pos) < (e.radius + radius + spacing) {
                    overlap = true
                    break
                }
            }
            
            if !overlap {
                valid = true
                break
            }
        }
        
        if !valid { return }
        
        // GIANT IMPACTS: Rogue asteroids on collision course
        let rogueChance: Float = player.mass < 600 ? 0.05 : 0.03
        let isRogue = Float.random(in: 0...1) < rogueChance
        
        let roll = Float.random(in: 0...100)
        var mass: Float = 1.0
        var kind: EntityKind = .matter
        var baseColor: SIMD4<Float> = SIMD4<Float>(0.8, 0.4, 0.9, 1.0)
        
        if isRogue {
            // Rogue asteroids
            kind = .hazard
            if player.mass < 600 {
                mass = Float.random(in: 15...30)
                baseColor = SIMD4<Float>(0.9, 0.3, 0.2, 1.0)  // Red warning
            } else {
                mass = Float.random(in: 400...1500)
                baseColor = SIMD4<Float>(1.0, 0.2, 0.1, 1.0)  // Bright red danger
            }
        } else if roll < 70 {
            mass = Float.random(in: 1...5)
            kind = .matter
            baseColor = SIMD4<Float>(0.55, 0.5, 0.45, 1.0)
        } else if roll < 90 {
            mass = Float.random(in: 12...35)
            kind = .hazard
            baseColor = SIMD4<Float>(0.6, 0.6, 0.65, 1.0)
        } else if roll < 98 {
            mass = Float.random(in: 40...120)
            kind = .hazard
            baseColor = SIMD4<Float>(0.3, 0.6, 0.8, 1.0)
        } else {
            mass = Float.random(in: 300...800)
            kind = .hazard
            baseColor = SIMD4<Float>(0.9, 0.6, 0.3, 1.0)
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
}
