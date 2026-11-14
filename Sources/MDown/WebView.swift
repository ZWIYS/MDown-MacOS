import SwiftUI
import WebKit
import UniformTypeIdentifiers

/// WKWebView, у которого щипок на трекпаде меняет размер текста (с перетеканием строк), как в режиме чтения.
final class ZoomableWebView: WKWebView {
    var onMagnify: ((CGFloat) -> Void)?
    override func magnify(with event: NSEvent) { onMagnify?(event.magnification) }

    // «Правка → Отменить / Повторить» работают с историей правок страницы
    @objc func undo(_ sender: Any?) { evaluateJavaScript("window.mdUndo&&window.mdUndo()") }
    @objc func redo(_ sender: Any?) { evaluateJavaScript("window.mdRedo&&window.mdRedo()") }
}

/// Отдаёт локальные файлы (картинки рядом с .md) по схеме mdlocal://doc/<абсолютный путь>.
final class LocalFileHandler: NSObject, WKURLSchemeHandler {
    func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
        guard let url = task.request.url else { task.didFailWithError(URLError(.badURL)); return }
        let file = URL(fileURLWithPath: url.path)
        do {
            let data = try Data(contentsOf: file)
            let mime = UTType(filenameExtension: file.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
            task.didReceive(URLResponse(url: url, mimeType: mime, expectedContentLength: data.count, textEncodingName: nil))
            task.didReceive(data)
            task.didFinish()
        } catch {
            task.didFailWithError(error)
        }
    }
    func webView(_ webView: WKWebView, stop task: WKURLSchemeTask) {}
}

struct MarkdownWebView: NSViewRepresentable {
    @ObservedObject var model: ReaderModel

    func makeCoordinator() -> Coordinator { Coordinator(model) }

    func makeNSView(context: Context) -> ZoomableWebView {
        let cfg = WKWebViewConfiguration()
        cfg.setURLSchemeHandler(LocalFileHandler(), forURLScheme: "mdlocal")
        cfg.userContentController.add(context.coordinator, name: "hl")
        cfg.userContentController.add(context.coordinator, name: "edit")
        cfg.userContentController.add(context.coordinator, name: "editOn")
        let view = ZoomableWebView(frame: .zero, configuration: cfg)
        view.navigationDelegate = context.coordinator
        context.coordinator.webView = view
        model.activeWebView = view
        view.allowsMagnification = false
        view.onMagnify = { [weak model] m in model?.zoomBy(magnification: m) }
        return view
    }

    func updateNSView(_ view: ZoomableWebView, context: Context) {
        context.coordinator.sync(view)
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let model: ReaderModel
        weak var webView: WKWebView?
        private var loadedPath = ""
        private var loadedRussian = L10n.isRussian
        private var embeddedText = ""
        private var pushedText = ""
        private var appliedEditing: String?
        private var appliedTint: Tint?
        init(_ model: ReaderModel) { self.model = model }

        func sync(_ view: WKWebView) {
            if view.pageZoom != model.zoom { view.pageZoom = model.zoom }
            guard let file = model.fileURL else { return }
            if file.path != loadedPath || loadedRussian != L10n.isRussian {
                loadedPath = file.path
                loadedRussian = L10n.isRussian
                embeddedText = model.text
                pushedText = model.text
                appliedEditing = nil
                appliedTint = model.tint
                let base = "mdlocal://doc" + file.deletingLastPathComponent().absoluteString.dropFirst("file://".count)
                view.loadHTMLString(
                    Template.html(markdown: model.text, highlights: model.highlightsJSON(for: file.path), tint: model.tint),
                    baseURL: URL(string: base))
            } else {
                if model.text != pushedText { pushedText = model.text; push(view) }
                if appliedEditing != editingKey { applyEditing(view) }
                if appliedTint != model.tint { applyTint(view) }
            }
        }

        /// Обновить текст без перезагрузки страницы (прокрутка сохраняется).
        private func push(_ view: WKWebView) {
            guard let d = try? JSONSerialization.data(withJSONObject: pushedText, options: [.fragmentsAllowed]) else { return }
            view.evaluateJavaScript("window.updateMD(\(String(decoding: d, as: UTF8.self)))")
        }

        /// В сплите правка идёт в левом редакторе, а превью остаётся «чистым».
        private var effectiveEditing: Bool { model.editing && !model.split }

        private var editingKey: String { "\(effectiveEditing)|\(model.split)" }

        private func applyEditing(_ view: WKWebView) {
            appliedEditing = editingKey
            view.evaluateJavaScript("window.setSplit(\(model.split)); window.setEditing(\(effectiveEditing))")
        }

        private func applyTint(_ view: WKWebView) {
            appliedTint = model.tint
            view.evaluateJavaScript("window.setTint('\(model.tint.lightHex)','\(model.tint.darkHex)')")
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.pageZoom = model.zoom
            if model.text != embeddedText { pushedText = model.text; push(webView) }
            applyEditing(webView)
            applyTint(webView)
        }

        func userContentController(_ c: WKUserContentController, didReceive message: WKScriptMessage) {
            switch message.name {
            case "hl":
                if let json = message.body as? String, !loadedPath.isEmpty { model.setHighlights(json, for: loadedPath) }
            case "edit":
                // правка прямо на странице: текст приходит целиком
                if let text = message.body as? String { pushedText = text; model.textEdited(text) }
            case "editOn":
                // двойной клик по тексту в красивом виде
                if !model.split { model.editing = true }
            default: break
            }
        }

        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard action.navigationType == .linkActivated, let url = action.request.url else {
                decisionHandler(.allow); return
            }
            decisionHandler(.cancel)
            if url.scheme == "mdlocal" {
                let file = URL(fileURLWithPath: url.path)
                if markdownExtensions.contains(file.pathExtension.lowercased()) { model.open(file) }
                else { NSWorkspace.shared.open(file) }
            } else {
                NSWorkspace.shared.open(url)
            }
        }
    }
}
