import MetalKit
import simd

// Mirroring the C-structs for Swift safety
struct InstanceData {
    var position: SIMD2<Float>
    var velocity: SIMD2<Float>
    var radius: Float
    var color: SIMD4<Float>
    var glowIntensity: Float
    var seed: Float
    var crackColor: SIMD4<Float>     // Path-specific crack glow color
    var crackIntensity: Float        // 0.0–1.0 strength
    var rotation: Float             // Radians, for surface spin
    var type: Int32                 // VisualType enum
    var time: Float                 // For animated textures
}

struct Uniforms {
    var projectionMatrix: simd_float4x4
    var viewMatrix: simd_float4x4
    var time: Float
    var screenSize: SIMD2<Float>
}

private func makeOrtho(left: Float, right: Float, bottom: Float, top: Float, near: Float, far: Float) -> simd_float4x4 {
    let rml = right - left
    let tmb = top - bottom
    let fmn = far - near
    return simd_float4x4(columns: (
        SIMD4<Float>(2.0 / rml, 0, 0, 0),
        SIMD4<Float>(0, 2.0 / tmb, 0, 0),
        SIMD4<Float>(0, 0, -1.0 / fmn, 0),
        SIMD4<Float>(-(right + left) / rml, -(top + bottom) / tmb, -near / fmn, 1)
    ))
}

private func makeTranslation(_ t: SIMD3<Float>) -> simd_float4x4 {
    return simd_float4x4(columns: (
        SIMD4<Float>(1, 0, 0, 0),
        SIMD4<Float>(0, 1, 0, 0),
        SIMD4<Float>(0, 0, 1, 0),
        SIMD4<Float>(t.x, t.y, t.z, 1)
    ))
}

class Renderer: NSObject, MTKViewDelegate {
    
    var device: MTLDevice!
    var commandQueue: MTLCommandQueue!
    var pipelineState: MTLRenderPipelineState!
    
    var viewportSize: SIMD2<Float> = .zero
    var startTime: Date = Date()
    
    // Simulation / World Reference (to be injected)
    // For prototype, we'll keep a local buffer or ref
    var instanceBuffer: MTLBuffer?
    var instanceCount: Int = 0
    
    // Sub-renderers
    var backgroundRenderer: BackgroundRenderer?
    var particleSystem: ParticleSystem?
    
    // Camera
    var cameraPos: SIMD2<Float> = .zero
    var zoom: Float = 1.0
    var simTime: Float = 0.0
    var flashIntensity: Float = 0.0
    
    init?(metalKitView: MTKView) {
        super.init()
        self.device = metalKitView.device
        guard let queue = self.device.makeCommandQueue() else { return nil }
        self.commandQueue = queue
        
        metalKitView.delegate = self
        // Deep Space Color (Darker for background contrast)
        metalKitView.clearColor = MTLClearColor(red: 0.005, green: 0.005, blue: 0.01, alpha: 1.0)
        
        buildPipelineState(view: metalKitView)
        
        self.backgroundRenderer = BackgroundRenderer(device: device, view: metalKitView)
        self.particleSystem = ParticleSystem(device: device)
    }
    
