# Stellar Ascent - Visual Design System

**Version**: 3.0  
**Last Updated**: 2026-02-10

---

## Progression Flow

### Mass 5-25: Meteor (Tier 0)
**Appearance**: Lumpy with visible attachments  
**Color**: `(0.55, 0.5, 0.45)` - Rocky gray/brown  
**Purpose**: Learning phase - frequent chip damage teaches mechanics

### Mass 25-60: Asteroid (Tier 1)
**Appearance**: **Clean solid sphere** (attachments compacted)  
**Color**: Path-dependent (green/blue/red based on first power-up choice)  
**Purpose**: First power-up - color choice defines your journey  
**Key Change (v3.0)**: Clean merge now triggers at tier 1 (mass ≥25) instead of tier 2

### Mass 60-1000: Planet (Tier 2-3)
**Appearance**: Realistic planet textures based on path  
**Color**: Hybrid blend if second choice made (50/50 mix)  
**Purpose**: Second power-up - hybrid evolution

### Mass 600+: Gas Giant+ (Tier 4+)
**Appearance**: Advanced patterns, glowing  
**Color**: Persistent from previous choices  
**Purpose**: Cosmic horror - one mistake = death

---

## Color Persistence System (v3.0)

### The Problem (FIXED)
- `updatePlayerVisualsForTier` was overriding chosen colors on every tier change
- Hybrid blend logic was executing AFTER switch statement color assignments
- Result: Green choice → reverts to gray/blue on tier change

### The Solution
**Color set ONLY in `selectPath()`** (WorldEvolution.swift:L99-109):
```swift
// Set color based on path (with hybrid blending if multiple choices)
let newColor = pathColor(for: path)
if player.evoHistory.count > 1, let lastPath = player.evoHistory.dropLast().last {
    let lastColor = pathColor(for: lastPath)
    player.color = mix(lastColor, newColor, t: 0.5)  // 50/50 hybrid
} else {
    player.color = newColor  // First choice - pure color
}
```

**Result**:
- First power-up: Pure green (or chosen color)
- Second power-up: 50/50 hybrid (e.g., green + blue = teal)
- Color persists forever - no overrides

---

## Path-Specific Colors

### Evolution Paths
| Path | Base Color | Crack Color | Description |
|------|------------|-------------|-------------|
| **Cradle of Life** | `(0.3, 0.8, 0.4)` Green | `(0.2, 1.0, 0.4)` Bright green | Lush habitable world |
| **Frozen Fortress** | `(0.6, 0.8, 1.0)` Ice blue | `(0.4, 0.9, 1.0)` Bright blue | Icy fortress |
| **War Planet** | `(0.9, 0.3, 0.2)` Red | `(1.0, 0.4, 0.2)` Bright red | Scarred hellworld |
| **Lava** | `(0.9, 0.5, 0.2)` Orange | `(1.0, 0.6, 0.1)` Bright orange | Molten surface |
| **Rings** | `(0.7, 0.7, 0.9)` Purple | `(0.8, 0.8, 1.0)` Bright purple | Ringed gas giant |
| **Red Dwarf** | `(0.9, 0.3, 0.2)` Red | `(1.0, 0.4, 0.2)` Bright red | Small star |
| **Yellow Star** | `(1.0, 0.9, 0.6)` Yellow | `(1.0, 1.0, 0.7)` Bright yellow | Sun-like star |
| **Blue Giant** | `(0.6, 0.8, 1.0)` Blue | `(0.7, 0.9, 1.0)` Bright blue | Massive hot star |

---

## Realistic Planet Shaders (v3.0)

### Player vs Hazards
- **Player**: Path-unique appearance (life/ice/war patterns)
- **Hazards**: Real solar system variety (Earth, Jupiter, Mars, etc.)

### Planet Patterns (Shaders.metal:L154-178)

**Gas Giants** (radius >100):
```metal
// Jupiter-like bands + Great Red Spot
float bands = sin(localCoord.y * 15.0 + fbm(localCoord * 2.0) * 3.0);
baseCol = mix(jupiterOrange, saturnPale, bands);
if (storm) baseCol = redSpot;  // Great Red Spot
```

**Ice Giants** (radius 60-100):
```metal
// Uranus/Neptune pale blue with misty haze
baseCol = float3(0.6, 0.8, 0.9);
baseCol = mix(baseCol, float3(0.8, 0.9, 1.0), haze * 0.4);
```

**Terrestrial** (radius <60):
```metal
// Earth: blue oceans + green continents + white clouds
float land = smoothstep(0.4, 0.6, noise);
baseCol = mix(oceanBlue, landGreen, land);
baseCol = mix(baseCol, white, clouds * 0.3);

// Mars/Mercury: red/gray craters
// Venus: yellow swirling clouds
```

---

## Visual Transitions (v3.0)

### Clean Merge at Power-Up
**Trigger**: Mass ≥25 (Tier 1, Asteroid)  
**Effect** (WorldEvolution.swift:L204-215):
```swift
// Blend attachment colors into player base color
if !player.attachments.isEmpty {
    var totalR, totalG, totalB: Float = 0
    for att in player.attachments {
        totalR += att.color.x * att.color.w
        totalG += att.color.y * att.color.w
        totalB += att.color.z * att.color.w
    }
    let blend = SIMD4<Float>(totalR/count, totalG/count, totalB/count, 1.0)
    player.color = mix(player.color, blend, t: 0.4)  // 40% blend
}
player.attachments.removeAll()
```

**Visual**: Attachments "melt" inward → clean solid sphere

---

## Implementation Status

### ✅ Completed (v3.0)
1. **Color persistence**: Removed all overrides, colors stick forever
2. **Hybrid blending**: 50/50 mix for multi-path evolution
3. **Clean merge at tier 1**: Solid sphere at mass ≥25
4. **Realistic planet shaders**: Earth, Jupiter, Saturn, ice giants, Mars, Venus
5. **Astrophysics mechanics**: Tidal disruption, rogue asteroids
6. **Power-up timing**: Milestone-based (fires exactly at 25, 60, 1000)

### 🔄 Future Enhancements
1. **Player-specific shader patterns**: Separate player appearance from hazards
2. **Path-unique planet textures**: Life/ice/war visual themes
3. **More astrophysics mechanics**: Supernovae, orbital instability, stellar engulfment
