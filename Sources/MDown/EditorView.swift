import SwiftUI
import AppKit

/// NSTextView с меню форматирования markdown (правый клик / два пальца) и ⌘B / ⌘I.
final class FormattingTextView: NSTextView {
    /// Вызывается, если форматирование применили при выключенной правке: включаем её.
    var ensureEditing: (() -> Void)?

    private static let needsSelection: Set<String> = ["b", "i", "s", "code", "unmark"]

    // MARK: Меню

    override func menu(for event: NSEvent) -> NSMenu? {
        let base = super.menu(for: event) ?? NSMenu()
        let menu = NSMenu()

        let heading = NSMenu()
        for (key, title) in [("h0", "Обычный текст"), ("h1", "Заголовок 1"), ("h2", "Заголовок 2"), ("h3", "Заголовок 3")] {
            heading.addItem(item(title, key))
        }
        let headingItem = NSMenuItem(title: "Заголовок", action: nil, keyEquivalent: "")
        headingItem.submenu = heading
        menu.addItem(headingItem)

        menu.addItem(item("Жирный", "b", keyEquivalent: "b"))
        menu.addItem(item("Курсив", "i", keyEquivalent: "i"))
        menu.addItem(item("Зачёркнутый", "s"))
        menu.addItem(item("Код", "code"))
        menu.addItem(.separator())
        menu.addItem(item("Цитата", "quote"))
        menu.addItem(item("Маркированный список", "ul"))
        menu.addItem(.separator())

        let marks = NSMenu()
        for c in Pastel.allCases {
            let it = item(c.title, "mark:" + c.rawValue)
            it.image = Self.swatch(c.hlLight)
            marks.addItem(it)
        }
        let markItem = NSMenuItem(title: "Выделить цветом", action: nil, keyEquivalent: "")
        markItem.submenu = marks
        menu.addItem(markItem)
        menu.addItem(item("Убрать выделение", "unmark"))
        menu.addItem(.separator())

        for it in base.items { base.removeItem(it); menu.addItem(it) }   // стандартные: копировать, вставить…
        return menu
    }

    private func item(_ title: String, _ key: String, keyEquivalent: String = "") -> NSMenuItem {
        let it = NSMenuItem(title: title, action: #selector(format(_:)), keyEquivalent: "")
        it.target = self
        it.representedObject = key
        return it
    }

    private static func swatch(_ hex: String) -> NSImage {
        let img = NSImage(size: NSSize(width: 12, height: 12))
        img.lockFocus()
        Tint.color(hex).setFill()
        NSBezierPath(ovalIn: NSRect(x: 0, y: 0, width: 12, height: 12)).fill()
        NSColor.black.withAlphaComponent(0.15).setStroke()
        NSBezierPath(ovalIn: NSRect(x: 0.5, y: 0.5, width: 11, height: 11)).stroke()
        img.unlockFocus()
        return img
    }

    override func validateMenuItem(_ item: NSMenuItem) -> Bool {
        if item.action == #selector(format(_:)), let key = item.representedObject as? String {
            if Self.needsSelection.contains(key) || key.hasPrefix("mark:") { return selectedRange().length > 0 }
            return true
        }
        return super.validateMenuItem(item)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if isEditable, window?.firstResponder === self,
           event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
           let ch = event.charactersIgnoringModifiers {
            if ch == "b" { toggleInline("**"); return true }
            if ch == "i" { toggleInline("*"); return true }
        }
        return super.performKeyEquivalent(with: event)
    }

    // MARK: Действия

    @objc func format(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        if !isEditable { isEditable = true; ensureEditing?() }
        window?.makeFirstResponder(self)
        switch key {
        case "b": toggleInline("**")
        case "i": toggleInline("*")
        case "s": toggleInline("~~")
        case "code": toggleInline("`")
        case "h0", "h1", "h2", "h3": heading(Int(key.dropFirst()) ?? 0)
        case "quote": togglePrefix(isQuote: true)
        case "ul": togglePrefix(isQuote: false)
        case "unmark": unmark()
        default: if key.hasPrefix("mark:") { mark(String(key.dropFirst(5))) }
        }
    }

    private func replace(_ range: NSRange, with s: String) {
        if shouldChangeText(in: range, replacementString: s) {
            replaceCharacters(in: range, with: s)
            didChangeText()
        }
    }

    private func toggleInline(_ m: String) {
        let ns = string as NSString
        let r = selectedRange()
        let ml = (m as NSString).length
        if r.length == 0 {
            replace(r, with: m + m)
            setSelectedRange(NSRange(location: r.location + ml, length: 0))
            return
        }
        func ch(_ loc: Int) -> String { loc >= 0 && loc < ns.length ? ns.substring(with: NSRange(location: loc, length: 1)) : "" }
        func sub(_ loc: Int, _ len: Int) -> String { loc >= 0 && loc + len <= ns.length ? ns.substring(with: NSRange(location: loc, length: len)) : "" }
        let end = r.location + r.length
        var wrapped = sub(r.location - ml, ml) == m && sub(end, ml) == m
        if wrapped, m == "*", ch(r.location - 2) == "*" || ch(end + 1) == "*" { wrapped = false }   // это часть **
        let sel = ns.substring(with: r)
        if wrapped {
            replace(NSRange(location: r.location - ml, length: r.length + 2 * ml), with: sel)
            setSelectedRange(NSRange(location: r.location - ml, length: r.length))
        } else {
            replace(r, with: m + sel + m)
            setSelectedRange(NSRange(location: r.location + ml, length: r.length))
        }
    }

