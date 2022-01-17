//
//  AppDelegate.swift
//  Recording Indicator Utility
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    var shouldPreventClosing = false

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        return shouldPreventClosing ? .terminateCancel : .terminateNow
    }
    
    @IBAction func checkForUpdates(_ sender: Any? = nil) {
        NSWorkspace.shared.open(URL(string:"https://github.com/cormiertyshawn895/RecordingIndicatorUtility/releases")!)
    }
    
    @IBAction func openIssue(_ sender: Any? = nil) {
        NSWorkspace.shared.open(URL(string:"https://github.com/cormiertyshawn895/RecordingIndicatorUtility/issues/new")!)
    }
    
    @IBAction func projectPage(_ sender: Any? = nil) {
        NSWorkspace.shared.open(URL(string:"https://github.com/cormiertyshawn895/RecordingIndicatorUtility")!)
    }
    
    @IBAction func issueTracker(_ sender: Any) {
        NSWorkspace.shared.open(URL(string:"https://github.com/cormiertyshawn895/RecordingIndicatorUtility/issues")!)
    }
    
    static var current: AppDelegate {
        return NSApplication.shared.delegate as! AppDelegate
    }
    
    static func showOptionSheet(title: String, text: String, firstButtonText: String, secondButtonText: String, thirdButtonText: String, callback: @escaping ((_ response: NSApplication.ModalResponse)-> ())) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = text
        alert.alertStyle = NSAlert.Style.informational
        alert.addButton(withTitle: firstButtonText)
        if secondButtonText.count > 0 {
            alert.addButton(withTitle: secondButtonText)
        }
        if thirdButtonText.count > 0 {
            alert.addButton(withTitle: thirdButtonText)
        }
        if let window = self.appWindow {
            alert.beginSheetModal(for: window) { (response) in
                callback(response)
            }
        } else {
            let response = alert.runModal()
            callback(response)
        }
    }
    
    static var appWindow: NSWindow? {
        if let mainWindow = NSApp.mainWindow {
            return mainWindow
        }
        for window in NSApp.windows {
            if let typed = window as? MainWindow {
                return typed
            }
        }
        return nil
    }
}

