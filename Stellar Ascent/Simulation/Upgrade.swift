import SwiftUI

enum UpgradeType: String, CaseIterable {
    // EARLY (Physical)
    case relativisticJet = "Relativistic Jet"
    case magnetosphere = "Magnetosphere"
    case escapeVelocity = "Escape Velocity"
    
    // MID (Gravity/Structure)
    case neutroniumHull = "Neutronium Hull"
    case orbitalResonance = "Orbital Resonance"
    case rocheLimit = "Roche Limit Breaker"
    case darkMatterHalo = "Dark Matter Halo"
    
    // LATE (Stellar/Quantum)
    case nucleosynthesis = "Nucleosynthesis"
    case hawkingRadiation = "Hawking Radiation"
    case gammaRayBurst = "Gamma Ray Burst"
    case gravitationalLensing = "Gravitational Lensing"
    case eventHorizon = "Event Horizon"
}

struct Upgrade {
    let type: UpgradeType
    let name: String
    let description: String
    let icon: String
    let color: Color
    let rarity: Rarity
    let minStage: Int
    
    enum Rarity { case common, rare, epic, legendary }
}

class UpgradePool {
    static let shared = UpgradePool()
    
    let allUpgrades: [Upgrade] = [
        Upgrade(type: .relativisticJet, name: "Relativistic Jet", description: "Eject mass to boost speed.\nSpeed +20%, Ram Dmg +30%", icon: "wind", color: .orange, rarity: .common, minStage: 0),
        Upgrade(type: .magnetosphere, name: "Magnetosphere", description: "Magnetic field deflects debris.\nDefense +25%", icon: "shield.fill", color: .blue, rarity: .common, minStage: 1),
        Upgrade(type: .escapeVelocity, name: "Escape Velocity", description: "Lighter movement mechanics.\nAccel +40%", icon: "arrow.right.circle.fill", color: .mint, rarity: .common, minStage: 0),
        
        Upgrade(type: .neutroniumHull, name: "Neutronium Hull", description: "Become incredibly dense.\nMass +15%, Knockback Resist +50%", icon: "circle.grid.hex.fill", color: .gray, rarity: .rare, minStage: 3),
        Upgrade(type: .orbitalResonance, name: "Orbital Resonance", description: "Captured moons spin 2x faster and deal contact damage.", icon: "circle.dashed", color: .cyan, rarity: .rare, minStage: 3),
        Upgrade(type: .rocheLimit, name: "Roche Limit Breaker", description: "Tidal forces shatter enemies from 50% further away.", icon: "arrow.up.left.and.arrow.down.right", color: .red, rarity: .rare, minStage: 4),
        Upgrade(type: .darkMatterHalo, name: "Dark Matter Halo", description: "Invisible mass increases gravity range by 50%.", icon: "tornado", color: .indigo, rarity: .epic, minStage: 4),
        
        Upgrade(type: .nucleosynthesis, name: "Nucleosynthesis", description: "Fuse matter into energy.\nHeal 5% HP on absorb.", icon: "leaf.fill", color: .green, rarity: .epic, minStage: 6),
        Upgrade(type: .hawkingRadiation, name: "Hawking Radiation", description: "Emit thermal radiation, burning nearby enemies.", icon: "sun.max.fill", color: .yellow, rarity: .legendary, minStage: 6),
        Upgrade(type: .gammaRayBurst, name: "Gamma Ray Burst", description: "15% Chance to trigger massive explosion on impact.", icon: "burst.fill", color: .red, rarity: .legendary, minStage: 7),
        Upgrade(type: .gravitationalLensing, name: "Gravitational Lensing", description: "Bend light to see further.\nZoom +30%, Rare Spawns +20%", icon: "eye.fill", color: .pink, rarity: .rare, minStage: 8),
        Upgrade(type: .eventHorizon, name: "Event Horizon", description: "Contact instantly absorbs smaller enemies without shattering.", icon: "circle.dashed.inset.filled", color: .purple, rarity: .legendary, minStage: 9)
    ]
    
    func getOptions(for stageIndex: Int) -> [Upgrade] {
        let available = allUpgrades.filter { $0.minStage <= stageIndex }
        return Array(available.shuffled().prefix(3))
    }
}
