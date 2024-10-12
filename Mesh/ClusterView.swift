//
//  ClusterView.swift
//  Mesh
//
//  Created by Tyler Watson on 10/12/24.
//

import SwiftUI

struct ClusterView: View {
    @Binding var color: Color
    var isMovable: Bool
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.5))
                .frame(width: 44, height: 44)
                .background(BlurView(style: .systemThinMaterial))
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 2)
            
            Circle()
                .fill(color)
                .frame(width: 36, height: 36)
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
            
            // Invisible ColorPicker overlay
            ColorPicker("", selection: $color)
                .labelsHidden()
                .opacity(0.01)
                .frame(width: 44, height: 44)
        }
    }
}

