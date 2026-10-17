import Foundation

// Compile with Sources/ZoomMenuPolicy.swift; no UI or accessibility access needed.
private var checks = 0
private var failures = 0
private let genericBundle = "com.example.editor"
private let doubaoBundle = "com.bot.neotix.doubao"

private func expect(_ titles: [String], _ expected: (Int, Int, Int?)?, _ label: String,
                    bundleIdentifier: String = genericBundle,
                    file: StaticString = #filePath, line: UInt = #line) {
    checks += 1
    let actual = ZoomMenuPolicy.select(titles: titles, bundleIdentifier: bundleIdentifier)
    let matches: Bool
    switch (actual, expected) {
    case (nil, nil):
        matches = true
    case let (actual?, expected?):
        matches = actual.zoomIn == expected.0 && actual.zoomOut == expected.1 &&
            actual.reset == expected.2
    default:
        matches = false
    }
    guard !matches else { return }
    failures += 1
    let actualText = actual.map { "(\($0.zoomIn), \($0.zoomOut), \(String(describing: $0.reset)))" } ?? "nil"
    fputs("FAIL \(label): got \(actualText), expected \(String(describing: expected)) (\(file):\(line))\n", stderr)
}

expect(["Zoom In", "Zoom Out"], (0, 1, nil), "English pair without reset")
expect(["Find", "Zoom Out", "Actual Size", "Zoom In", "Full Screen"], (3, 1, 2),
       "indices refer to original direct children")
expect(["\n zOoM In\t", " ZOOM OUT ", " reset ZOOM\n"], (0, 1, 2),
       "English is case-insensitive and trims surrounding whitespace")
expect(["放大", "缩小", "实际大小"], (0, 1, 2), "Chinese zoom pair")
expect(["缩小显示", "正常大小", "放大显示"], (2, 0, 1), "Chinese display pair")
expect(["\t放大\n", " 缩小 ", " 重置缩放 "], (0, 1, 2), "Chinese whitespace")

for reset in ["Actual Size", "Reset Zoom", "实际大小", "重置缩放", "正常大小"] {
    expect(["Zoom In", reset, "Zoom Out"], (0, 2, 1), "recognized reset: \(reset)")
}
expect(["Zoom In", "Zoom Out", "Actual Size", "Reset Zoom"], (0, 1, nil),
       "ambiguous resets leave only reset unavailable")
expect(["Zoom In", "Zoom Out", "Reset"], (0, 1, nil), "unrelated reset is ignored")

expect([], nil, "empty menu")
expect(["Zoom In"], nil, "zoom in alone is insufficient")
expect(["Zoom Out", "Actual Size"], nil, "zoom out plus reset is insufficient")
expect(["Zoom In", "Zoom In", "Zoom Out"], nil, "duplicate zoom-in is ambiguous")
expect(["Zoom In", "Zoom Out", "zoom out"], nil, "duplicate zoom-out after normalization")
expect(["Zoom In", "放大", "Zoom Out"], nil, "synonyms cannot produce multiple zoom-in choices")
expect(["放大显示", "缩小", "缩小显示"], nil, "Chinese synonyms are ambiguous")

expect(["Zoom", "缩放", "Minimize"], nil, "window zoom is not content zoom")
expect(["Larger", "Smaller", "Actual Size"], nil, "format size commands are not generic zoom")
expect(["Make Text Bigger", "Make Text Smaller"], nil, "font commands are not inferred")
expect(["Zoom In…", "Zoom Out…"], nil, "ellipsis is not silently stripped")
expect(["Zoom In (100%)", "Zoom Out (100%)"], nil, "substring matches are not accepted")
expect(["Zoom  In", "Zoom Out"], nil, "internal whitespace is not rewritten")
expect(["View > Zoom In", "View > Zoom Out"], nil, "menu paths are not direct command titles")
expect(["放大图片", "缩小图片"], nil, "Chinese suffixes are not inferred")
expect(["Zoom In", "Out"], nil, "partial direction names are rejected")

expect(["放大字体", "缩小字体", "默认字体"], (0, 1, 2), "Doubao view zoom exception",
       bundleIdentifier: doubaoBundle)
expect(["缩小字体", "放大字体"], (1, 0, nil), "Doubao reset is optional",
       bundleIdentifier: doubaoBundle)
expect(["放大字体", "缩小字体", "默认字体"], nil, "font exception is not global")
expect(["放大字体", "缩小字体"], nil, "similar bundle identifier is insufficient",
       bundleIdentifier: "com.bot.neotix.doubao.beta")
expect(["放大字体", "缩小字体"], nil, "bundle identifier is exact",
       bundleIdentifier: "COM.BOT.NEOTIX.DOUBAO")
expect(["Zoom In", "Zoom Out", "默认字体"], (0, 1, nil), "Doubao-only reset is not global")
expect(["Zoom In", "Zoom Out", "默认字体"], (0, 1, 2), "Doubao also supports generic pair",
       bundleIdentifier: doubaoBundle)
expect(["放大字体", "放大", "缩小字体"], nil, "Doubao direction ambiguity is rejected",
       bundleIdentifier: doubaoBundle)
expect(["放大字体", "Actual Size"], nil, "Doubao still requires both directions",
       bundleIdentifier: doubaoBundle)

if failures > 0 {
    fputs("\(failures) of \(checks) checks failed.\n", stderr)
    exit(1)
}
print("PASS: \(checks) zoom menu policy behavior checks")
