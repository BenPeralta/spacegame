import SwiftUI

struct EvolutionSelectionView: View {
    let options: [Upgrade]
    let onSelect: (Upgrade) -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.85).edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 30) {
                Text("COSMIC EVOLUTION")
                    .font(.custom("AvenirNext-Heavy", size: 32))
                    .foregroundColor(.white)
                    .shadow(color: .purple, radius: 20)
                
                HStack(spacing: 20) {
                    ForEach(0..<options.count, id: \.self) { i in
                        UpgradeCard(upgrade: options[i]) {
                            onSelect(options[i])
                        }
                    }
                }
            }
        }
    }
}

struct UpgradeCard: View {
    let upgrade: Upgrade
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Circle()
                    .fill(upgrade.color.opacity(0.2))
                    .frame(width: 70, height: 70)
                    .overlay(
                        Image(systemName: upgrade.icon)
                            .font(.system(size: 35))
                            .foregroundColor(upgrade.color)
                    )
                    .shadow(color: upgrade.color, radius: isHovered ? 20 : 5)
                
                Text(upgrade.name)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .frame(height: 40)
                
                Text(upgrade.description)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .frame(height: 50)
                
                Text(rarityString(upgrade.rarity))
                    .font(.caption2)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(upgrade.color.opacity(0.2))
                    .cornerRadius(8)
                    .foregroundColor(upgrade.color)
            }
            .padding()
            .frame(width: 160, height: 260)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(white: 0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(upgrade.color.opacity(isHovered ? 1.0 : 0.3), lineWidth: 2)
                    )
            )
            .scaleEffect(isHovered ? 1.05 : 1.0)
            .animation(.spring(), value: isHovered)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    func rarityString(_ r: Upgrade.Rarity) -> String {
        switch r {
        case .common: return "COMMON"
        case .rare: return "RARE"
        case .epic: return "EPIC"
        case .legendary: return "LEGENDARY"
        }
    }
}
