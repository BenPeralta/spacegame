import SwiftUI

struct StartScreenView: View {
    @ObservedObject var coordinator: GameCoordinator
    
    var body: some View {
        ZStack {
            // Background (Deep Space)
            LinearGradient(gradient: Gradient(colors: [Color.black, Color(red: 0.05, green: 0.05, blue: 0.15)]), startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            
            // Stars / Particles (Simple visual for now)
            GeometryReader { geometry in
                ForEach(0..<20) { _ in
                    Circle()
                        .fill(Color.white.opacity(Double.random(in: 0.2...0.8)))
                        .frame(width: CGFloat.random(in: 1...3), height: CGFloat.random(in: 1...3))
                        .position(x: CGFloat.random(in: 0...geometry.size.width), y: CGFloat.random(in: 0...geometry.size.height))
                }
            }
            
            VStack(spacing: 40) {
                // Title
                VStack(spacing: 5) {
                    Text("STELLAR")
                        .font(.custom("AvenirNext-Heavy", size: 60))
                        .foregroundColor(.white)
                        .shadow(color: .blue.opacity(0.8), radius: 20, x: 0, y: 0)
                    
                    Text("ASCENT")
                        .font(.custom("AvenirNext-Heavy", size: 60))
                        .foregroundColor(.white)
                        .shadow(color: .purple.opacity(0.8), radius: 20, x: 0, y: 0)
                }
                .padding(.top, 100)
                
                Spacer()
                
                // Menu Buttons
                VStack(spacing: 20) {
                    Button(action: {
                        withAnimation {
                            coordinator.gameState = .playing
                            coordinator.onStartGame?()
                        }
                    }) {
                        Text("PLAY")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(width: 200, height: 60)
                            .background(
                                RoundedRectangle(cornerRadius: 30)
                                    .fill(LinearGradient(gradient: Gradient(colors: [Color.blue, Color.purple]), startPoint: .leading, endPoint: .trailing))
                                    .shadow(color: .blue.opacity(0.5), radius: 10, x: 0, y: 5)
                            )
                    }
                    
                    Button(action: {
                        // TODO: Settings
                    }) {
                        Text("SETTINGS")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white.opacity(0.8))
                            .frame(width: 200, height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 25)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 2)
                            )
                    }
                }
                .padding(.bottom, 100)
            }
        }
    }
}
