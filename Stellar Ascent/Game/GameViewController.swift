import UIKit
import MetalKit
import SwiftUI
import Combine

enum GameState {
    case menu
    case playing
    case paused
    case gameOver
}

// Coordinate between SwiftUI and UIKit/Metal
class GameCoordinator: ObservableObject {
    @Published var gameState: GameState = .menu
    
    @Published var score: Int = 0
    @Published var health: Float = 100
    @Published var tier: String = "Asteroid"
    // gameOver is now derived from gameState == .gameOver
    var gameOver: Bool { gameState == .gameOver }
    
    // Evolution
    @Published var showEvolutionSelection: Bool = false
    @Published var selectedPath: EvoPath = .none
    @Published var abilityCooldown: Float = 0.0
    
    var inputVector: SIMD2<Float> = .zero
    var capturePressed: Bool = false  // Manual orbit capture
    
    // Actions
    var onAbilityPress: (() -> Void)?
    var onPathSelect: ((EvoPath) -> Void)?
    var onStartGame: (() -> Void)?
    var onQuitGame: (() -> Void)?
}


class GameViewController: UIViewController {
    
    var mtkView: MTKView!
    var renderer: Renderer!
    var world: World!
    var coordinator: GameCoordinator?
    // Removed local isPaused - rely on coordinator.gameState
    
    var displayLink: CADisplayLink?
    var lastFrameTime: CFTimeInterval = 0
    var lastHapticTime: CFTimeInterval = 0 // Throttle haptics
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 1. Setup Metal View
        mtkView = MTKView(frame: self.view.bounds)
        mtkView.device = MTLCreateSystemDefaultDevice()
        mtkView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        // Energy Optimization: Cap frame rate to 60 FPS
        mtkView.preferredFramesPerSecond = 60
        
        self.view.addSubview(mtkView)
        
        // 2. Setup Renderer
        guard let r = Renderer(metalKitView: mtkView) else {
            print("Renderer initialization failed")
            return
        }
        self.renderer = r
        
        // 3. Setup World
        self.world = World()
        
        // 4. Setup Callbacks
        setupCallbacks()
        
        // 5. Start Game Loop
        startLoop()
        
        // 6. Setup Restart Observer
        NotificationCenter.default.addObserver(self, selector: #selector(restartGame), name: NSNotification.Name("RestartGame"), object: nil)
        
        print("🚀 [STELLAR ASCENT] Game initialized successfully!")
    }
    
    func setupCallbacks() {
        guard let coordinator = self.coordinator else { return }
        
        // Input Handling
        coordinator.onAbilityPress = { [weak self] in
            self?.world.useAbility()
        }
        
        coordinator.onPathSelect = { [weak self] path in
            self?.world.selectPath(path)
            self?.coordinator?.selectedPath = path
            // Game state is set to .playing in SwiftUI view
        }
        
        coordinator.onStartGame = { [weak self] in
            self?.restartGame() // Ensure fresh start
        }
        
        coordinator.onQuitGame = {
            // Stop logic? Just rely on state
        }
        
        // World Callbacks
        world.onEvolutionTrigger = { [weak self] in
            DispatchQueue.main.async {
                self?.coordinator?.showEvolutionSelection = true
                self?.coordinator?.gameState = .paused // Pause game logic for selection
            }
        }
    }
    
    func startLoop() {
        lastFrameTime = CACurrentMediaTime()
        displayLink = CADisplayLink(target: self, selector: #selector(gameLoop))
        
        // Energy Optimization: Cap to 60 FPS
        if #available(iOS 15.0, *) {
            displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
        } else {
            displayLink?.preferredFramesPerSecond = 60
        }
        
        displayLink?.add(to: .current, forMode: .common)
    }
    
