//
//  GeometryHelpers.swift
//  Mesh
//
//  Created by Tyler Watson on 10/12/24.
//
import SwiftUI

// MARK: - Point Adjustment Functions

func adjustedMeshPoints(meshPoints: [MeshPoint], isEditingMode: Bool, gridSize: Int, geometry: GeometryProxy) -> [SIMD2<Float>] {
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

func getPoint(for index: Int, adjustedPoints: [SIMD2<Float>], geometry: GeometryProxy) -> CGPoint {
    let point = adjustedPoints[index]
    return CGPoint(
        x: CGFloat(point.x) * geometry.size.width,
        y: CGFloat(point.y) * geometry.size.height
    )
}

func isPointMovable(_ index: Int, gridSize: Int) -> Bool {
    let x = index % gridSize
    let y = index / gridSize
    
    // Corners can't be moved
    if (x == 0 || x == gridSize - 1) && (y == 0 || y == gridSize - 1) {
        return false
    }
    return true
}

// MARK: - Mesh Point Movement Functions

func updateMeshPoint(index: Int, with value: DragGesture.Value, meshPoints: inout [MeshPoint], gridSize: Int, geometry: GeometryProxy) {
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

func updateNearestMeshPoint(
    to value: DragGesture.Value,
    meshPoints: inout [MeshPoint],
    initialDragLocation: inout CGPoint?,
    initialMeshPointPosition: inout SIMD2<Float>?,
    currentDraggingIndex: inout Int?,
    gridSize: Int,
    geometry: GeometryProxy
) {
    guard let initialLocation = initialDragLocation else { return }
    
    // Convert drag translation to normalized coordinates
    let translationX = Float(value.translation.width / geometry.size.width)
    let translationY = Float(value.translation.height / geometry.size.height)
    
    // If we already have a current dragging index, update that point
    if let index = currentDraggingIndex, let initialPosition = initialMeshPointPosition {
        let newX = initialPosition.x + translationX
        let newY = initialPosition.y + translationY
        moveMeshPoint(at: index, to: SIMD2<Float>(newX, newY), isHorizontalDrag: nil, meshPoints: &meshPoints, gridSize: gridSize, geometry: geometry)
        return
    }
    
    // Calculate total drag translation
    let totalTranslation = CGPoint(
        x: value.location.x - initialLocation.x,
        y: value.location.y - initialLocation.y
    )
    
    // Determine drag direction
    let isHorizontalDrag = abs(totalTranslation.x) > abs(totalTranslation.y)
    
    let location = value.location
    let dragX = Float(location.x / geometry.size.width)
    let dragY = Float(location.y / geometry.size.height)
    
    let edgeThreshold: CGFloat = 0.2 // 20% threshold
    let widthThreshold = geometry.size.width * edgeThreshold
    let heightThreshold = geometry.size.height * edgeThreshold
    
    var eligibleIndices: [Int] = []
    
    // Determine proximity to edges
    let nearTopEdge = location.y <= heightThreshold
    let nearBottomEdge = location.y >= geometry.size.height - heightThreshold
    let nearLeftEdge = location.x <= widthThreshold
    let nearRightEdge = location.x >= geometry.size.width - widthThreshold
    let nearHorizontalCenter = !nearTopEdge && !nearBottomEdge
    let nearVerticalCenter = !nearLeftEdge && !nearRightEdge
    
    // Determine eligible mesh points based on proximity and drag direction
    for (index, meshPoint) in meshPoints.enumerated() {
        if isPointMovable(index, gridSize: gridSize) {
            let x = index % gridSize
            let y = index / gridSize
            
            switch (isHorizontalDrag, nearTopEdge, nearBottomEdge, nearLeftEdge, nearRightEdge, nearHorizontalCenter, nearVerticalCenter) {
            case (true, true, _, _, _, _, _): // Horizontal drag near top edge
                if y == 0 {
                    eligibleIndices.append(index)
                }
            case (true, _, true, _, _, _, _): // Horizontal drag near bottom edge
                if y == gridSize - 1 {
                    eligibleIndices.append(index)
                }
            case (false, _, _, true, _, _, _): // Vertical drag near left edge
                if x == 0 {
                    eligibleIndices.append(index)
                }
            case (false, _, _, _, true, _, _): // Vertical drag near right edge
                if x == gridSize - 1 {
                    eligibleIndices.append(index)
                }
            case (true, _, _, _, _, true, _): // Horizontal drag near center
                if y == gridSize / 2 {
                    eligibleIndices.append(index)
                }
            case (false, _, _, _, _, _, true): // Vertical drag near center
                if x == gridSize / 2 {
                    eligibleIndices.append(index)
                }
            default:
                break
            }
        }
    }
    
    // If no eligible indices found, fallback to all movable points
    if eligibleIndices.isEmpty {
        for (index, _) in meshPoints.enumerated() {
            if isPointMovable(index, gridSize: gridSize) {
                eligibleIndices.append(index)
            }
        }
    }
    
    // Find the nearest eligible mesh point
    var nearestIndex: Int? = nil
    var smallestDistance: Float = .greatestFiniteMagnitude
    
    for index in eligibleIndices {
        let point = meshPoints[index].position
        let distance = pow(point.x - dragX, 2) + pow(point.y - dragY, 2)
        if distance < smallestDistance {
            smallestDistance = distance
            nearestIndex = index
        }
    }
    
    // Set the current dragging index and move the point
    if let nearestIndex = nearestIndex {
        currentDraggingIndex = nearestIndex
        initialMeshPointPosition = meshPoints[nearestIndex].position
        let newX = initialMeshPointPosition!.x + translationX
        let newY = initialMeshPointPosition!.y + translationY
        moveMeshPoint(at: nearestIndex, to: SIMD2<Float>(newX, newY), isHorizontalDrag: isHorizontalDrag, meshPoints: &meshPoints, gridSize: gridSize, geometry: geometry)
    }
}



func moveMeshPoint(
    at index: Int,
    to position: SIMD2<Float>,
    isHorizontalDrag: Bool?,
    meshPoints: inout [MeshPoint],
    gridSize: Int,
    geometry: GeometryProxy
) {
    var newX = position.x
    var newY = position.y
    
    newX = min(max(newX, 0), 1)
    newY = min(max(newY, 0), 1)
    
    let x = index % gridSize
    let y = index / gridSize
    
    switch (x, y) {
    case (0, _), (gridSize - 1, _):
        meshPoints[index].position.y = newY
    case (_, 0), (_, gridSize - 1):
        meshPoints[index].position.x = newX
    default:
        if let isHorizontalDrag = isHorizontalDrag {
            if isHorizontalDrag {
                meshPoints[index].position.x = newX
            } else {
                meshPoints[index].position.y = newY
            }
        } else {
            meshPoints[index].position = SIMD2(newX, newY)
        }
    }
}

