import SwiftUI

struct ContentView: View {
    @StateObject private var coordinator = GameCoordinator()
    
    var body: some View {
        ZStack {
            if coordinator.gameState == .menu {
                StartScreenView(coordinator: coordinator)
            } else {
                // Game Layer
                GameView(coordinator: coordinator)
                    .edgesIgnoringSafeArea(.all)
                
                // HUD Layer (Only visible when playing or paused)
                if coordinator.gameState == .playing || coordinator.gameState == .paused || coordinator.gameState == .levelingUp {
                    hudLayer
                }
                
                // Overlays
                if coordinator.gameState == .levelingUp && coordinator.showEvolutionSelection {
                    EvolutionSelectionView(options: coordinator.currentUpgradeOptions) { upgrade in
                        coordinator.onUpgradeSelect?(upgrade)
                        withAnimation {
                            coordinator.showEvolutionSelection = false
                            coordinator.gameState = .playing
                        }
                    }
                }
                
                // Pause Overlay
                if coordinator.gameState == .paused {
                    pauseOverlay
                }
                
                // Game Over Overlay
                if coordinator.gameState == .gameOver {
                    gameOverOverlay
                }
            }
        }
        .statusBar(hidden: true)
    }
    
    var hudLayer: some View {
        VStack {
            HStack {
                VStack(alignment: .leading) {
                    Text(coordinator.tier.uppercased())
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.accentColor)
                    Text("MASS: \(Int(coordinator.score))")
                        .font(.custom("Avenir Next", size: 24))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    EvolutionProgressBar(currentMass: Float(coordinator.score))
                        .frame(width: 180, height: 22)
                }
                .padding()
                
                Spacer()
                
                Button(action: {
                    withAnimation {
                        if coordinator.gameState == .playing {
                            coordinator.gameState = .paused
                        }
                    }
                }) {
                    Image(systemName: "pause.circle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.white)
                }
                .padding()
            }
            Spacer()
            
            // Controls Layer
            HStack(alignment: .bottom) {
                JoystickView(inputVector: $coordinator.inputVector)
                    .padding(50)
                Spacer()
                
                if coordinator.selectedPath == .warPlanet {
                    Button(action: { coordinator.onAbilityPress?() }) {
                        AbilityButtonView(color: .red, icon: "flame.fill", cooldown: coordinator.abilityCooldown, maxCooldown: coordinator.maxAbilityCooldown)
                    }
                    .padding(50)
                    .disabled(coordinator.abilityCooldown > 0)
                }
                
                if coordinator.selectedPath == .cradleOfLife {
                    Button(action: { coordinator.onAbilityPress?() }) {
                        AbilityButtonView(color: .green, icon: "tornado", cooldown: coordinator.abilityCooldown, maxCooldown: coordinator.maxAbilityCooldown)
                    }
                    .padding(50)
                    .disabled(coordinator.abilityCooldown > 0)
                }
                
                if coordinator.selectedPath == .frozenFortress {
                    Button(action: { coordinator.onAbilityPress?() }) {
                        AbilityButtonView(color: .cyan, icon: "snowflake", cooldown: coordinator.abilityCooldown, maxCooldown: coordinator.maxAbilityCooldown)
                    }
                    .padding(50)
                    .disabled(coordinator.abilityCooldown > 0)
                }
            }
        }
    }
    
    var pauseOverlay: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .background(.ultraThinMaterial)
            
            VStack(spacing: 30) {
                Text("PAUSED")
                    .font(.custom("AvenirNext-Heavy", size: 48))
                    .foregroundColor(.white)
                    .padding(.bottom, 20)
                
                Button(action: {
                    withAnimation {
                        coordinator.gameState = .playing
                    }
                }) {
                    Text("RESUME")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(width: 200, height: 50)
                        .background(RoundedRectangle(cornerRadius: 25).fill(Color.blue))
                }
                
                Button(action: {
                    restartGame()
                }) {
                    Text("RESTART")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(width: 200, height: 50)
                        .background(RoundedRectangle(cornerRadius: 25).fill(Color.orange))
                }
                
                Button(action: {
                    // Quit to Menu
                    coordinator.gameState = .menu
                    coordinator.onQuitGame?()
                }) {
                    Text("QUIT TO MENU")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(width: 200, height: 50)
                        .background(RoundedRectangle(cornerRadius: 25).fill(Color.red.opacity(0.8)))
                }
            }
        }
    }
    
    var gameOverOverlay: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Text("Game Over")
                    .font(.system(size: 56, weight: .bold))
                    .foregroundColor(.white)
                
                VStack(spacing: 10) {
                    Text("Final Mass")
                        .font(.system(size: 18))
                        .foregroundColor(.gray)
                    Text("\(coordinator.score)")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.white)
                }
                
                Button(action: {
                    restartGame()
                }) {
                    Text("Restart")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 50)
                        .padding(.vertical, 18)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.blue)
                                .shadow(color: .blue.opacity(0.5), radius: 10)
                        )
                }
                
                Button(action: {
                    coordinator.gameState = .menu
                    coordinator.onQuitGame?()
                }) {
                    Text("Menu")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.top, 10)
                }
            }
        }
    }
    
    func restartGame() {
        // Reset coordinator state
        coordinator.gameState = .playing
        coordinator.score = 5
        coordinator.health = 100
        coordinator.tier = "Meteor"
        coordinator.selectedPath = .none
                        coordinator.showEvolutionSelection = false
        coordinator.abilityCooldown = 0.0
        coordinator.maxAbilityCooldown = 5.0
        coordinator.currentUpgradeOptions = []
        
        // Trigger world reset via notification
        NotificationCenter.default.post(name: NSNotification.Name("RestartGame"), object: nil)
    }
}

