
//  MeshGradientView.swift
//  ColorPickerTest
//
//  Created by Tyler Watson on 10/12/24.
//

import SwiftUI

struct MeshGradientView: View {
    @State private var isEditingMode: Bool = false
    @State private var selectedPointIndex: Int? = nil
    
    // Start with 3x3 grid
    @State private var gridSize: Int = 3
    
    // Dynamic mesh points and colors
    @State private var meshPoints: [MeshPoint] = []
    @State private var colors: [Color] = []
    
    // For drag gesture
    @State private var initialDragLocation: CGPoint?
    @State private var currentDraggingIndex: Int? = nil
    @State private var initialMeshPointPosition: SIMD2<Float>? = nil
    
    // Sliders
    @State private var hueAdjustment: Double = 0.0
    @State private var saturationAdjustment: Double = 1.0
    @State private var brightnessAdjustment: Double = 1.0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                // Background color
                (isEditingMode ? Color(hue: 0.58, saturation: 0.15, brightness: 0.06) : Color.clear)
                    .ignoresSafeArea()
                
                // Background mesh gradient
                MeshGradient(width: gridSize, height: gridSize, points: adjustedMeshPoints(for: geometry), colors: adjustedColors())
                    .animation(
                        isEditingMode
                        ? .spring(response: 0.6, dampingFraction: 0.5, blendDuration: 0.1)
                        : .easeInOut,
                        value: isEditingMode
                    )
                    .shadow(color: isEditingMode ? Color.white.opacity(0.15) : Color.clear, radius: 100)
                
                // Editing overlay with clusters
                ForEach(meshPoints.indices, id: \.self) { index in
                    let point = getPoint(for: index, in: geometry)
                    
                    ClusterView(color: $colors[index], isMovable: isPointMovable(index))
                        .position(point)
                        .scaleEffect(isEditingMode ? 1 : 0.2)
                        .opacity(isEditingMode ? 1 : 0)
                        .animation(.interpolatingSpring(stiffness: 110, damping: 8).delay(0.05 * Double(index)), value: isEditingMode)
                        .zIndex(isPointMovable(index) ? 1 : 0)
                        .gesture(
                            DragGesture(minimumDistance: 10)
                                .onChanged { value in
                                    if isEditingMode && isPointMovable(index) {
                                        updateMeshPoint(index: index, with: value, in: geometry)
                                    }
                                }
                        )
                }
                
                // Dice icon and sliders
                if isEditingMode {
                    VStack {
                        Spacer()
                        VStack(spacing: 16) {
                            Slider(value: $hueAdjustment, in: -1...1) {
                                Text("Hue")
                            }
                            Slider(value: $saturationAdjustment, in: 0...2) {
                                Text("Saturation")
                            }
                            Slider(value: $brightnessAdjustment, in: 0...2) {
                                Text("Brightness")
                            }
                            HStack {
                                Spacer()
                                Button(action: {
                                    randomizeColors()
                                }) {
                                    Image(systemName: "dice")
                                        .resizable()
                                        .frame(width: 44, height: 44)
                                        .padding()
                                }
                            }
                        }
                        .padding()
                        .background(BlurView(style: .systemThinMaterial))
                        .cornerRadius(12)
                        .padding()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                isEditingMode ? nil : DragGesture(minimumDistance: 10)
                    .onChanged { value in
                        if initialDragLocation == nil {
                            initialDragLocation = value.startLocation
                        }
                        updateNearestMeshPoint(to: value, in: geometry)
                    }
                    .onEnded { _ in
                        initialDragLocation = nil
                        initialMeshPointPosition = nil
                        currentDraggingIndex = nil
                    }
            )
            .highPriorityGesture(
                TapGesture(count: 2)
                    .onEnded {
                        withAnimation(isEditingMode ? .easeInOut : .spring(response: 0.6, dampingFraction: 0.5, blendDuration: 0.1)) {
                            isEditingMode.toggle()
                        }
                    }
            )
        }
        .ignoresSafeArea()
        .onAppear {
            setupGrid()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Stepper(value: $gridSize, in: 3...4, step: 1, onEditingChanged: { _ in
                    setupGrid()
                }) {
                    Text("\(gridSize)x\(gridSize) Grid")
                }
            }
        }
    }
}

