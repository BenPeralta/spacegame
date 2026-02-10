import MetalKit
import simd

struct Particle {
    var position: SIMD2<Float>
    var velocity: SIMD2<Float>
    var color: SIMD4<Float>
    var size: Float
    var life: Float
    var maxLife: Float
}

class ParticleSystem {
    var particles: [Particle] = []
    let maxParticles = 2000
    
    // Metal
    var device: MTLDevice
    var buffer: MTLBuffer?
    
    init(device: MTLDevice) {
        self.device = device
        // Pre-allocate buffer?
        // Dynamic for now
    }
    
    func update(dt: Float) {
        // Update physics
        for i in (0..<particles.count).reversed() {
            particles[i].life -= dt
            if particles[i].life <= 0 {
                particles.remove(at: i) // O(n) remove, optimize with swap-remove later if needed
                continue
            }
            
            particles[i].position += particles[i].velocity * dt
            particles[i].velocity *= 0.95 // Drag
        }
    }
    
    func emit(pos: SIMD2<Float>, count: Int, color: SIMD4<Float>, speed: Float, type: String) {
        if particles.count + count > maxParticles { return }
        
        for _ in 0..<count {
            let angle = Float.random(in: 0...Float.pi * 2)
            let velDir = SIMD2<Float>(cos(angle), sin(angle))
            // Random speed
            let s = Float.random(in: speed * 0.5 ... speed * 1.5)
            
            var p = Particle(
                position: pos,
                velocity: velDir * s,
                color: color,
                size: Float.random(in: 2...5),
                life: Float.random(in: 0.5...1.0),
                maxLife: 1.0
            )
            
            // Custom behavior based on type
            if type == "absorb" {
                // Implosion? Or just sucky dust?
                // For consume pop: maybe outward bang then fade
                p.velocity = velDir * s
            } else if type == "trail" {
                p.velocity = -velDir * s * 0.2 // Small drift
                p.life = 0.3
                p.size = 3.0
            }
            
            particles.append(p)
        }
    }
    
    // Generate render instances
    func getRenderInstances() -> [InstanceData] {
        var instances: [InstanceData] = []
        // Optional: capacity
        
        for p in particles {
            // Fade alpha over life
            var c = p.color
            c.w *= (p.life / p.maxLife)
            
            instances.append(InstanceData(
                position: p.position,
                velocity: .zero,
                radius: p.size,
                color: c,
                glowIntensity: 0.8,
                seed: Float.random(in: 0...1),
                crackColor: .zero,
                crackIntensity: 0.0,
                rotation: 0.0,
                type: 0,
                time: 0.0
            ))
        }
        return instances
    }
}
