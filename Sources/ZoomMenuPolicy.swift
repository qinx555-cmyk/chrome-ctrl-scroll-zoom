import Foundation

enum ZoomCommand {
    case zoomIn, zoomOut, reset
}

struct ZoomMenuSelection {
    let zoomIn: Int
    let zoomOut: Int
    let reset: Int?
}

/// Selects only an unambiguous pair of commands among one menu's direct children.
enum ZoomMenuPolicy {
    static func select(titles: [String], bundleIdentifier: String) -> ZoomMenuSelection? {
        var zoomInTitles: Set<String> = ["zoom in", "放大", "放大显示"]
        var zoomOutTitles: Set<String> = ["zoom out", "缩小", "缩小显示"]
        var resetTitles: Set<String> = [
            "actual size", "reset zoom", "实际大小", "重置缩放", "正常大小"
        ]

        // Doubao exposes view zoom through these font-labelled menu commands.
        // Other apps may use the same wording to change a document's formatting.
        if bundleIdentifier == "com.bot.neotix.doubao" {
            zoomInTitles.insert("放大字体")
            zoomOutTitles.insert("缩小字体")
            resetTitles.insert("默认字体")
        }

        var zoomInIndices: [Int] = []
        var zoomOutIndices: [Int] = []
        var resetIndices: [Int] = []
        for (index, title) in titles.enumerated() {
            let normalized = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if zoomInTitles.contains(normalized) { zoomInIndices.append(index) }
            if zoomOutTitles.contains(normalized) { zoomOutIndices.append(index) }
            if resetTitles.contains(normalized) { resetIndices.append(index) }
        }

        guard zoomInIndices.count == 1, zoomOutIndices.count == 1 else { return nil }
        return ZoomMenuSelection(
            zoomIn: zoomInIndices[0],
            zoomOut: zoomOutIndices[0],
            reset: resetIndices.count == 1 ? resetIndices[0] : nil
        )
    }
}
