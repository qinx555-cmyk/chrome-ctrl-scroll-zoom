import AppKit
import ApplicationServices

private func axValue(_ element: AXUIElement, _ attribute: CFString) -> CFTypeRef? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else { return nil }
    return value
}

private func axEnabled(_ element: AXUIElement) -> Bool {
    (axValue(element, kAXEnabledAttribute as CFString) as? Bool) == true
}

private func axPressSupported(_ element: AXUIElement) -> Bool {
    var actions: CFArray?
    guard AXUIElementCopyActionNames(element, &actions) == .success else { return false }
    return (actions as? [String])?.contains(kAXPressAction as String) == true
}

struct NativeZoomAction {
    let element: AXUIElement
    let enabled: Bool
}

struct NativeZoomTarget {
    let pid: pid_t
    let zoomIn: NativeZoomAction
    let zoomOut: NativeZoomAction
    let reset: NativeZoomAction?

    private func action(_ command: ZoomCommand) -> NativeZoomAction? {
        switch command {
        case .zoomIn: return zoomIn
        case .zoomOut: return zoomOut
        case .reset: return reset
        }
    }

    func supports(_ command: ZoomCommand) -> Bool { action(command)?.enabled == true }

    /// Call on the AX worker, never from the event tap. No keyboard retry on failure.
    func perform(_ command: ZoomCommand, ifCurrent: () -> Bool) -> Bool {
        guard let action = action(command) else { return false }
        var owner: pid_t = 0
        guard AXUIElementGetPid(action.element, &owner) == .success, owner == pid,
              axEnabled(action.element), axPressSupported(action.element) else { return false }
        guard ifCurrent() else { return false }
        return AXUIElementPerformAction(action.element, kAXPressAction as CFString) == .success
    }
}

enum NativeZoomMenus {
    /// Only visits the native menu bar; never reads document or web page contents.
    static func discover(pid: pid_t, bundleIdentifier: String) -> NativeZoomTarget? {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.12)
        guard let value = axValue(app, kAXMenuBarAttribute as CFString),
              CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        let menuBar = value as! AXUIElement
        let deadline = ProcessInfo.processInfo.systemUptime + 0.8
        var visited = 0

        func visit(_ element: AXUIElement, depth: Int) -> NativeZoomTarget? {
            guard depth <= 7, visited < 600,
                  ProcessInfo.processInfo.systemUptime < deadline else { return nil }
            visited += 1
            guard let children = axValue(element, kAXChildrenAttribute as CFString) as? [AXUIElement],
                  !children.isEmpty else { return nil }
            var titles: [String] = []
            for child in children {
                guard ProcessInfo.processInfo.systemUptime < deadline else { return nil }
                titles.append(axValue(child, kAXTitleAttribute as CFString) as? String ?? "")
            }
            if let selection = ZoomMenuPolicy.select(titles: titles, bundleIdentifier: bundleIdentifier) {
                let up = children[selection.zoomIn]
                let down = children[selection.zoomOut]
                if axPressSupported(up), axPressSupported(down) {
                    let reset = selection.reset.flatMap { index -> NativeZoomAction? in
                        let item = children[index]
                        return axPressSupported(item) ? NativeZoomAction(element: item, enabled: axEnabled(item)) : nil
                    }
                    return NativeZoomTarget(pid: pid,
                        zoomIn: NativeZoomAction(element: up, enabled: axEnabled(up)),
                        zoomOut: NativeZoomAction(element: down, enabled: axEnabled(down)), reset: reset)
                }
            }
            // Reach View / Appearance before large File or Edit menus.
            let preferred: Set<String> = ["view", "appearance", "显示", "查看", "视图", "外观"]
            let order = children.indices.sorted {
                let left = preferred.contains(titles[$0].lowercased())
                let right = preferred.contains(titles[$1].lowercased())
                return left == right ? $0 < $1 : left
            }
            for index in order {
                if let target = visit(children[index], depth: depth + 1) { return target }
            }
            return nil
        }
        return visit(menuBar, depth: 0)
    }
}
