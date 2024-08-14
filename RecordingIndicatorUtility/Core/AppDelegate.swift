//
//  AppDelegate.swift
//  Recording Indicator Utility
//

import AVFAudio
import AVFoundation
import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    var shouldPreventClosing = false
    @IBOutlet weak var showSystemOverrideMenuItem: NSMenuItem!
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        NSApp.activate(ignoringOtherApps: true)
        if (!osAtLeastSonomaE) {
            showSystemOverrideMenuItem.isHidden = true
        }
        if (osAtLeastSonomaE && !UserDefaults.standard.bool(forKey: "AcknowledgedSystemOverrideAlert") && SystemInformation.shared.isSystemstatusdLoaded) {
            self.showSystemOverrideInstructions(self)
        }
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
                                        thirdButtonText: "Cancel") { (response, isChecked) in
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
                                        thirdButtonText: "") { (response, isChecked) in
                if (response == .alertSecondButtonReturn) {
                    AppDelegate.current.safelyOpenURL(SystemInformation.shared.releasePage)
                }
            }
        }
    }
    
    @IBAction func showSystemOverrideInstructions(_ sender: Any) {
        UserDefaults.standard.setValue(nil, forKey: "AcknowledgedSystemOverrideAlert")
        AppDelegate.showOptionSheet(title: "You can hide the recording indicator on external displays without using Recording Indicator Utility.",
                                    text: "Start up from macOS Recovery, and enter this command in Terminal:\n\nsystem-override suppress-sw-camera-indication-on-external-displays=on\n\nRestart, then open System Settings > Privacy & Security > Microphone, and turn off Privacy Indicators.",
                                    firstButtonText: "Learn More…",
                                    secondButtonText: "     Continue     ",
                                    thirdButtonText: "",
                                    checkboxText: "Don’t show this message again") { (response, isChecked) in
            if (response == .alertFirstButtonReturn) {
                AppDelegate.current.safelyOpenURL("https://support.apple.com/118449")
            }
            if (isChecked == true) {
                UserDefaults.standard.setValue(true, forKey: "AcknowledgedSystemOverrideAlert")
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
        self.safelyOpenURL("https://github.com/cormiertyshawn895/RecordingIndicatorUtility/issues?q=")
    }
    
    static var current: AppDelegate {
        return NSApplication.shared.delegate as! AppDelegate
    }
    
    static var rootVC: ViewController? {
        get {
            return self.appWindow?.contentViewController as? ViewController
        }
    }
    
    static func showOptionSheet(title: String, text: String, firstButtonText: String, secondButtonText: String, thirdButtonText: String, checkboxText: String? = nil, prefersKeyWindow: Bool = false, callback: @escaping ((_ response: NSApplication.ModalResponse, _ isChecked: Bool?)-> ())) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = text
        alert.alertStyle = NSAlert.Style.informational
        alert.addButton(withTitle: firstButtonText)
        var checkbox: NSButton?
        if let checkboxText = checkboxText {
            checkbox = NSButton(checkboxWithTitle: checkboxText, target: nil, action: nil)
            alert.accessoryView = checkbox
        }
        if secondButtonText.count > 0 {
            alert.addButton(withTitle: secondButtonText)
        }
        if thirdButtonText.count > 0 {
            alert.addButton(withTitle: thirdButtonText)
        }
        if let window = prefersKeyWindow ? NSApp.keyWindow : self.appWindow {
            alert.beginSheetModal(for: window) { (response) in
                callback(response, checkbox?.state == .on)
            }
        } else {
            let response = alert.runModal()
            callback(response, checkbox?.state == .on)
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