struct AbilityButtonView: View {
    var color: Color
    var icon: String
    var cooldown: Float
    var maxCooldown: Float
    
    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.8))
                .frame(width: 80, height: 80)
                .shadow(color: color, radius: 10)
            
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(.white)
            
            if cooldown > 0 {
                Circle()
                    .trim(from: 0, to: CGFloat(cooldown / max(0.01, maxCooldown)))
                    .stroke(Color.black.opacity(0.5), lineWidth: 80)
                    .rotationEffect(.degrees(-90))
            }
        }
    }
}

struct EvolutionProgressBar: View {
    let currentMass: Float
    
    @State private var previousMass: Float = 0
    @State private var barScale: CGFloat = 1.0
    @State private var flashOpacity: Double = 0.0
    
    var stageInfo: (current: Progression.Stage, next: Progression.Stage?, progress: Float) {
        let current = Progression.getStage(mass: currentMass)
        let next = Progression.getNextStage(mass: currentMass)
        
        guard let nextStage = next else {
            let finalProgress = (currentMass - 50000.0) / (Progression.winMass - 50000.0)
            return (current, nil, min(1.0, max(0.0, finalProgress)))
        }
        
        let range = nextStage.threshold - current.threshold
        let completed = currentMass - current.threshold
        let percent = completed / max(1.0, range)
        
        return (current, nextStage, min(1.0, max(0.0, percent)))
    }
    
    var body: some View {
        let info = stageInfo
        
        VStack(alignment: .leading, spacing: 3) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.black.opacity(0.5))
                        .overlay(
                            Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                    
                    HStack(spacing: 0) {
                        Spacer()
                        Rectangle().fill(Color.white.opacity(0.1)).frame(width: 1, height: 4)
                        Spacer()
                        Rectangle().fill(Color.white.opacity(0.1)).frame(width: 1, height: 4)
                        Spacer()
                        Rectangle().fill(Color.white.opacity(0.1)).frame(width: 1, height: 4)
                        Spacer()
                    }
                    
                    Capsule()
                        .fill(LinearGradient(
                            gradient: Gradient(colors: getColors(for: info.current.name)),
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .frame(width: geo.size.width * CGFloat(info.progress))
                        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: info.progress)
                    
                    Capsule()
                        .fill(Color.white)
                        .frame(width: geo.size.width * CGFloat(info.progress))
                        .opacity(flashOpacity)
                        .blur(radius: 2)
                    
                    if info.progress > 0 {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 4, height: 4)
                            .offset(x: geo.size.width * CGFloat(info.progress) - 2)
                            .shadow(color: .white, radius: 2)
                            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: info.progress)
                    }
                }
            }
            .frame(height: 10)
            .scaleEffect(barScale)
            
            HStack {
                Text(info.current.name)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.8))
                    .shadow(color: .black, radius: 1)
                Spacer()
                if let next = info.next {
                    Text("Next: \(next.name)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(getNextColor(for: next.name))
                        .shadow(color: .black, radius: 1)
                } else {
                    Text("CRITICAL MASS")
                        .font(.system(size: 10, weight: .black))
                        .foregroundColor(.red)
                }
            }
        }
        .onChange(of: currentMass) { newMass in
            let diff = newMass - previousMass
            if diff > 1.0 {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                    barScale = 1.15
                    flashOpacity = 0.6
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation {
                        barScale = 1.0
                        flashOpacity = 0.0
                    }
                }
            }
            previousMass = newMass
        }
        .onAppear {
            previousMass = currentMass
        }
    }
    
    func getColors(for name: String) -> [Color] {
        if name.contains("Star") { return [.orange, .red] }
        if name.contains("Neutron") { return [.cyan, .white] }
        if name.contains("Black") { return [.purple, .black] }
        if name.contains("Gas") { return [.orange, .yellow] }
        if name.contains("Rocky") { return [.brown, .orange] }
        if name.contains("Dwarf Planet") { return [.blue, .cyan] }
        return [.blue, .purple]
    }
    
    func getNextColor(for name: String) -> Color {
        if name.contains("Star") { return .yellow }
        if name.contains("Black") { return .purple }
        return .white.opacity(0.5)
    }
}
