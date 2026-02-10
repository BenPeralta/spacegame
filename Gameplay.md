# Stellar Ascent - Complete Gameplay Bible

**Version**: 3.0  
**Last Updated**: 2026-02-10  
**Purpose**: Technical specification for third-party developer audits

---

## Recent Updates (v3.0)

### Astrophysics Destruction Mechanics
- **Tidal Disruption (Spaghettification)**:
  - Pre-600: Stretch bounces (10 damage + knockback) on mid-sized hazards (massRatio 0.5-0.8, speed <300)
  - Post-600: Full shred (50% mass loss + debris scatter) on slow grazes of massive objects
- **Giant Impacts (Rogue Asteroids)**:
  - Pre-600: 5% spawn rogues (mass 15-30, red color) on collision courses
  - Post-600: 3% spawn massive rogues (mass 400-1500, bright red) = instant death threat

### Visual & Progression Fixes
- **Color Persistence**: Removed `updatePlayerVisualsForTier` color override - chosen path colors now stick
- **Hybrid Color Blending**: 50/50 blend between multiple path choices for unique evolution
- **Clean Merge at Tier 1**: Attachments compact at mass ≥25 (Asteroid) instead of tier 2
- **Realistic Planet Shaders**: Earth (oceans/continents), Jupiter (bands/Great Red Spot), ice giants, Mars/Venus
- **Power-Up Timing**: Milestone-based triggers (fires exactly at mass 25, 60, 1000 even if mass jumps)

### Late-Game Difficulty Scaling
- **Scaled Absorb Ratio**: 0.50 → 0.30 at high mass (harder to absorb late-game)
- **Velocity-Based Damage**: 2x damage at high difficulty
- **More Giants**: Increased spawn rate of large hazards at high difficulty

---