    @objc func gameLoop(displayLink: CADisplayLink) {
        // Only update world if playing
        guard let coordinator = coordinator, coordinator.gameState == .playing else {
            lastFrameTime = CACurrentMediaTime() // Keep time synced
            
            // Still render though? Maybe strict pause freezes rendering too?
            // If we want to see the frozen frame, we should render but not update.
            // For now, let's render static frame if paused
            if coordinator?.gameState == .paused || coordinator?.gameState == .gameOver {
                 // Render last frame without update
                 let instances = world.getRenderInstances()
                 let camera = world.player.pos
                 let targetZoom = 100.0 / (world.player.radius + 60.0)
                 let zoom: Float = max(0.15, min(2.0, targetZoom))
                 renderer.update(instances: instances, camera: camera, zoom: zoom, time: world.time, flashIntensity: world.flashIntensity, playerVel: world.player.vel, playerPos: world.player.pos)
            }
            return
        }
        
        let currentTime = CACurrentMediaTime()
        let dt = Float(currentTime - lastFrameTime)
        lastFrameTime = currentTime
        
        // Input from Coordinator (SwiftUI)
        let input = coordinator.inputVector
        
        // Physics Step (Simple Fixed DT approximation for MVP: just use dt with max clamp)
        let clampedDT = min(dt, 0.05) // Prevent spiral of death
        world.update(dt: clampedDT, input: input)
        
        // Process Events
        for event in world.events {
            switch event {
            case .absorb(let pos, let color):
                renderer.handleEvent(type: "absorb", pos: pos, color: color)
                AudioManager.shared.playEvent("absorb")
            case .damage(let pos):
                renderer.handleEvent(type: "damage", pos: pos, color: .zero)
                AudioManager.shared.playEvent("damage")
            case .shatter(let pos, let color):
                // Use entity's actual color for rock particles
                createExplosion(at: pos, color: color)
                // NO haptic - shatter events fire too frequently
                
            case .evolve:
                // Visual fanfare for evolution
                triggerHaptic(style: .heavy)
                // Maybe a screen flash or particle effect here?
                let flash = UIView(frame: view.bounds)
                flash.backgroundColor = .white
                flash.alpha = 0.5
                view.addSubview(flash)
                UIView.animate(withDuration: 0.5) {
                    flash.alpha = 0.0
                } completion: { _ in
                    flash.removeFromSuperview()
                }
            }
        }
        world.events.removeAll(keepingCapacity: true)
        
        // Update Particles (CPU)
        renderer.particleSystem?.update(dt: clampedDT)
        
        // Trail now handled in Renderer.update
        
        // Update Coordinator State
        if world.player.abilityCooldown > 0 {
            let cooldown = world.player.abilityCooldown
            DispatchQueue.main.async {
                self.coordinator?.abilityCooldown = cooldown
            }
        } else if (coordinator.abilityCooldown) > 0 {
             DispatchQueue.main.async { self.coordinator?.abilityCooldown = 0 }
        }
        
        // Update Renderer
        let instances = world.getRenderInstances()
        let camera = world.player.pos
        
        // Sync to UI
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.coordinator?.score = Int(self.world.player.mass)
            self.coordinator?.health = self.world.player.health
            
            let tiers = ["Meteor", "Asteroid", "Planet", "Gas Giant", "Star", "Neutron Star", "Black Hole"]
            let tIndex = max(0, min(tiers.count-1, self.world.player.tier))
            self.coordinator?.tier = tiers[tIndex]
            
            if self.world.gameOver {
                self.coordinator?.gameState = .gameOver
            }
        }
        
        // Simple Zoom Logic (Scale based on player radius) -> 100 screen pts approx = player
        // zoom = 1.0 means 1 unit = 1 pixel (roughly, depending on projection)
        // Dynamic Zoom: As player grows, zoom out to show more world
        // Base Scale: 80.0 / (Radius + 40.0) -> Start ~ 1.33, End ~ 0.1
        let targetZoom = 100.0 / (world.player.radius + 60.0)
        let zoom: Float = max(0.15, min(2.0, targetZoom))
        
        renderer.update(instances: instances, camera: camera, zoom: zoom, time: world.time, flashIntensity: world.flashIntensity, playerVel: world.player.vel, playerPos: world.player.pos)
    }
    
    // MARK: - Restart
    @objc func restartGame() {
        // Recreate world
        world = World()
        setupCallbacks()
        
        // Reset timing
        lastFrameTime = CACurrentMediaTime()
        
        print("🔄 [STELLAR ASCENT] Game restarted")
    }
    
    // MARK: - Helpers
    func createExplosion(at pos: SIMD2<Float>, color: SIMD4<Float>) {
        // Use renderer's existing handleEvent
        renderer.handleEvent(type: "damage", pos: pos, color: color)
        AudioManager.shared.playEvent("damage")
    }
    
    func triggerHaptic(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        // Throttle to prevent rate-limit errors (iOS limit is 32Hz)
        let now = CACurrentMediaTime()
        guard now - lastHapticTime > 0.05 else { return } // Max 20Hz
        lastHapticTime = now
        
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
}

// SwiftUI Wrapper
struct GameView: UIViewControllerRepresentable {
    @ObservedObject var coordinator: GameCoordinator
    
    func makeUIViewController(context: Context) -> GameViewController {
        let vc = GameViewController()
        vc.coordinator = coordinator
        return vc
    }
    
    func updateUIViewController(_ uiViewController: GameViewController, context: Context) {
        // No-op
    }
}