extension MeshGradientView {
    // MARK: - Setup Methods
    
    private func setupGrid() {
        meshPoints = []
        colors = []
        
        for y in 0..<gridSize {
            for x in 0..<gridSize {
                let point = SIMD2<Float>(Float(x) / Float(gridSize - 1), Float(y) / Float(gridSize - 1))
                meshPoints.append(MeshPoint(position: point))
                colors.append(randomColor())
            }
        }
    }
    
    // MARK: - Adjustment Methods
    
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
                    Float((CGFloat(point.position.x) * width + xOffset) / geometry.size.width),
                    Float((CGFloat(point.position.y) * height + yOffset) / geometry.size.height)
                )
            }
        } else {
            return meshPoints.map { $0.position }
        }
    }
    
    private func adjustedColors() -> [Color] {
        return colors.map { color in
            color.adjusted(hue: hueAdjustment, saturation: saturationAdjustment, brightness: brightnessAdjustment)
        }
    }
    
    // MARK: - Point Methods
    
    private func getPoint(for index: Int, in geometry: GeometryProxy) -> CGPoint {
        let adjustedPoints = adjustedMeshPoints(for: geometry)
        let point = adjustedPoints[index]
        return CGPoint(
            x: CGFloat(point.x) * geometry.size.width,
            y: CGFloat(point.y) * geometry.size.height
        )
    }
    
    private func isPointMovable(_ index: Int) -> Bool {
        let x = index % gridSize
        let y = index / gridSize
        
        if (x == 0 || x == gridSize - 1) && (y == 0 || y == gridSize - 1) {
            return false
        }
        return true
    }
    
    private func updateMeshPoint(index: Int, with value: DragGesture.Value, in geometry: GeometryProxy) {
        let newX = Float(value.location.x / geometry.size.width)
        let newY = Float(value.location.y / geometry.size.height)
        
        let x = index % gridSize
        let y = index / gridSize
        
        switch (x, y) {
        case (0, _), (gridSize - 1, _):
            meshPoints[index].position.y = newY
        case (_, 0), (_, gridSize - 1):
            meshPoints[index].position.x = newX
        default:
            meshPoints[index].position = SIMD2(newX, newY)
        }
    }
    
    private func updateNearestMeshPoint(to value: DragGesture.Value, in geometry: GeometryProxy) {
        Mesh.updateNearestMeshPoint(
            to: value,
            meshPoints: &meshPoints,
            initialDragLocation: &initialDragLocation,
            initialMeshPointPosition: &initialMeshPointPosition,
            currentDraggingIndex: &currentDraggingIndex,
            gridSize: gridSize,
            geometry: geometry
        )
    }
    
    private func moveMeshPoint(at index: Int, to position: SIMD2<Float>, isHorizontalDrag: Bool?, geometry: GeometryProxy) {
        Mesh.moveMeshPoint(
            at: index,
            to: position,
            isHorizontalDrag: isHorizontalDrag,
            meshPoints: &meshPoints,
            gridSize: gridSize,
            geometry: geometry
        )
    }
    
    // MARK: - Color Methods
    
    private func randomColor() -> Color {
        // Generate a random brightness value between 0.4 and 0.8
           let brightness = Double.random(in: 0.4...0.8)
           
           // Generate a random saturation value greater than 0.5
           let saturation = Double.random(in: 0.5...1.0)
           
           // Generate a random hue between 0 and 1
           let hue = Double.random(in: 0.0...1.0)
           
           // Return a Color using the HSB (Hue, Saturation, Brightness) model
           return Color(hue: hue, saturation: saturation, brightness: brightness)
       }
    
    private func randomizeColors() {
        colors = colors.map { _ in randomColor() }
    }
}

