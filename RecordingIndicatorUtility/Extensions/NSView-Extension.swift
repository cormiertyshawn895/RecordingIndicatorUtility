//
//  NSView-Extension.swift
//  Recording Indicator Utility
//

import AppKit

extension NSView {
    func growByHeight(_ height: CGFloat, onlyShiftOrigin: Bool = false) {
        var newFrame = self.frame
        newFrame.origin.y -= height
        if (!onlyShiftOrigin) {
            newFrame.size.height += height
        }
        self.frame = newFrame
    }
}
