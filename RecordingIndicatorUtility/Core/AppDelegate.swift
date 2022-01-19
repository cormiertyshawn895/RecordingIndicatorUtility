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
    
    func safelyOpenURL(_ urlString: String?) {
        if let page = urlString, let url = URL(string: page) {
            NSWorkspace.shared.open(url)
        }
    }
    
    @objc func promptForUpdateAvailable() {
        if (SystemInformation.shared.hasNewerVersion == true) {
            AppDelegate.showOptionSheet(title: SystemInformation.shared.newVersionVisibleTitle ?? "Update available.",
                                        text: SystemInformation.shared.newVersionChangelog ?? "A newer version of Recording Indicator Utility is available.",
                                        firstButtonText: "Download",
                                        secondButtonText: "Learn More...",
                                        thirdButtonText: "Cancel") { (response) in
                if (response == .alertFirstButtonReturn) {
                    AppDelegate.current.safelyOpenURL(SystemInformation.shared.latestZIP)
                } else if (response == .alertSecondButtonReturn) {
                    AppDelegate.current.safelyOpenURL(SystemInformation.shared.releasePage)
                }
            }
        } else {
            AppDelegate.showOptionSheet(title: String(format: "Recording Indicator Utility %@ is already the latest available version.", Bundle.main.cfBundleVersionString ?? ""),
                                        text:"",
                                        firstButtonText: "OK",
                                        secondButtonText: "View Release Page...",
                                        thirdButtonText: "") { (response) in
                if (response == .alertSecondButtonReturn) {
                    AppDelegate.current.safelyOpenURL(SystemInformation.shared.releasePage)
                }
            }
        }
    }

    @IBAction func checkForUpdates(_ sender: Any? = nil) {
        SystemInformation.shared.checkForConfigurationUpdates()
        if (SystemInformation.shared.hasNewerVersion == true) {
            self.promptForUpdateAvailable()
        } else {
            Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(promptForUpdateAvailable), userInfo: nil, repeats: false)
        }
    }
    
    @IBAction func tipsClicked(_ sender: Any) {
        self.safelyOpenURL("https://github.com/cormiertyshawn895/RecordingIndicatorUtility#troubleshooting-tips")
    }
    
    @IBAction func frequentlyAskedQuestionsClicked(_ sender: Any) {
        self.safelyOpenURL("https://github.com/cormiertyshawn895/RecordingIndicatorUtility#frequently-asked-questions")
    }
    
    @IBAction func openIssue(_ sender: Any? = nil) {
        self.safelyOpenURL("https://github.com/cormiertyshawn895/RecordingIndicatorUtility/issues/new")
    }
    
    @IBAction func projectPage(_ sender: Any? = nil) {
        self.safelyOpenURL("https://github.com/cormiertyshawn895/RecordingIndicatorUtility")
    }
    
    @IBAction func issueTracker(_ sender: Any) {
        self.safelyOpenURL("https://github.com/cormiertyshawn895/RecordingIndicatorUtility/issues")
    }
    
    static var current: AppDelegate {
        return NSApplication.shared.delegate as! AppDelegate
    }
    
    static var rootVC: ViewController? {
        get {
            return self.appWindow?.contentViewController as? ViewController
        }
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

