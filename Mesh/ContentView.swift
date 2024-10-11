import SwiftUI
import CoreMotion

struct MeshGradientView: View {
    struct IdentifiableInt: Identifiable {
        let id = UUID()
        let value: Int
    }
    @State private var isEditingMode: Bool = false
    @State private var selectedPointIndex: IdentifiableInt? = nil
    @State private var colors: [Color] = [
        .black, .black, .black,
        .mint, .red, .purple,
        .orange, .yellow, .green
    ]
    @State private var meshPoints: [SIMD2<Float>] = [
        SIMD2(0, 0), SIMD2(0.5, 0), SIMD2(1, 0),
        SIMD2(0, 0.5), SIMD2(0.5, 0.5), SIMD2(1, 0.5),
        SIMD2(0, 1), SIMD2(0.5, 1), SIMD2(1, 1)
    ]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Off-black background with a slight navy tint when editing
                (isEditingMode ? Color(hex: "#0B0D0F") : Color.clear)
                    .ignoresSafeArea()
                
                // Background mesh gradient
                MeshGradient(width: 3, height: 3, points: adjustedMeshPoints(for: geometry), colors: colors)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                if !isEditingMode {
                                    // Update nearest mesh point when dragging in normal mode
                                    let location = SIMD2<Float>(
                                        Float(value.location.x / geometry.size.width),
                                        Float(value.location.y / geometry.size.height)
                                    )
                                    if let closestIndex = findClosestPoint(to: location) {
                                        updateMeshPoint(index: closestIndex, with: value, in: geometry)
                                    }
                                }
                            }
                    )
                    .animation(
                        isEditingMode
                        ? .spring(response: 0.6, dampingFraction: 0.5, blendDuration: 0.1)
                        : .easeInOut,
                        value: isEditingMode
                    )
                    .simultaneousGesture(
                        TapGesture(count: 2)
                            .onEnded {
                                // Double tap to toggle edit mode
                                if !isEditingMode {
                                    // When entering editing mode, use a spring animation
                                    withAnimation(.spring(response: 0.6, dampingFraction: 0.5, blendDuration: 0.1)) {
                                        isEditingMode.toggle()
                                    }
                                } else {
                                    // When exiting editing mode, use a smoother animation
                                    withAnimation(.easeInOut) {
                                        isEditingMode.toggle()
                                    }
                                }
                            }
                    )
                    // Adding a subtle glow effect when editing
                    .shadow(color: isEditingMode ? Color.white.opacity(0.15) : Color.clear, radius: 100)
                
                // Editing overlay with clusters
                ForEach(meshPoints.indices, id: \.self) { index in
                    let point = getPoint(for: index, in: geometry)
                    
                    ClusterView(color: colors[index], isMovable: isPointMovable(index))
                        .position(point)
                        .scaleEffect(isEditingMode ? 1 : 0.01)
                        .opacity(isEditingMode ? 1 : 0)
                        .animation(.interpolatingSpring(stiffness: 110, damping: 8).delay(0.05 * Double(index)), value: isEditingMode)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    if isEditingMode {
                                        updateMeshPoint(index: index, with: value, in: geometry)
                                    }
                                }
                        )
                        .onTapGesture {
                            selectedPointIndex = IdentifiableInt(value: index)
                        }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .ignoresSafeArea()
        .sheet(item: $selectedPointIndex) { selectedIndex in
            ColorPicker("Select Color", selection: $colors[selectedIndex.value])
                .labelsHidden()
                .padding()
                .background(Color.white)
                .cornerRadius(10)
                .shadow(radius: 5)
        }
    }
    
    private func adjustedMeshPoints(for geometry: GeometryProxy) -> [SIMD2<Float>] {
        if isEditingMode {
            let padding: CGFloat = 48
            let availableWidth = geometry.size.width - (padding * 2)
            let availableHeight = geometry.size.height - (padding * 2)
            let aspectRatio: CGFloat = 2/3
            
            let width: CGFloat
            let height: CGFloat
            if availableWidth / availableHeight > aspectRatio {
                height = availableHeight
                width = height * aspectRatio
            } else {
                width = availableWidth
                height = width / aspectRatio
            }
            
            let xOffset = (geometry.size.width - width) / 2
            let yOffset = (geometry.size.height - height) / 2
            
            return meshPoints.map { point in
                SIMD2<Float>(
                    Float((CGFloat(point.x) * width + xOffset) / geometry.size.width),
                    Float((CGFloat(point.y) * height + yOffset) / geometry.size.height)
                )
            }
        } else {
            return meshPoints
        }
    }
    
    private func getPoint(for index: Int, in geometry: GeometryProxy) -> CGPoint {
        let adjustedPoints = adjustedMeshPoints(for: geometry)
        let point = adjustedPoints[index]
        return CGPoint(
            x: CGFloat(point.x) * geometry.size.width,
            y: CGFloat(point.y) * geometry.size.height
        )
    }
    
    private func isPointMovable(_ index: Int) -> Bool {
        switch index {
        case 0, 2, 6, 8:
            return false
        default:
            return true
        }
    }
    
    private func updateMeshPoint(index: Int, with value: DragGesture.Value, in geometry: GeometryProxy) {
        let newX = Float(value.location.x / geometry.size.width)
        let newY = Float(value.location.y / geometry.size.height)
        
        switch index {
        case 0, 2, 6, 8:
            // These points can't be moved
            return
        case 1, 7:
            // These points can only be moved horizontally
            meshPoints[index].x = newX
        case 3, 5:
            // These points can only be moved vertically
            meshPoints[index].y = newY
        case 4:
            // This point can be moved freely
            meshPoints[index] = SIMD2(newX, newY)
        default:
            // This shouldn't happen, but just in case
            return
        }
    }
    
    private func findClosestPoint(to location: SIMD2<Float>) -> Int? {
        meshPoints.enumerated().min(by: {
            distance(location, $0.element) < distance(location, $1.element)
        })?.offset
    }
    
    private func distance(_ a: SIMD2<Float>, _ b: SIMD2<Float>) -> Float {
        let diff = a - b
        return sqrt(diff.x * diff.x + diff.y * diff.y)
    }
    
    struct ClusterView: View {
        var color: Color
        var isMovable: Bool

        var body: some View {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.5))
                    .frame(width: 40, height: 40)
                    .background(BlurView(style: .systemThinMaterial))
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 2)

                Circle()
                    .fill(color)
                    .frame(width: 30, height: 30)
                    .overlay(
                        Circle()
                           .stroke(
                               RadialGradient(
                                   gradient: Gradient(colors: [Color.white.opacity(0.25), Color.clear]),
                                   center: .top,
                                   startRadius: 5,
                                   endRadius: 15
                               ),
                               lineWidth: 4
                           )
                           .clipShape(Circle())
                    )
                    .shadow(color: Color.black.opacity(0.25), radius: 2, x: 0, y: 1)
                
                if !isMovable {
                    Image(systemName: "lock.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 12))
                }
            }
        }
    }
    
    struct BlurView: UIViewRepresentable {
        var style: UIBlurEffect.Style

        func makeUIView(context: Context) -> UIVisualEffectView {
            return UIVisualEffectView(effect: UIBlurEffect(style: style))
        }

        func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
            uiView.effect = UIBlurEffect(style: style)
        }
    }
}

struct ContentView: View {
    var body: some View {
        MeshGradientView()
    }
}

extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        _ = scanner.scanString("#")
        
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)
        
        let r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = Double(rgbValue & 0x0000FF) / 255.0
        
        self.init(red: r, green: g, blue: b)
    }
}

#Preview {
    ContentView()
}

