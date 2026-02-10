import SwiftUI

enum UpgradeType: String, CaseIterable {
    // TIER 1-2 (Meteor/Asteroid)
    case relativisticJet = "Relativistic Jet"
    case magnetosphere = "Magnetosphere"
    case escapeVelocity = "Escape Velocity"
    
    // TIER 3 (Planet/Gas Giant)
    case rocheLimit = "Roche Limit Breaker"
    case orbitalResonance = "Orbital Resonance"
    case neutroniumHull = "Neutronium Hull"
    case nucleosynthesis = "Nucleosynthesis"
    
    // TIER 4-5 (Star/Black Hole)
    case hawkingRadiation = "Hawking Radiation"
    case eventHorizon = "Event Horizon"
    case gammaRayBurst = "Gamma Ray Burst"
    case darkMatterHalo = "Dark Matter Halo"
    case gravitationalLensing = "Gravitational Lensing"
}

struct Upgrade {
    let type: UpgradeType
    let name: String
    let description: String
    let icon: String
    let color: Color
    let rarity: Rarity
    let minTier: Int
    
    enum Rarity { case common, rare, epic, legendary }
}

class UpgradePool {
    static let shared = UpgradePool()
    
    let allUpgrades: [Upgrade] = [
        Upgrade(type: .relativisticJet, name: "Relativistic Jet", description: "Eject mass to boost speed.\nSpeed +20%, Ram Dmg +30%", icon: "wind", color: .orange, rarity: .common, minTier: 0),
        Upgrade(type: .magnetosphere, name: "Magnetosphere", description: "Magnetic field deflects debris.\nDefense +25%", icon: "shield.fill", color: .blue, rarity: .common, minTier: 1),
        Upgrade(type: .escapeVelocity, name: "Escape Velocity", description: "Lighter movement mechanics.\nAccel +40%", icon: "arrow.right.circle.fill", color: .mint, rarity: .common, minTier: 0),
        
        Upgrade(type: .rocheLimit, name: "Roche Limit Breaker", description: "Tidal forces shatter enemies from afar.\nShatter Range +50%", icon: "arrow.up.left.and.arrow.down.right", color: .red, rarity: .rare, minTier: 2),
        Upgrade(type: .neutroniumHull, name: "Neutronium Hull", description: "Become incredibly dense.\nMass +20%, Knockback Resist +50%", icon: "circle.grid.hex.fill", color: .gray, rarity: .rare, minTier: 2),
        Upgrade(type: .orbitalResonance, name: "Orbital Resonance", description: "Captured moons spin faster and deal damage.", icon: "orbit", color: .cyan, rarity: .rare, minTier: 2),
        Upgrade(type: .nucleosynthesis, name: "Nucleosynthesis", description: "Fuse matter into energy.\nHeal on absorb.", icon: "leaf.fill", color: .green, rarity: .epic, minTier: 2),
        
        Upgrade(type: .hawkingRadiation, name: "Hawking Radiation", description: "Emit thermal radiation, burning nearby enemies.", icon: "sun.max.fill", color: .yellow, rarity: .epic, minTier: 4),
        Upgrade(type: .eventHorizon, name: "Event Horizon", description: "Contact instantly absorbs smaller enemies.", icon: "circle.dashed.inset.filled", color: .purple, rarity: .legendary, minTier: 5),
        Upgrade(type: .gammaRayBurst, name: "Gamma Ray Burst", description: "15% chance to trigger explosion on impact.", icon: "burst.fill", color: .red, rarity: .legendary, minTier: 4),
        Upgrade(type: .darkMatterHalo, name: "Dark Matter Halo", description: "Invisible mass increases gravity range by 50%.", icon: "tornado", color: .indigo, rarity: .epic, minTier: 3),
        Upgrade(type: .gravitationalLensing, name: "Gravitational Lensing", description: "Zoom out +30%, rare spawn chance.", icon: "eye.fill", color: .pink, rarity: .rare, minTier: 3)
    ]
    
    func getOptions(for tier: Int) -> [Upgrade] {
        let available = allUpgrades.filter { $0.minTier <= tier }
        return Array(available.shuffled().prefix(3))
    }
}
