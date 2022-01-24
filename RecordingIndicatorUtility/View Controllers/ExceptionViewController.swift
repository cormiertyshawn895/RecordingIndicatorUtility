//
//  ExceptionViewController.swift
//  Recording Indicator Utility
//

import Cocoa
import UniformTypeIdentifiers

let plistURL = URL(fileURLWithPath: "\(injectionFolderPath)/\(injectionExceptionsPlistName)")
let checkboxPath = "\(injectionFolderPath)/\(injectionOnlyWantsControlCenterIndicatorFileName)"

class ExceptionViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource, AppExceptionTableCellViewDelegate {
    @IBOutlet weak var roundedBoxView: NSBox!
    @IBOutlet weak var scrollView: NSScrollView!
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var horizontalLineView: NSBox!
    @IBOutlet weak var addButton: NSButton!
    @IBOutlet weak var removeButton: NSButton!
    @IBOutlet weak var fullScreenAutoHideCheckbox: NSButton!
    
    var exceptions: [AppException] = []
    
    // MARK: - Set Up
    static func instantiate() -> ExceptionViewController {
        return NSStoryboard.main?.instantiateController(withIdentifier: "ExceptionViewController") as! ExceptionViewController
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        addButton.sendAction(on: [.leftMouseDown])
        setUpScrollView()
        setUpTableView()
        readCheckboxFromDisk()
        readExceptionsFromDisk()
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        self.view.window?.preventsApplicationTerminationWhenModal = false
        self.view.window?.styleMask.remove(.resizable)
    }
    
    func setUpScrollView() {
        scrollView.wantsLayer = true
        scrollView.layer?.masksToBounds = true
        scrollView.layer?.cornerCurve = .continuous
        scrollView.layer?.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        scrollView.layer?.cornerRadius = 10
    }
    
