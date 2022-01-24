//
//  AppException.swift
//  Recording Indicator Utility
//

import Foundation

// Mapping for "Apps Using Microphone" menu and "Show in Finder"
let serviceToApp: [String: (name: String, path: String?)] = [
    "avconferenced": ("FaceTime", "/System/Applications/FaceTime.app"),
    "corespeechd": ("Siri and Dictation", "/System/Applications/Siri.app"),
    "PreferencePanes": ("System Preferences", "/System/Applications/System Preferences.app"),
    "screencapture": ("Screenshot", "/System/Applications/Utilities/Screenshot.app"),
    "com.apple.preference.keyboard.remoteservice": ("Keyboard Preferences", nil),
    "com.apple.preference.sound.remoteservice": ("Sound Preferences", nil),
    "com.apple.preference.speech.remoteservice": ("Siri Preferences", nil),
    "com.apple.WorkflowKit.ShortcutsViewService": ("Shortcuts Action", "/System/Applications/Shortcuts.app"),

    "com.apple.WebKit.GPU": ("Websites", "/Applications/Safari.app"),
    "com.google.Chrome.helper": ("Websites (Google Chrome)", nil),
    "org.mozilla.plugincontainer": ("Websites (Firefox)", nil),
    "com.microsoft.edgemac.helper": ("Websites (Microsoft Edge)", nil),
    "com.operasoftware.Opera.helper": ("Websites (Opera)", nil),
    "com.vivaldi.Vivaldi.helper": ("Websites (Vivaldi)", nil),
]

// The launcher does not record audio, only the service does.
let launcherBundleIDToService: [String: String] = [
    "com.apple.FaceTime": "/usr/libexec/avconferenced",
    "com.apple.screenshot.launcher": "/usr/sbin/screencapture",
    "com.apple.siri.launcher": "/System/Library/PrivateFrameworks/CoreSpeech.framework/corespeechd",
    "com.apple.systempreferences": "/System/Library/PreferencePanes",
]

// Both the app and the agent can record audio.
let appBundleIDToAgent: [String: String] = [
    "com.apple.QuickTimePlayerX": "/usr/sbin/screencapture",
    "com.apple.Safari": "/System/Library/Frameworks/WebKit.framework/Versions/A/XPCServices/com.apple.WebKit.GPU.xpc",
    "com.apple.shortcuts": "/System/Library/PrivateFrameworks/WorkflowKit.framework/XPCServices/ShortcutsViewService.xpc",
    "com.apple.SafariTechnologyPreview": "/System/Library/Frameworks/WebKit.framework/Versions/A/XPCServices/com.apple.WebKit.GPU.xpc",
]

class AppException: Codable {
    var bundleIdentifier: String?
    var path: String?
    var bundleName: String?
    var binaryName: String?
    var enabled = true
    
    init(bundleIdentifier: String?, path: String?, bundleName: String?, binaryName: String?) {
        self.bundleIdentifier = bundleIdentifier
        self.path = path
        self.bundleName = bundleName
        self.binaryName = binaryName
    }
    
    var bundle: Bundle? {
        if let bundlePath = path {
            return Bundle(path: bundlePath)
        }
        if let bundleID = bundleIdentifier {
            return Bundle(identifier: bundleID)
        }
        return nil
    }
    
    var userFacingName: String {
        if let bundleID = bundleIdentifier ?? binaryName, let (serviceName, _) = serviceToApp[bundleID] {
            return serviceName
        }
        
        if let resolvedBundle = bundle {
            if let displayName = resolvedBundle.localizedInfoDictionary?["CFBundleDisplayName"] as? String {
                return displayName
            }
            if let displayName = resolvedBundle.infoDictionary?["CFBundleDisplayName"] as? String {
                return displayName
            }
            if let fallbackName = resolvedBundle.infoDictionary?["CFBundleName"] as? String {
                return fallbackName
            }
        }
        return bundleName?.lastPathComponentWithoutExtension ?? binaryName ?? path?.lastPathComponentWithoutExtension ?? "Unknown"
    }
    
    var icon: NSImage? {
        if let bundleID = bundleIdentifier ?? binaryName {
            let tuple = serviceToApp[bundleID]
            if let correspondingPath = tuple?.path {
                return NSWorkspace.shared.icon(forFile: correspondingPath)
            }
        }
        
        if let resolvedBundle = self.bundle {
            return NSWorkspace.shared.icon(forFile: resolvedBundle.bundlePath.rootBundlePath)
        }
        
        if let resolvedPath = path {
            return NSWorkspace.shared.icon(forFile: resolvedPath.rootBundlePath)
        }
        
        return NSImage(named: "GenericAppIcon")
    }
    
    var urlToRevealInFinder: URL? {
        if let path = self.path, let userFacingApp = serviceToApp[path.lastPathComponent], let userFacingPath = userFacingApp.path {
            return URL(fileURLWithPath: userFacingPath)
        }
        
        if let bundle = self.bundle {
            let bundleURL = bundle.bundleURL
            if let bID = bundleIdentifier, let (_, path) = serviceToApp[bID], let path = path {
                return URL(fileURLWithPath: path)
            }
            return bundleURL
        }
        
        if let path = self.path {
            return URL(fileURLWithPath: path)
        }
        
        return nil
    }
}
