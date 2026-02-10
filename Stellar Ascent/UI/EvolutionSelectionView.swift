import SwiftUI

struct EvolutionSelectionView: View {
    let onSelect: (EvoPath) -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.85).edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 30) {
                Text("EVOLUTION REACHED")
                    .font(.custom("Avenir Next", size: 32))
                    .fontWeight(.heavy)
                    .foregroundColor(.white)
                    .shadow(color: .purple, radius: 10)
                
                Text("Choose your destiny")
                    .font(.headline)
                    .foregroundColor(.gray)
                
                HStack(spacing: 20) {
                    // Path 1: Frozen Fortress
                    ChoiceCard(
                        title: "Frozen Fortress",
                        desc: "High Health & Armor\nSlower Growth",
                        icon: "shield.fill",
                        color: .blue
                    ) {
                        onSelect(.frozenFortress)
                    }
                    
                    // Path 2: Cradle of Life
                    ChoiceCard(
                        title: "Cradle of Life",
                        desc: "Massive Gravity\nMagnetism++",
                        icon: "leaf.fill",
                        color: .green
                    ) {
                        onSelect(.cradleOfLife)
                    }
                    
                    // Path 3: War Planet
                    ChoiceCard(
                        title: "War Planet",
                        desc: "Shockwave Ability\nHigh Damage",
                        icon: "flame.fill",
                        color: .red
                    ) {
                        onSelect(.warPlanet)
                    }
                }
                .padding()
            }
        }
    }
}

struct ChoiceCard: View {
    let title: String
    let desc: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 15) {
                Image(systemName: icon)
                    .font(.system(size: 40))
                    .foregroundColor(color)
                
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(desc)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            .padding(25)
            .frame(width: 160, height: 220)
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 15)
                            .stroke(color, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isHovered ? 1.05 : 1.0)
        .animation(.spring(), value: isHovered)
    }
}
