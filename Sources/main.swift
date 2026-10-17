import AppKit
import ApplicationServices

private let appID = "com.qinxin.chrome-ctrl-scroll-zoom"

final class ZoomApp: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var statusLine: NSMenuItem!
    private var enabledItem: NSMenuItem!
    private var reverseItem: NSMenuItem!
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var timer: Timer?
    private var welcome: NSWindow?
    private var welcomeStatus: NSTextField?
    private var activationObserver: NSObjectProtocol?
    private var chromePID: pid_t?
    private var quantizer = ScrollQuantizer()
    private var enabled = true
    private var reversed = UserDefaults.standard.bool(forKey: "reverseDirection")
    private var failedToCreateTap = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        if NSRunningApplication.runningApplications(withBundleIdentifier: appID).count > 1 {
            NSApp.terminate(nil)
            return
        }
        NSApp.setActivationPolicy(.accessory)
        buildMenu()
        updateFrontmostApp()
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil,
            queue: .main
        ) { [weak self] _ in self?.updateFrontmostApp() }
        refreshPermission()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) {
            [weak self] _ in self?.refreshPermission()
        }
        if !AXIsProcessTrusted() { showWelcome(nil) }
    }

    private func updateFrontmostApp() {
        let app = NSWorkspace.shared.frontmostApplication
        chromePID = app?.bundleIdentifier == "com.google.Chrome" ? app?.processIdentifier : nil
        quantizer.reset()
    }

    private func buildMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "⌃↕"
        statusItem.button?.toolTip = "Chrome 滚轮缩放：Control + 滚轮"
        let menu = NSMenu()
        statusLine = NSMenuItem(title: "正在检查权限…", action: nil, keyEquivalent: "")
        menu.addItem(statusLine)
        menu.addItem(.separator())
        enabledItem = item("启用 Ctrl + 滚轮缩放", #selector(toggleEnabled))
        enabledItem.state = .on
        menu.addItem(enabledItem)
        reverseItem = item("反转缩放方向", #selector(toggleReverse))
        reverseItem.state = reversed ? .on : .off
        menu.addItem(reverseItem)
        menu.addItem(.separator())
        menu.addItem(item("使用说明与权限…", #selector(showWelcome(_:))))
        menu.addItem(item("打开辅助功能设置…", #selector(openPermissions)))
        menu.addItem(.separator())
        menu.addItem(item("退出 Chrome 滚轮缩放", #selector(quit)))
        statusItem.menu = menu
    }

    private func item(_ title: String, _ selector: Selector) -> NSMenuItem {
        let result = NSMenuItem(title: title, action: selector, keyEquivalent: "")
        result.target = self
        return result
    }

    private func refreshPermission() {
        let trusted = AXIsProcessTrusted()
        if trusted && enabled && tap == nil { startTap() }
        if (!trusted || !enabled) && tap != nil { stopTap() }
        let text: String
        if !trusted { text = "等待开启辅助功能权限" }
        else if !enabled { text = "已暂停" }
        else if tap != nil { text = "已启用 · 仅在 Chrome 中生效" }
        else { text = "监听未启动，请退出后重新打开" }
        statusLine.title = text
        welcomeStatus?.stringValue = text
        statusItem.button?.appearsDisabled = !trusted || !enabled || tap == nil
    }

    private func startTap() {
        guard !failedToCreateTap else { return }
        let mask = CGEventMask(1) << CGEventType.scrollWheel.rawValue
        tap = CGEvent.tapCreate(
            tap: .cgAnnotatedSessionEventTap, place: .headInsertEventTap,
            options: .defaultTap, eventsOfInterest: mask,
            callback: { _, type, event, context in
                guard let context else { return Unmanaged.passUnretained(event) }
                let app = Unmanaged<ZoomApp>.fromOpaque(context).takeUnretainedValue()
                return app.handle(type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )
        guard let tap else { failedToCreateTap = true; return }
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func stopTap() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        source = nil
        tap = nil
        quantizer.reset()
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap, enabled, AXIsProcessTrusted() { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        let flags = event.flags
        guard enabled, let pid = chromePID, flags.contains(.maskControl),
              !flags.contains(.maskCommand), !flags.contains(.maskAlternate),
              !flags.contains(.maskShift) else {
            quantizer.reset()
            return Unmanaged.passUnretained(event)
        }
        let targetPID = pid_t(event.getIntegerValueField(.eventTargetUnixProcessID))
        guard targetPID == 0 || targetPID == pid else {
            quantizer.reset()
            return Unmanaged.passUnretained(event)
        }
        let continuous = event.getIntegerValueField(.scrollWheelEventIsContinuous) != 0
        var delta = event.getDoubleValueField(continuous ? .scrollWheelEventPointDeltaAxis1 : .scrollWheelEventDeltaAxis1)
        let native = NSEvent(cgEvent: event)
        if let phase = native?.phase, !phase.intersection([.began, .ended, .cancelled]).isEmpty {
            quantizer.reset()
        }
        // A horizontal-only gesture remains ordinary horizontal scrolling.
        guard delta != 0 else { return Unmanaged.passUnretained(event) }
        // Do not keep zooming from trackpad inertia after the fingers lift.
        if event.getIntegerValueField(.scrollWheelEventMomentumPhase) != 0 {
            quantizer.reset()
            return nil
        }
        if native?.isDirectionInvertedFromDevice == true { delta = -delta }
        if reversed { delta = -delta }
        let steps = quantizer.steps(delta: delta, continuous: continuous,
            time: Double(event.timestamp) / 1_000_000_000,
            gestureStart: native?.phase.contains(.began) == true)
        if steps != 0 { postZoom(steps: steps, pid: pid) }
        return nil
    }

    private func postZoom(steps: Int, pid: pid_t) {
        // Cmd+= / Cmd+- invokes Chrome's own zoom, including its PDF viewer.
        // Post only to the Chrome PID captured for this scroll event.
        let key = CGKeyCode(steps > 0 ? 24 : 27)
        let eventSource = CGEventSource(stateID: .privateState)
        for _ in 0..<abs(steps) {
            guard let down = CGEvent(keyboardEventSource: eventSource, virtualKey: key, keyDown: true),
                  let up = CGEvent(keyboardEventSource: eventSource, virtualKey: key, keyDown: false)
            else { return }
            for event in [down, up] {
                event.flags = .maskCommand
                event.setIntegerValueField(.eventSourceUserData, value: 0x43535A)
                event.postToPid(pid)
            }
        }
    }

    @objc private func toggleEnabled() {
        enabled.toggle()
        enabledItem.state = enabled ? .on : .off
        failedToCreateTap = false
        refreshPermission()
    }

    @objc private func toggleReverse() {
        reversed.toggle()
        reverseItem.state = reversed ? .on : .off
        UserDefaults.standard.set(reversed, forKey: "reverseDirection")
        quantizer.reset()
    }

    @objc private func openPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    @objc private func showWelcome(_ sender: Any?) {
        if let welcome { welcome.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true); return }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 500, height: 360),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Chrome 滚轮缩放"
        window.isReleasedWhenClosed = false
        let view = window.contentView!
        let title = NSTextField(labelWithString: "像在 Windows 上一样缩放 Chrome")
        title.font = .boldSystemFont(ofSize: 20)
        title.frame = NSRect(x: 28, y: 302, width: 450, height: 28)
        view.addSubview(title)
        let details = NSTextField(wrappingLabelWithString:
            "按住 Control（⌃）向上滚动放大，向下滚动缩小。\n使用 Chrome 原生缩放；⌘0 恢复默认比例。\n\n只在 Chrome 位于前台时生效，松开 Control 后正常滚动。\n触控板双指捏合保持原有行为。\n\n首次使用：在辅助功能设置中启用“Chrome 滚轮缩放”。\n此工具只处理滚轮，不记录键盘或网页内容，也不联网。")
        details.font = .systemFont(ofSize: 14)
        details.frame = NSRect(x: 28, y: 99, width: 444, height: 192)
        view.addSubview(details)
        let status = NSTextField(labelWithString: statusLine.title)
        status.textColor = .secondaryLabelColor
        status.frame = NSRect(x: 28, y: 64, width: 444, height: 22)
        view.addSubview(status)
        welcomeStatus = status
        let button = NSButton(title: "打开辅助功能设置", target: self, action: #selector(openPermissions))
        button.bezelStyle = .rounded
        button.frame = NSRect(x: 26, y: 20, width: 190, height: 32)
        view.addSubview(button)
        let close = NSButton(title: "完成", target: window, action: #selector(NSWindow.performClose(_:)))
        close.bezelStyle = .rounded
        close.frame = NSRect(x: 374, y: 20, width: 100, height: 32)
        view.addSubview(close)
        welcome = window
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quit() { NSApp.terminate(nil) }

    func applicationWillTerminate(_ notification: Notification) {
        stopTap()
        timer?.invalidate()
        if let activationObserver { NSWorkspace.shared.notificationCenter.removeObserver(activationObserver) }
    }
}

let app = NSApplication.shared
let delegate = ZoomApp()
app.delegate = delegate
app.run()
