//
//  ColorExtensions.swift
//  Mesh
//
//  Created by Tyler Watson on 10/12/24.
//
import SwiftUI

extension Color {
    func adjusted(hue: Double, saturation: Double, brightness: Double) -> Color {
        var h: CGFloat = 0
        var s: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        
        UIColor(self).getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        
        h += CGFloat(hue)
        if h > 1 { h -= 1 }
        if h < 0 { h += 1 }
        
        s *= CGFloat(saturation)
        s = min(max(s, 0), 1)
        
        b *= CGFloat(brightness)
        b = min(max(b, 0), 1)
        
        return Color(hue: Double(h), saturation: Double(s), brightness: Double(b), opacity: Double(a))
    }
}

