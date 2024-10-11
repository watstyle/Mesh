import SwiftUI
import CoreMotion

struct MeshGradientView: View {
    struct IdentifiableInt: Identifiable {
        let id = UUID()
        let value: Int
    }
    @State private var centerPoint: SIMD2<Float> = SIMD2(0.5, 0.5)
    @GestureState private var dragOffset: CGSize = .zero
    @State private var lastDragPosition: CGSize = .zero
    @State private var isEditing: Bool = false
    @State private var selectedPointIndex: IdentifiableInt? = nil
    @State private var colors: [Color] = [
        .black, .black, .black,
        .mint, .red, .purple,
        .orange, .yellow, .green
    ]
// test comment
    var body: some View {
        let width = UIScreen.main.bounds.width
        let height = UIScreen.main.bounds.height

        ZStack {
            // Background mesh gradient
            MeshGradient(width: 3, height: 3, points: getMeshPoints(), colors: colors)
//                .frame(width: .infinity, height: .infinity)
                .gesture(dragGesture(width: width, height: height))
                .onTapGesture(count: 2) {
                    if !isEditing {
                        // When toggling on, use elastic animation
                        withAnimation(.interpolatingSpring(stiffness: 100, damping: 8)) {
                            isEditing.toggle()
                        }
                    } else {
                        // When toggling off, use a simple fade-out animation
                        withAnimation(.easeOut(duration: 0.25)) {
                            isEditing.toggle()
                        }
                    }
                }

            // Editing overlay with clusters
            ForEach(colors.indices, id: \.self) { index in
                let point = getPoint(for: index, width: width, height: height)
                let offsetPoint = getOffsetPoint(for: index, originalPoint: point, width: width, height: height)

                ClusterView(color: colors[index])
                    .position(offsetPoint)
                    .scaleEffect(isEditing ? 1.0 : 0.3) // Scale up when editing is active
                    .opacity(isEditing ? 1.0 : 0.0) // Increase opacity when editing is active
                    .animation(isEditing
                        ? .interpolatingSpring(stiffness: 110, damping: 8).delay(0.05 * Double(index))
                        : .easeInOut(duration: 0.25),
                        value: isEditing
                    )
                    .onTapGesture {
                        selectedPointIndex = IdentifiableInt(value: index)
                    }
                    .popover(item: $selectedPointIndex) { selectedIndex in
                        ColorPicker("Select Color", selection: $colors[selectedIndex.value])
                            .labelsHidden()
                            .padding()
                            .background(Color.white)
                            .cornerRadius(10)
                            .shadow(radius: 5)
                    }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity) // Ensure full screen usage
        .ignoresSafeArea()
    }

    // Example placeholder functions
    private func getMeshPoints() -> [SIMD2<Float>] {
        return [
            SIMD2(0, 0),
            SIMD2(0.5, 0),
            SIMD2(1, 0),
            SIMD2(0, 0.5),
            centerPoint,
            SIMD2(1, 0.5),
            SIMD2(0, 1),
            SIMD2(0.5, 1),
            SIMD2(1, 1)
        ]
    }
    
    private func getPoint(for index: Int, width: CGFloat, height: CGFloat) -> CGPoint {
        let meshPoints = getMeshPoints()
        let simdPoint = meshPoints[index]
        return CGPoint(x: CGFloat(simdPoint.x) * width, y: CGFloat(simdPoint.y) * height)
    }
    
    private func getOffsetPoint(for index: Int, originalPoint: CGPoint, width: CGFloat, height: CGFloat) -> CGPoint {
        var offsetPoint = originalPoint
        switch index {
        case 0:
            offsetPoint.x = max(48, originalPoint.x)
            offsetPoint.y = max(120, originalPoint.y)
        case 1:
            offsetPoint.y = max(120, originalPoint.y)
        case 2:
            offsetPoint.x = min(width - 48, originalPoint.x)
            offsetPoint.y = max(120, originalPoint.y)
        case 3:
            offsetPoint.x = max(48, originalPoint.x)
        case 4:
            offsetPoint.x = max(24, originalPoint.x)
        case 5:
            offsetPoint.x = min(width - 48, originalPoint.x)
        case 6:
            offsetPoint.x = max(48, originalPoint.x)
            offsetPoint.y = min(height - 120, originalPoint.y)
        case 7:
            offsetPoint.x = max(48, originalPoint.x)
            offsetPoint.y = min(height - 120, originalPoint.y)
        case 8:
            offsetPoint.x = min(width - 48, originalPoint.x)
            offsetPoint.y = min(height - 120, originalPoint.y)
        default:
            return offsetPoint
        }
        return offsetPoint
    }
    
    // Cluster view that combines disk and orb
    struct ClusterView: View {
        var color: Color

        var body: some View {
            ZStack {
                RoundedRectangle(cornerRadius: 100)
                    .fill(Color.white.opacity(0.5)) // Use a translucent white color
                    .frame(width: 50, height: 50)
                    .background(BlurView(style: .systemThinMaterial)) // Custom BlurView for more control
                    .clipShape(RoundedRectangle(cornerRadius: 100))
                    .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 3)

                // Orb on top
                Circle()
                    .fill(color)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Circle()
                           .stroke(
                               RadialGradient(
                                   gradient: Gradient(colors: [Color.white.opacity(0.25), Color.clear]),
                                   center: .top,
                                   startRadius: 8,
                                   endRadius: 24
                               ),
                               lineWidth: 8
                           )
                           .clipShape(Circle())
                    )
                    .shadow(color: Color.black.opacity(0.25), radius: 2, x: 0, y: 1) // Drop shadow for elevation
            }
        }
    }
    
    struct BlurView: UIViewRepresentable {
        var style: UIBlurEffect.Style

        func makeUIView(context: Context) -> UIVisualEffectView {
            let view = UIVisualEffectView(effect: UIBlurEffect(style: style))
            return view
        }

        func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
            uiView.effect = UIBlurEffect(style: style)
        }
    }
    
    private func dragGesture(width: CGFloat, height: CGFloat) -> some Gesture {
        DragGesture()
            .updating($dragOffset) { value, state, _ in
                state = value.translation
            }
            .onChanged { value in
                let deltaX = Float(value.translation.width - lastDragPosition.width) / Float(width)
                let deltaY = Float(value.translation.height - lastDragPosition.height) / Float(height)
                
                centerPoint.x = min(max(centerPoint.x + deltaX, 0.2), 0.8)
                centerPoint.y = min(max(centerPoint.y + deltaY, 0.2), 0.8)
                
                lastDragPosition = value.translation
            }
            .onEnded { _ in
                lastDragPosition = .zero
            }
    }
}

struct ContentView: View {
    var body: some View {
        MeshGradientView()
    }
}

#Preview {
    ContentView()
}

