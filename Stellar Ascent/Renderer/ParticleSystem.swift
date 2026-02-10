import MetalKit
import simd

struct Particle {
    var position: SIMD2<Float>
    var velocity: SIMD2<Float>
    var color: SIMD4<Float>
    var size: Float
    var life: Float
    var maxLife: Float
    var type: Int32
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
            
            if particles[i].type == 6 {
                particles[i].size += 15.0 * dt
                let progress = 1.0 - (particles[i].life / particles[i].maxLife)
                if progress > 0.2 {
                    particles[i].color.x *= 0.95
                    particles[i].color.y *= 0.90
                }
            } else {
                particles[i].velocity *= 0.95
            }
        }
    }
    
    func emit(pos: SIMD2<Float>, count: Int, color: SIMD4<Float>, speed: Float, type: String, direction: SIMD2<Float> = .zero) {
        if particles.count + count > maxParticles { return }
        
        for _ in 0..<count {
            var p = Particle(
                position: pos,
                velocity: .zero,
                color: color,
                size: 1.0,
                life: 1.0,
                maxLife: 1.0,
                type: 0
            )
            
            // Custom behavior based on type
            if type == "absorb" {
                let angle = Float.random(in: 0...Float.pi * 2)
                let velDir = SIMD2<Float>(cos(angle), sin(angle))
                p.velocity = velDir * Float.random(in: 50...150)
                p.color = color
                p.size = Float.random(in: 3...6)
                p.life = 0.5
                p.type = 0
            } else if type == "trail" {
                p.color = SIMD4<Float>(1.0, 0.8, 0.2, 1.0)
                let jitter = SIMD2<Float>(Float.random(in: -8...8), Float.random(in: -8...8))
                p.position = pos + jitter
                if length(direction) > 0.001 {
                    p.velocity = normalize(direction) * speed * 0.1
                }
                p.velocity += SIMD2<Float>(Float.random(in: -10...10), Float.random(in: -10...10))
                p.size = Float.random(in: 12...22)
                p.life = Float.random(in: 0.2...0.4)
                p.type = 6
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
                glowIntensity: p.type == 6 ? 1.0 : 0.8,
                seed: Float.random(in: 0...1),
                crackColor: .zero,
                crackIntensity: 0.0,
                rotation: Float.random(in: 0...Float.pi * 2.0),
                type: p.type,
                time: 0.0
            ))
        }
        return instances
    }
}
