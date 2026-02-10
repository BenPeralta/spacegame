import SwiftUI

struct EvolutionSelectionView: View {
    let onSelect: (EvoPath) -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.90).edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 25) {
                Text("STELLAR EVOLUTION")
                    .font(.custom("AvenirNext-Heavy", size: 36))
                    .foregroundColor(.white)
                    .shadow(color: .blue, radius: 15)
                
                Text("Select your cosmic destiny")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                HStack(spacing: 15) {
                    ChoiceCard(
                        title: "Zero Kelvin Crust",
                        desc: "Develop an impenetrable ice shell.\nDefense +50%",
                        icon: "snowflake",
                        color: Color(red: 0.4, green: 0.8, blue: 1.0)
                    ) {
                        onSelect(.frozenFortress)
                    }
                    
                    ChoiceCard(
                        title: "Accretion Disk",
                        desc: "Generate intense gravity to pull matter.\nPull range +200%",
                        icon: "tornado",
                        color: Color(red: 0.2, green: 0.9, blue: 0.4)
                    ) {
                        onSelect(.cradleOfLife)
                    }
                    
                    ChoiceCard(
                        title: "Stellar Ignition",
                        desc: "Burn nearby enemies on contact.\nContact Damage +300%",
                        icon: "flame.fill",
                        color: Color(red: 1.0, green: 0.3, blue: 0.1)
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
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.2))
                        .frame(width: 60, height: 60)
                    Image(systemName: icon)
                        .font(.system(size: 30))
                        .foregroundColor(color)
                }
                
                Text(title)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text(desc)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 5)
            }
            .padding(20)
            .frame(width: 170, height: 260)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(white: 0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(color, lineWidth: isHovered ? 4 : 1)
                    )
                    .shadow(color: color.opacity(0.4), radius: isHovered ? 20 : 0)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isHovered ? 1.05 : 1.0)
        .animation(.spring(response: 0.3), value: isHovered)
    }
}