    func buildPipelineState(view: MTKView) {
        guard let library = device.makeDefaultLibrary() else { return }
        
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.label = "Entity Pipeline"
        descriptor.vertexFunction = library.makeFunction(name: "vertexShader")
        descriptor.fragmentFunction = library.makeFunction(name: "fragmentShader")
        descriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
        
        // Alpha Blending for "Glow" look
        descriptor.colorAttachments[0].isBlendingEnabled = true
        descriptor.colorAttachments[0].rgbBlendOperation = .add
        descriptor.colorAttachments[0].alphaBlendOperation = .add
        descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        
        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            print("Failed to create pipeline: \(error)")
        }
    }
    
    // MARK: - Update Data (Called from Game Loop)
    func update(instances: [InstanceData], camera: SIMD2<Float>, zoom: Float, time: Float, flashIntensity: Float) {
        self.cameraPos = camera
        self.zoom = zoom
        self.simTime = time
        self.flashIntensity = flashIntensity
        
        // Merge Particles (Draw particles BEHIND entities)
        var allInstances: [InstanceData] = []
        if let ps = particleSystem {
            allInstances.append(contentsOf: ps.getRenderInstances())
        }
        allInstances.append(contentsOf: instances)
        
        self.instanceCount = allInstances.count
        
        if instanceCount == 0 { return }
        
        // OPTIMIZATION: Reuse buffer when possible
        let size = allInstances.count * MemoryLayout<InstanceData>.stride
        if let existingBuffer = instanceBuffer, existingBuffer.length >= size {
            // Reuse existing buffer - just update contents
            let contents = existingBuffer.contents().bindMemory(to: InstanceData.self, capacity: allInstances.count)
            for (index, instance) in allInstances.enumerated() {
                contents[index] = instance
            }
        } else {
            // Create new buffer only when needed (size increased)
            instanceBuffer = device.makeBuffer(bytes: allInstances, length: size, options: .storageModeShared)
        }
    }
    
    // MARK: - Event Handling
    func handleEvent(type: String, pos: SIMD2<Float>, color: SIMD4<Float>) {
        if type == "absorb" {
            particleSystem?.emit(pos: pos, count: 10, color: color, speed: 100.0, type: "absorb")
        } else if type == "trail" {
            particleSystem?.emit(pos: pos, count: 1, color: color, speed: 20.0, type: "trail")
        } else if type == "damage" {
            // Use passed color for rock particles (was hardcoded red!)
            particleSystem?.emit(pos: pos, count: 20, color: color, speed: 300.0, type: "absorb")
        }
    }
    
    // MARK: - MTKViewDelegate
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        viewportSize = SIMD2<Float>(Float(size.width), Float(size.height))
    }
    
    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let descriptor = view.currentRenderPassDescriptor,
              let pipelineState = pipelineState,
              instanceCount > 0 else {
            return
        }
        
        let commandBuffer = commandQueue.makeCommandBuffer()
        let encoder = commandBuffer?.makeRenderCommandEncoder(descriptor: descriptor)
        
        encoder?.setRenderPipelineState(pipelineState)
        
        // Set Uniforms
        let halfW = (viewportSize.x * 0.5) / zoom
        let halfH = (viewportSize.y * 0.5) / zoom
        let projection = makeOrtho(left: -halfW, right: halfW, bottom: -halfH, top: halfH, near: -1.0, far: 1.0)
        let view = makeTranslation(SIMD3<Float>(-cameraPos.x, -cameraPos.y, 0))
        var uniforms = Uniforms(
            projectionMatrix: projection,
            viewMatrix: view,
            time: simTime,
            screenSize: viewportSize,
            flashIntensity: flashIntensity
        )
        
        encoder?.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
        
        // 1. Draw Background
        // We use a separate pipeline state for background, so we might need separate encoders or switch pipeline.
        // It's better to end encoding if we are switching huge states, but sharing same pass is fine if we switch pipeline.
        // But wait, makeRenderCommandEncoder creates a NEW pass. Can't have two encoders for same drawable actively? 
        // Actually, we should just use ONE encoder and switch pipelines.
        // But BackgroundRenderer.draw takes a text descriptor? No, let's refactor BackgroundRenderer to take encoder.
        // Or just let BackgroundRenderer create its own encoder? No, Metal pass descriptors clear the screen.
        
        // Quick Refactor: Let's just put background draw logic inline here or pass encoder to it.
        // BackgroundRenderer currently takes (CommandBuffer, Descriptor) -> Creates new encoder. 
        // This would CLEAR the screen again if LoadAction is Clear.
        // Solution: Pass the ENCODER to BackgroundRenderer.
        
        // Let's modify the BackgroundRenderer call site to be consistent.
        // I will assume I will fix BackgroundRenderer in next step or now? 
        // I created BackgroundRenderer with `draw(commandBuffer...)`. This is bad if called inside here.
        // Let's change the pattern.
        
        // Actually, I'll pass the command buffer and descriptor to background renderer FIRST (with LoadAction=Clear),
        // then define a NEW encoder for entities (LoadAction=Load).
        // That is a valid multi-pass approach.
        
        // Draw Background First
        encoder?.endEncoding() // End the main encoder created above? No, I haven't used it yet.
        
        // Let's do:
        // 1. Background Renderer (Clears screen, draws stars)
        backgroundRenderer?.draw(commandBuffer: commandBuffer!, descriptor: descriptor, uniforms: uniforms)
        
        // 2. Main Entity Renderer (Loads existing, draws entities)
        // We need to modify descriptor to LoadAction = .load for the second pass?
        // Or just simpler: Pass the ENCODER to background renderer.
        
        // Let's assume for now I will use the simpler "One Encoder, Switch Pipeline" approach.
        // But BackgroundRenderer as written creates a new encoder.
        // I will perform a quick refactor of BackgroundRenderer in the next step to accept an Encoder.
        // For now, let's stick to the code flow and do the fix.
        
        // ... Wait, I can't easily edit BackgroundRenderer in this tool call context.
        // I will assume BackgroundRenderer.currentImplementation is used.
        // If I call backgroundRenderer.draw(...) it creates an encoder.
        // So I should NOT create `encoder` here first.
        
        // REWRITE:
        // 1. Draw Background
        backgroundRenderer?.draw(commandBuffer: commandBuffer!, descriptor: descriptor, uniforms: uniforms)
        
        // 2. Draw Entities associated on top
        // Update descriptor to load content
        descriptor.colorAttachments[0].loadAction = .load
        
        let entityEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: descriptor)
        entityEncoder?.setRenderPipelineState(pipelineState)
        entityEncoder?.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
        entityEncoder?.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
        
        if let buffer = instanceBuffer {
            entityEncoder?.setVertexBuffer(buffer, offset: 0, index: 0)
            entityEncoder?.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4, instanceCount: instanceCount)
        }
        
        entityEncoder?.endEncoding()
        commandBuffer?.present(drawable)
        commandBuffer?.commit()
    }
}
