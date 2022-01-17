//
//  WindowController.swift
//  Recording Indicator Utility
//

import Cocoa

class WindowController: NSWindowController, NSWindowDelegate {
    
    override func windowDidLoad() {
        super.windowDidLoad()
        
        window?.backgroundColor = NSColor(named: "WindowBackground")
        window?.delegate = self
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        return !AppDelegate.current.shouldPreventClosing
    }
}