    private func transformLines(_ f: ([String]) -> [String]) {
        let ns = string as NSString
        let lr = ns.lineRange(for: selectedRange())
        let block = ns.substring(with: lr)
        let trailing = block.hasSuffix("\n")
        var lines = block.components(separatedBy: "\n")
        if trailing { lines.removeLast() }
        let out = f(lines).joined(separator: "\n") + (trailing ? "\n" : "")
        replace(lr, with: out)
        setSelectedRange(NSRange(location: lr.location, length: max(0, (out as NSString).length - (trailing ? 1 : 0))))
    }

    private static let stripRegex = try! NSRegularExpression(pattern: #"^\s{0,3}(#{1,6}\s+|>\s?|[-*+]\s+|\d+[.)]\s+)"#)

    private func strip(_ l: String) -> String {
        Self.stripRegex.stringByReplacingMatches(in: l, range: NSRange(l.startIndex..., in: l), withTemplate: "")
    }

    private func heading(_ level: Int) {
        transformLines { $0.map { (level > 0 ? String(repeating: "#", count: level) + " " : "") + strip($0) } }
    }

    private func togglePrefix(isQuote: Bool) {
        let marker = isQuote ? "> " : "- "
        transformLines { lines in
            let has = lines.allSatisfy { isQuote ? $0.hasPrefix(">") : ($0.hasPrefix("- ") || $0.hasPrefix("* ") || $0.hasPrefix("+ ")) }
            return lines.map { has ? (isQuote ? String($0.dropFirst($0.hasPrefix("> ") ? 2 : 1)) : String($0.dropFirst(2))) : marker + $0 }
        }
    }

    private func mark(_ color: String) {
        let r = selectedRange()
        guard r.length > 0 else { return }
        let open = "<mark data-c=\"\(color)\">"
        let sel = (string as NSString).substring(with: r)
        replace(r, with: open + sel + "</mark>")
        setSelectedRange(NSRange(location: r.location + (open as NSString).length, length: r.length))
    }

    private func unmark() {
        transformLines { lines in
            lines.map { $0.replacingOccurrences(of: #"</?mark[^>]*>"#, with: "", options: .regularExpression) }
        }
    }
}

/// Вид «Исходник»: редактор markdown на NSTextView (undo, поиск ⌘F, форматирование по правому клику).
struct EditorView: NSViewRepresentable {
    @ObservedObject var model: ReaderModel

    func makeCoordinator() -> Coordinator { Coordinator(model) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = true
        scroll.autohidesScrollers = true

        let tv = FormattingTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 400))
        tv.minSize = NSSize(width: 0, height: 0)
        tv.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.autoresizingMask = [.width]
        tv.textContainer?.widthTracksTextView = true
        tv.textContainer?.containerSize = NSSize(width: 400, height: CGFloat.greatestFiniteMagnitude)
        scroll.documentView = tv

        tv.delegate = context.coordinator
        tv.ensureEditing = { [weak model] in model?.editing = true }
        tv.isRichText = false
        tv.allowsUndo = true
        tv.usesFindBar = false
        model.activeTextView = tv
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.isAutomaticDashSubstitutionEnabled = false
        tv.isAutomaticSpellingCorrectionEnabled = false
        tv.isAutomaticTextReplacementEnabled = false
        tv.textContainerInset = NSSize(width: 28, height: 24)
        tv.textColor = .labelColor
        tv.drawsBackground = true
        tv.backgroundColor = model.tint.nsColor
        scroll.backgroundColor = model.tint.nsColor
        tv.font = .monospacedSystemFont(ofSize: 14 * model.zoom, weight: .regular)
        tv.isEditable = model.editing
        tv.isSelectable = true
        tv.string = model.text
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let tv = scroll.documentView as? FormattingTextView else { return }
        if tv.string != model.text { tv.string = model.text }
        if tv.isEditable != model.editing {
            tv.isEditable = model.editing
            if model.editing { DispatchQueue.main.async { tv.window?.makeFirstResponder(tv) } }
        }
        let size = 14 * model.zoom
        if tv.font?.pointSize != CGFloat(size) { tv.font = .monospacedSystemFont(ofSize: size, weight: .regular) }
        tv.backgroundColor = model.tint.nsColor
        scroll.backgroundColor = model.tint.nsColor
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        let model: ReaderModel
        init(_ model: ReaderModel) { self.model = model }
        func textDidChange(_ n: Notification) {
            guard let tv = n.object as? NSTextView else { return }
            model.textEdited(tv.string)
        }
    }
}