## Table of Contents
1. [Core Gameplay Loop](#core-gameplay-loop)
2. [Starting Conditions](#starting-conditions)
3. [Collision System](#collision-system)
4. [Fragment Mechanics](#fragment-mechanics)
5. [Progression & Tiers](#progression--tiers)
6. [Physics System](#physics--orbit-system)
7. [Visual Rendering](#visual-rendering)
8. [Entity Spawning](#entity-spawning)
9. [Performance Limits](#performance-limits)

---

## Core Gameplay Loop

**Objective**: Start as a tiny meteor (mass 5) and grow by absorbing smaller objects while avoiding larger ones.

**Win Condition**: Reach Black Hole tier (mass 5000+)  
**Lose Condition**: Collide with object ≥ 80% of your mass OR health reaches 0

---

## Starting Conditions

```swift
// Player initialization (World.swift:L29-33)
player.mass = 5.0
player.radius = SimParams.radiusForMass(5.0) // ≈ 14.5
player.color = SIMD4<Float>(0.55, 0.5, 0.45, 1.0) // Brown/gray meteor
player.health = 100.0
player.tier = 0 // Meteor
```

**Initial World**:
- 40 entities spawn at distance 500-3000 from origin
- Player starts at position (0, 0)

---

## Collision System

### Mass Ratio Formula
```swift
let massRatio = entity.mass / player.mass
let impactSpeed = length(player.vel - entity.vel)
```

### Collision Rules (Updated v2.0)

| Mass Ratio | Velocity | Behavior | Code Reference |
|------------|----------|----------|----------------|
| **< 0.50** | Any | **ABSORB** - Entity merges instantly | World.swift:L375-400 |
| **0.50 - 0.80** | < 180 | **BUMP** - Damage + bounce, no shatter | World.swift:L427-433 |
| **0.50 - 0.80** | ≥ 180 | **SHATTER** - Entity breaks into 2 fragments | World.swift:L435-490 |
| **≥ 0.80** | Any | **CRUSH** - Player dies (game over) | World.swift:L402-410 |

### Key Changes from v1.0

**OLD** (v1.0 - Broken):
- Absorb < 35% → fragments at 35-50% would re-shatter (chain bug)
- All 35-80% collisions shattered → dust spam
- Fragments 3-5 mass → some >35% player → infinite chains

**NEW** (v2.0 - Fixed):
- Absorb < 50% → fragments always <48% → instant absorb ✅
- Gentle bumps bounce → only fast impacts shatter
- Fixed 2 fragments → less entity spam

### Absorption Details

**When massRatio < 0.50**:
1. Entity mass added to player: `player.mass += entity.mass`
2. Player radius updated: `player.updateRadius()`
3. Health restored: `player.health += entity.mass * 0.12` (was 0.10)
4. Visual attachment created if entity is small enough

**Attachment System** (World.swift:L385-403):
- Small debris (mass < 15% of player) creates visual "clumps"
- Max 25 attachments (was 30)
- Positioned using golden angle spiral: `φ = 137.5°`
- Attachments removed at Tier 2+ (Hydrostatic Equilibrium)

### Shatter Details

**When 0.50 ≤ massRatio < 0.80 AND impactSpeed ≥ 180**:
1. Player takes damage: `damage = impactSpeed * massRatio * 0.22 * defenseMultiplier`
2. Player receives knockback: `knockback = 0.45 * 800.0 * massRatio`
3. Entity breaks into **exactly 2 fragments**
4. Fragments scatter with velocity 150-300 units/s (escape velocity)

---

## Fragment Mechanics

### Fragment Creation Formula (v2.0 - FIXED)

```swift
// World.swift:L435-465
let pieceCount = 2  // FIXED: Always 2 pieces
let safeMax = player.mass * 0.50 * 0.96  // Hard cap at 48% player mass

for i in 0..<1 {  // First piece
    let portion = Float.random(in: 0.30...0.50)  // 30-50% of parent
    let pieceMass = remainingMass * portion
    let maxPiece = min(pieceMass, min(remainingMass * 0.70, safeMax))
    let clampedMass = max(1.5, maxPiece)  // Min 1.5 for visibility
    debrisMasses.append(clampedMass)
    remainingMass -= clampedMass
}
debrisMasses.append(remainingMass)  // Second piece gets ALL remaining
```

**Key Properties**:
- **Piece count**: Always 2 (prevents spam)
- **Mass conservation**: Perfect (last piece = remaining)
- **Absorb guarantee**: All fragments < 48% player mass
- **Color**: Exact parent color (no variation)
- **Seed**: 0.123 (same as all meteors)

### Fragment Collectibility

**Example** (Player mass 20, Asteroid mass 15):
- massRatio = 15/20 = 0.75 → **SHATTER** (if fast impact)
- Fragments: 2 pieces of mass ~4.5 and ~10.5
- But 10.5/20 = 0.525 > 0.50? **NO** - safeMax caps at 9.6 ✅
- Fragment/Player ratio: 9.6/20 = 0.48 → **Instantly absorbable** ✅

**No more chain shatters!**

---

## Astrophysics Destruction Mechanics (v3.0)

### Tidal Disruption (Spaghettification)

**Pre-600 Mass** (WorldPhysics.swift:L142-157):
```swift
if massRatio >= 0.5 && massRatio <= 0.8 && impactSpeed < 300 && player.mass < 600 {
    // Stretch bounce (chip damage + knockback)
    let dir = normalize(player.pos - e.pos)
    player.vel += dir * -300.0  // Strong bounce
    player.health -= 10.0
}
```
- **Purpose**: Teaches speed requirement for absorption
- **Frequency**: Common on mid-sized hazards
- **Effect**: 10 damage + strong knockback

**Post-600 Mass** (WorldPhysics.swift:L158-173):
```swift
if massRatio > 0.6 && impactSpeed < 300 && player.mass >= 600 {
    // Full shred (50% mass loss + debris)
    player.mass *= 0.5
    player.health -= 50.0
    createPlayerDebris() // 2x debris scatter
}
```
- **Purpose**: Punishes slow approaches to massive objects
- **Frequency**: Rare but devastating
- **Effect**: 50% mass loss, 50 damage, possible death

### Giant Impacts (Rogue Asteroids)

**Pre-600 Mass** (WorldSpawning.swift:L44-56):
```swift
let rogueChance: Float = player.mass < 600 ? 0.05 : 0.03
if isRogue && player.mass < 600 {
    mass = Float.random(in: 15...30)
    baseColor = SIMD4<Float>(0.9, 0.3, 0.2, 1.0)  // Red warning
    driftVel = toPlayer * Float.random(in: 80...150)  // Collision course
}
```
- **Purpose**: Dodging practice
- **Spawn Rate**: 5%
- **Visual**: Red color for warning
- **Behavior**: Aims toward player at moderate speed

**Post-600 Mass** (WorldSpawning.swift:L57-62):
```swift
if isRogue && player.mass >= 600 {
    mass = Float.random(in: 400...1500)
    baseColor = SIMD4<Float>(1.0, 0.2, 0.1, 1.0)  // Bright red danger
    driftVel = toPlayer * Float.random(in: 200...400)  // Fast collision course
}
```
- **Purpose**: Instant death threat
- **Spawn Rate**: 3%
- **Visual**: Bright red for extreme danger
- **Behavior**: Fast collision course, massRatio >0.7 = instant death

---

## Progression & Tiers

### Tier Thresholds

```swift
// World.swift:L565-569
if mass < 20: tier = 0      // Meteor
else if mass < 40: tier = 1  // Asteroid
else if mass < 300: tier = 2 // Planet
else if mass < 1000: tier = 3 // Gas Giant
else if mass < 2500: tier = 4 // Star
else if mass < 5000: tier = 5 // Neutron Star
else: tier = 6               // Black Hole
```

### Tier Properties

| Tier | Name | Mass Range | Radius Range | Base Color | Glow |
|------|------|------------|--------------|------------|------|
| 0 | Meteor | 1-20 | 9-25 | `(0.55, 0.5, 0.45)` | 0.0 |
| 1 | Asteroid | 20-40 | 25-38 | `(0.6, 0.6, 0.65)` | 0.0 |
| 2 | Planet | 40-300 | 38-75 | `(0.3, 0.6, 0.8)` | 1.2 |
| 3 | Gas Giant | 300-1000 | 75-150 | `(0.9, 0.6, 0.3)` | 1.4 |
| 4 | Star | 1000-2500 | 150-250 | Evolution-dependent | 1.6 |
| 5 | Neutron Star | 2500-5000 | 250-350 | Evolution-dependent | 1.8 |
| 6 | Black Hole | 5000+ | 350+ | Evolution-dependent | 2.0 |

---

## Physics & Orbit System

### Gravity Constants (v2.0 - Tuned for Stable Orbits)

```swift
// SimParams.swift:L5-12
static let G: Float = 80000.0       // Lower: Prevents death spirals (was 500k)
static let softening: Float = 120.0  // Softer close-in (was 60)
static let influenceRadius: Float = 1200.0  // Wider pull (was 800)

// Orbit System
static let captureRange: Float = 3.5     // Distance multiplier for manual capture
static let minOrbitRadius: Float = 1.8   // Prevent overlap
static let orbitDecay: Float = 0.995     // Slight inspiral for accretion
```

### Stable Orbit Gravity Formula (v2.0)

```swift
// World.swift:L318-355
let r = player.pos - entity.pos  // Vector TO player
let dist = length(r)
let dir = r / dist  // Unit vector

// Pure 1/r² radial force (using r³ denominator with r vector)
let denom = pow(dist, 3.0) + pow(softening, 3.0)
var accelMag = G * player.mass / denom * dist  // = GM / r²

// Cradle of Life evolution boost
if player.evoPath == .cradleOfLife {
    accelMag *= 1.5
}

var accel = dir * accelMag

// ANTI-DECAY: Tangential velocity boost to counter Euler integration
let tangent = SIMD2<Float>(-dir.y, dir.x)  // CCW perpendicular
let velTan = dot(entity.vel, tangent)
let idealTan = sqrt(accelMag * dist) * 0.95  // ~orbital velocity
let tanBoost = max(0, idealTan - velTan) * 0.3  // Gentle nudge
accel += tangent * tanBoost
```

**Why This Works**:
- **1/r³ vector form** = exact 1/r² magnitude (stable circular orbits)
- **Tangential boost** counters Euler decay (prevents spiral-in)
- **No inertia factor** (removed `/sqrt(mass)` - all objects orbit)
- **Result**: Rocks orbit at ~1.5-3x player radius in stable circles ✅

### OLD Gravity (v1.0 - Death Spirals)

```swift
// BROKEN: Caused death spirals
accelMag = G * player.mass / (dist² + softening²)  // Too strong
accelMag /= sqrt(entity.mass)  // Heavy objects ignored
accel = dir * accelMag + tangent * accelMag * 1.2  // 120% swirl = spiral
```

### Movement

```swift
// SimParams.swift:L14-16
static let playerMaxSpeed: Float = 900.0
static let playerAccel: Float = 1400.0
static let drag: Float = 0.04  // Reduced from 0.08 for smoother orbit following
```

**Player Control** (World.swift:L158-176):
```swift
// Joystick input → acceleration
player.vel += inputDir * playerAccel * dt
// Apply drag
player.vel *= (1.0 - drag)
// Clamp speed
if length(player.vel) > playerMaxSpeed {
    player.vel = normalize(player.vel) * playerMaxSpeed
}
```

---

## Visual Rendering

### Color System

**Meteor Consistency** (World.swift:L112-123):
```swift
if mass <= 5.0 {
    colorVar = 1.0  // ZERO variation - all meteors identical
} else {
    colorVar = Float.random(in: 0.98...1.02)  // ±2% for other tiers
}
```

**Fragment Inheritance**:
- Fragments use **exact parent color** (no variation)
- Fragments use **seed 0.123** (same as meteors)

### Shader Rendering

**Texture Detail Levels** (Shaders.metal:L138-154):
```metal
if (radius < 5.0) {
    // Tiny particles: simple hash noise
    baseCol = mix(inputColor, lightColor, hash(...) * 0.3);
} else if (radius < 38.0) {
    // Meteors/Asteroids: rocky FBM texture
    float nRock = fbm(localCoord * 4.0);
    baseCol = mix(darkColor, inputColor, smoothstep(0.2, 0.8, nRock));
} else {
    // Planets: smooth patterns (banded/cratered/oceanic)
}
```

---

## Entity Spawning

### Distribution (World.swift:L88-109)

```swift
let roll = Float.random(in: 0...100)

if roll < 70:       // 70% - Meteors
    mass = Float.random(in: 1...5)
    color = (0.55, 0.5, 0.45)
else if roll < 90:  // 20% - Asteroids
    mass = Float.random(in: 12...35)
    color = (0.6, 0.6, 0.65)
else if roll < 98:  // 8% - Planets
    mass = Float.random(in: 40...120)
    color = (0.3, 0.6, 0.8)
else:               // 2% - Gas Giants
    mass = Float.random(in: 300...800)
    color = (0.9, 0.6, 0.3)
```

---

## Performance Limits

### Entity Caps (v2.0)

```swift
static let entityHardLimit = 180  // Hard cap (was 200)
```

### Debris Counts

| Event | Piece Count | Previous |
|-------|-------------|----------|
| Collision shatter | **2** | 2-3 |
| Roche limit | 2-3 | 3-5 |
| Player death | 3-5 | 5-10 |

### Optimization

- **Spatial grid**: 180-unit cells for collision detection
- **Gravity candidates**: Only entities within influence radius (1200)
- **Fixed fragment count**: 2 pieces (prevents exponential growth)
- **Higher scatter velocity**: Fragments escape quickly (less screen clutter)

---

## Constants Reference

### SimParams.swift (v2.0)

```swift
// Gravity (Stable Orbits)
G = 80000.0          // Was 500k
softening = 120.0    // Was 60
influenceRadius = 1200.0  // Was 800

// Movement
playerMaxSpeed = 900.0
playerAccel = 1400.0
drag = 0.04          // Was 0.08

// Collision (Fixed Chain Shatters)
absorbRatio = 0.50   // Was 0.35
shatterRatio = 0.75  // New
crushRatio = 0.80
damageScale = 0.22   // Was 0.30
knockbackScale = 0.45  // Was 0.40
minFragmentMass = 1.5
shatterImpactThreshold = 180.0  // New (velocity gate)
entityHardLimit = 180  // Was 200

// Limits
maxEntitySpeed = 1200.0
maxAccel = 4000.0
```

---

## File Reference

| System | File | Lines |
|--------|------|-------|
| Collision | World.swift | 364-490 |
| Fragments | World.swift | 435-490 |
| Gravity | World.swift | 318-355 |
| Progression | World.swift | 565-625 |
| Physics | World.swift | 158-330 |
| Spawning | World.swift | 48-127 |
| Rendering | Shaders.metal | 138-194 |
| Constants | SimParams.swift | 1-60 |
| Player | Player.swift | 1-48 |
| Entity | Entity.swift | 1-28 |

---

## Version History

**v2.0** (2026-02-09):
- Fixed chain shatter bug (fragments always <48% player)
- Velocity-gated shatters (gentle bumps bounce)
- Stable orbit gravity (tangential boost, no death spirals)
- Tuned constants (G=80k, influence=1200, drag=0.04)
- Added Orbiter struct for manual capture system (Phase 2)

**v1.0** (2026-02-09):
- Initial comprehensive documentation
- Fragment mass conservation fix
- Meteor visual consistency
