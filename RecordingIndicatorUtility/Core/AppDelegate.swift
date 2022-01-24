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
    
    func startZeroSecondRecording() {
        // Begin a 0 second long recording to force WindowServer and Control Center refresh their recording state.
        // No audio is actually recorded or saved.
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            performZeroSecondRecording()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                if granted {
                    self.performZeroSecondRecording()
                } else {
                    self.promptForLackOfAudioAuthorization()
                }
            }
        case .denied, .restricted:
            promptForLackOfAudioAuthorization()
        @unknown default:
            promptForLackOfAudioAuthorization()
        }
    }
    
    private func performZeroSecondRecording() {
        let url = URL(fileURLWithPath: (NSTemporaryDirectory() as NSString).appendingPathComponent("discarded"))
        do {
            let recorder = try AVAudioRecorder(url: url, settings: [:])
            recorder.record(forDuration: 0)
        } catch {
            print("Unable to simulate a zero second recording to refresh microphone indicator, \(error)")
        }
    }
    
    private func promptForLackOfAudioAuthorization() {
        DispatchQueue.main.async {
            AppDelegate.showOptionSheet(title: "Changes to the recording indicator take effect when you pause an existing recording or start a new recording.", text: "For changes to take effect immediately in the future, allow Recording Indicator Utility to access your microphone.", firstButtonText: "Open Microphone Preferences", secondButtonText: "Not Now", thirdButtonText: "", prefersKeyWindow: true) { response in
                if response == .alertFirstButtonReturn {
                    AppDelegate.current.safelyOpenURL("x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")
                }
            }
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
    
    static func showOptionSheet(title: String, text: String, firstButtonText: String, secondButtonText: String, thirdButtonText: String, prefersKeyWindow: Bool = false, callback: @escaping ((_ response: NSApplication.ModalResponse)-> ())) {
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
        if let window = prefersKeyWindow ? NSApp.keyWindow : self.appWindow {
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

