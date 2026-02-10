import SwiftUI

struct JoystickView: View {
    @Binding var inputVector: SIMD2<Float>
    
    @State private var dragOffset: CGSize = .zero
    
    let baseRadius: CGFloat = 60.0
    let knobRadius: CGFloat = 25.0
    
    var body: some View {
        ZStack {
            // Base
            Circle()
                .fill(Color.white.opacity(0.1))
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 2)
                )
                .frame(width: baseRadius * 2, height: baseRadius * 2)
            
            // Knob
            Circle()
                .fill(Color.white)
                .frame(width: knobRadius * 2, height: knobRadius * 2)
                .offset(dragOffset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            let vector = CGVector(dx: value.translation.width, dy: value.translation.height)
                            let distance = sqrt(vector.dx * vector.dx + vector.dy * vector.dy)
                            
                            var clampedOffset = value.translation
                            
                            if distance > baseRadius {
                                let angle = atan2(vector.dy, vector.dx)
                                clampedOffset = CGSize(
                                    width: cos(angle) * baseRadius,
                                    height: sin(angle) * baseRadius
                                )
                            }
                            
                            dragOffset = clampedOffset
                            
                            // Normalize output (-1 to 1)
                            // Note: Y is flipped in Screen Coords (Down is +), but usually Up is + in Game Engines.
                            // We will invert Y here to match standard "Up is Positive" logic if needed,
                            // or keep as is and flip in physics.
                            // Let's output Standard Screen Coords (Right +, Down +) and generic Input.
                            // NOTE: User Spec says "dy inverted for screen coords" -> Up is Positive?
                            // Let's just output raw normalized and let logic handle it.
                            // actually, spec says "dy inverted for screen coords"
                            
                            let x = Float(clampedOffset.width / baseRadius)
                            let y = Float(clampedOffset.height / baseRadius)
                            
                            // Input Vector: Y Up is Negative in Screen, Positive in World?
                            // Convention: Metal/World usually Y Up. Screen Y Down.
                            // If I push UP (Negative Y Screen), I want +Y World.
                            // So Input = (x, -y)
                            inputVector = SIMD2<Float>(x, -y)
                        }
                        .onEnded { _ in
                            dragOffset = .zero
                            inputVector = .zero
                        }
                )
        }
    }
}