    func setUpTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.rowHeight = 48
        tableView.setDraggingSourceOperationMask(.copy, forLocal: false)
        tableView.registerForDraggedTypes([.fileURL])
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show in Finder", action: #selector(tableViewShowItemInFinderClicked(_:)), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Delete", action: #selector(tableViewDeleteItemClicked(_:)), keyEquivalent: ""))
        tableView.menu = menu
    }
    
    func readCheckboxFromDisk() {
        let checked = FileManager.default.fileExists(atPath: checkboxPath)
        fullScreenAutoHideCheckbox.state = checked ? .on : .off
    }
    
    func readExceptionsFromDisk() {
        let decoder = PropertyListDecoder()
        typealias Exceptions = [AppException]
        guard let data = try? Data.init(contentsOf: plistURL), let preferences = try? decoder.decode(Exceptions.self, from: data) else {
            return
        }
        self.exceptions = preferences
        tableView.reloadData()
    }
    
    // MARK: - Dismissal
    override func cancelOperation(_ sender: Any?) {
        self.dismiss(nil)
    }
    
    @IBAction func closeButtonClicked(_ sender: Any) {
        self.dismiss(nil)
    }
    
    // MARK: - Add and Remove
    @IBAction func addButtonClicked(_ sender: Any) {
        var candidateSources: [String] = []
        if let loaded = NSArray(contentsOfFile: "\(injectionFolderPath)/\(candidateSourcesPlistName)") as? [String] {
            candidateSources = loaded
        }
        print("Candidate sources: \(candidateSources)")

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Choose App…", action: #selector(chooseAppToAdd(_:)), keyEquivalent: ""))
        if (candidateSources.count > 0) {
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "Apps Using Microphone", action: nil, keyEquivalent: ""))
            for i in 0..<candidateSources.count {
                let candidate = candidateSources[i]
                let tuple = exceptionForPath(path: candidate)
                let exception = tuple.exception
                let menuItem = NSMenuItem(title: exception.userFacingName, action: #selector(addFromCandidateSource(_:)), keyEquivalent: "")
                if let imageCopy = exception.icon?.copy() as? NSImage {
                    imageCopy.size = NSSize(width: 18, height: 18)
                    menuItem.image = imageCopy
                }
                menuItem.representedObject = tuple
                menu.addItem(menuItem)
            }
        }
        let point = NSPoint(x: 0, y: addButton.bounds.size.height)
        menu.popUp(positioning: nil, at: point, in: addButton)
    }
    
    @objc func chooseAppToAdd(_ sender: Any) {
        let dialog = NSOpenPanel()
        dialog.directoryURL = URL(fileURLWithPath: "/Applications")
        dialog.showsResizeIndicator = true
        dialog.allowsMultipleSelection = true
        dialog.canChooseDirectories = false
        dialog.allowedContentTypes = [UTType.applicationBundle, UTType.unixExecutable]
        
        if (dialog.runModal() !=  NSApplication.ModalResponse.OK) {
            return
        }
        let results = dialog.urls
        if results.count <= 0 {
            return
        }
        for result in results {
            addExceptionForPath(path: result.path)
        }
        sortPersistAndReload()
    }
    
    @objc func addFromCandidateSource(_ sender: NSMenuItem) {
        if let exceptionTuple = sender.representedObject as? (AppException, Bool) {
            addExceptionTuple(exceptionTuple: exceptionTuple)
        }
    }
    
    func addExceptionForPath(path: String) {
        let exceptionTuple = exceptionForPath(path: path)
        addExceptionTuple(exceptionTuple: exceptionTuple, needsReload: false)
        if let exceptionBundleID = exceptionTuple.exception.bundleIdentifier, let agentPath = appBundleIDToAgent[exceptionBundleID] {
            let agentExceptionTuple = exceptionForPath(path: agentPath)
            addExceptionTuple(exceptionTuple: agentExceptionTuple, needsReload: false)
        }
    }
    
    func addExceptionTuple(exceptionTuple: (exception: AppException, existing: Bool), needsReload: Bool = true) {
        let exception = exceptionTuple.exception
        let existing = exceptionTuple.existing
        if (existing) {
            exception.enabled = true
        } else {
            exceptions.append(exception)
        }
        if (needsReload) {
            sortPersistAndReload()
        }
    }
    
    func exceptionForPath(path: String) -> (exception: AppException, existing: Bool) {
        var resolvedPath = path
        var bundle = Bundle(path: resolvedPath)
        var bundleIdentifier = bundle?.bundleIdentifier
        if let bID = bundleIdentifier, let servicePath = launcherBundleIDToService[bID] {
            // Don't save launcher bundle information. The service will be mapped with icon and name via serviceToApp.
            resolvedPath = servicePath
            bundle = nil
            bundleIdentifier = nil
        }
        let bundleName = bundle?.bundlePath.lastPathComponent
        let binaryName = bundle?.executablePath?.lastPathComponent ?? resolvedPath.lastPathComponent
        let existingMatch = exceptions.first { exception in
            return (bundleIdentifier != nil && exception.bundleIdentifier == bundleIdentifier) || (exception.path == resolvedPath)
        }
        if let existing = existingMatch {
            print("Bundle \(bundleIdentifier ?? "") or \(path) already exists, not adding again. Instead we update.")
            existing.bundleIdentifier = bundleIdentifier
            existing.path = resolvedPath
            existing.bundleName = bundleName
            existing.binaryName = binaryName
            return (existing, true)
        }
        let exception = AppException(bundleIdentifier: bundleIdentifier,
                                     path: resolvedPath,
                                     bundleName: bundleName,
                                     binaryName: binaryName)
        return (exception, false)
    }
    
    @IBAction func delete(_ sender: AnyObject) {
        removeSelectedRows()
    }
    
    @IBAction func removeButtonClicked(_ sender: Any) {
        removeSelectedRows()
    }
    
    func removeSelectedRows() {
        exceptions.remove(at: tableView.selectedRowIndexes)
        sortPersistAndReload()
    }
    
    func sortPersistAndReload() {
        exceptions.sort { first, second in
            return first.userFacingName.localizedStandardCompare(second.userFacingName) == .orderedAscending
        }
        let encoder = PropertyListEncoder()
        if let data = try? encoder.encode(exceptions) {
            if FileManager.default.fileExists(atPath: plistURL.path) {
                try? data.write(to: plistURL)
            } else {
                FileManager.default.createFile(atPath: plistURL.path, contents: data, attributes: nil)
            }
        }
        tableView.reloadData()
        updateRemoveButton()
        AppDelegate.current.startZeroSecondRecording()
    }
    
    // MARK: - Full Screen Toggle
    @IBAction func fullScreenToggleClicked(_ sender: Any) {
        let wantCCOnly = fullScreenAutoHideCheckbox.state == .on
        if (wantCCOnly) {
            _ = Process.runNonAdminTask(toolPath: "/usr/bin/touch", arguments: [checkboxPath])
            _ = Process.runNonAdminTask(toolPath: "/bin/chmod", arguments: ["-R", "777", injectionFolderPath])
        } else {
            _ = Process.runNonAdminTask(toolPath: "/bin/rm", arguments: [checkboxPath])
        }
        AppDelegate.current.startZeroSecondRecording()
    }
    
    func didToggleCheckbox(_ cell: AppExceptionTableCellView) {
        let row = tableView.row(for: cell)
        let exception = exceptions[row]
        exception.enabled = cell.checkbox.state == .on ? true : false
        sortPersistAndReload()
    }
    
    // MARK: - Table View
    func numberOfRows(in tableView: NSTableView) -> Int {
        return exceptions.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let view = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "AppCellID"), owner: nil) as? AppExceptionTableCellView else {
            return nil
        }
        let exception = exceptions[row]
        view.iconView.image = exception.icon
        view.label.stringValue = exception.userFacingName
        view.checkbox.state = exception.enabled ? .on : .off
        view.delegate = self
        return view
    }
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 48
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        updateRemoveButton()
    }
    
    func updateRemoveButton() {
        removeButton.isEnabled = tableView.selectedRowIndexes.count > 0
    }
    
    // MARK: - Table View Context Menu
    @objc private func tableViewShowItemInFinderClicked(_ sender: AnyObject) {
        guard tableView.clickedRow >= 0 else {
            return
        }
        let exception = exceptions[tableView.clickedRow]
        if let url = exception.urlToRevealInFinder {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }
    
    @objc private func tableViewDeleteItemClicked(_ sender: AnyObject) {
        guard tableView.clickedRow >= 0 else {
            return
        }
        exceptions.remove(at: tableView.clickedRow)
        sortPersistAndReload()
    }
    
    // MARK: - Table View Drag and Drop
    func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation
    {
        if dropOperation == .above && appPathsForInfo(info: info).count > 0 {
            return .copy
        }
        return []
    }

    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        let paths = appPathsForInfo(info: info)
        if (paths.count > 0) {
            for path in paths {
                addExceptionForPath(path: path)
            }
            sortPersistAndReload()
            return true
        }
        return false
    }

    func appPathsForInfo(info: NSDraggingInfo) -> [String] {
        guard let items = info.draggingPasteboard.pasteboardItems else {
            return []
        }
        
        var paths: [String] = []
        print("Dropped \(items)")
        for item in items {
            if let data = item.data(forType: .fileURL), let url = URL(dataRepresentation: data, relativeTo: nil) {
                print(url)
                let path = url.path
                let resourceValues = try? url.resourceValues(forKeys: [URLResourceKey.contentTypeKey])
                print("resource value = \(String(describing: resourceValues))")
                if let fileType = resourceValues?.contentType {
                    print("file type is \(fileType)")
                    if fileType.conforms(to: UTType.applicationBundle) || fileType.conforms(to: UTType.unixExecutable) {
                        paths.append(path)
                    }
                }
            }
        }
        return paths
    }
}
