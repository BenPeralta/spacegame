import MetalKit
import simd

class BackgroundRenderer {
    var device: MTLDevice
    var pipelineState: MTLRenderPipelineState!
    var starBuffer: MTLBuffer?
    var starCount: Int = 0
    
    struct StarVertex {
        var position: SIMD2<Float>
        var color: SIMD4<Float>
        var size: Float
        var depth: Float // 0.0 (near) to 1.0 (far), used for parallax speed
    }
    
    var nebulaPipeline: MTLRenderPipelineState!
    
    init(device: MTLDevice, view: MTKView) {
        self.device = device
        buildPipeline(view: view)
        generateStars()
    }
    
    func buildPipeline(view: MTKView) {
        guard let library = device.makeDefaultLibrary() else { return }
        
        // 1. Star Pipeline
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.label = "Star Pipeline"
        descriptor.vertexFunction = library.makeFunction(name: "backgroundVertexShader")
        descriptor.fragmentFunction = library.makeFunction(name: "backgroundFragmentShader")
        descriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
        
        // Additive blending for stars
        descriptor.colorAttachments[0].isBlendingEnabled = true
        descriptor.colorAttachments[0].rgbBlendOperation = .add
        descriptor.colorAttachments[0].alphaBlendOperation = .add
        descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].destinationRGBBlendFactor = .one
        
        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            print("Star pipeline error: \(error)")
        }
        
        // 2. Nebula Pipeline
        let nebDesc = MTLRenderPipelineDescriptor()
        nebDesc.label = "Nebula Pipeline"
        nebDesc.vertexFunction = library.makeFunction(name: "nebulaVertex")
        nebDesc.fragmentFunction = library.makeFunction(name: "nebulaFragment")
        nebDesc.colorAttachments[0].pixelFormat = view.colorPixelFormat
        
        // Normal blending (drawn first, but let's allow alpha mix with clear color)
        nebDesc.colorAttachments[0].isBlendingEnabled = true
        nebDesc.colorAttachments[0].rgbBlendOperation = .add
        nebDesc.colorAttachments[0].alphaBlendOperation = .add
        nebDesc.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        nebDesc.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        
        do {
            nebulaPipeline = try device.makeRenderPipelineState(descriptor: nebDesc)
        } catch {
            print("Nebula pipeline error: \(error)")
        }
    }
    
    func generateStars() {
        var stars: [StarVertex] = []
        let count = 2000
        
        // Generate a large field of stars
        let fieldSize: Float = 4000
        
        for _ in 0..<count {
            let pos = SIMD2<Float>(
                Float.random(in: -fieldSize...fieldSize),
                Float.random(in: -fieldSize...fieldSize)
            )
            
            // Depth: 0.1 (Close/Fast) -> 0.9 (Far/Slow)
            let depth = Float.random(in: 0.1...0.9)
            
            // Size based on depth (closer = bigger)
            let size = max(2.0, (1.0 - depth) * 5.0)
            
            // Color varying slightly (Blue/White/Purple)
            let brightness = Float.random(in: 0.5...1.0)
            let color = SIMD4<Float>(
                brightness * (0.8 + Float.random(in: -0.1...0.1)),
                brightness * (0.9 + Float.random(in: -0.1...0.1)),
                brightness * 1.0,
                brightness * (1.0 - depth * 0.5) // Fade distant stars
            )
            
            stars.append(StarVertex(position: pos, color: color, size: size, depth: depth))
        }
        
        self.starCount = stars.count
        self.starBuffer = device.makeBuffer(bytes: stars, length: stars.count * 32, options: .storageModeShared)
    }
    
    func draw(commandBuffer: MTLCommandBuffer, descriptor: MTLRenderPassDescriptor, uniforms: Uniforms) {
        guard let pipelineState = pipelineState, let nebulaPipeline = nebulaPipeline, let buffer = starBuffer else { return }
        
        let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)
        var vertUniforms = uniforms
        
        // 1. Draw Nebula (Fullscreen Quad)
        encoder?.pushDebugGroup("Nebula")
        encoder?.setRenderPipelineState(nebulaPipeline)
        encoder?.setVertexBytes(&vertUniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
        encoder?.setFragmentBytes(&vertUniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
        encoder?.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder?.popDebugGroup()
        
        // 2. Draw Stars
        encoder?.pushDebugGroup("Stars")
        encoder?.setRenderPipelineState(pipelineState)
        encoder?.setVertexBytes(&vertUniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
        encoder?.setVertexBuffer(buffer, offset: 0, index: 0)
        encoder?.drawPrimitives(type: .point, vertexStart: 0, vertexCount: starCount)
        encoder?.popDebugGroup()
        
        encoder?.endEncoding()
    }
}
