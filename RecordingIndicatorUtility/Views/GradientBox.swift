//
//  GradientBox.swift
//  Recording Indicator Utility
//

import Cocoa

class GradientBox: NSBox {
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let backgroundColor = NSColor(named: "WindowBackground") else {
            return
        }
        let gradient = NSGradient(colors: [backgroundColor, backgroundColor.withAlphaComponent(0)])
        gradient?.draw(in: bounds, angle: 90)
    }
    
}
