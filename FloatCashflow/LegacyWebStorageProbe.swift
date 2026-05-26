import SwiftUI
import WebKit

struct LegacyWebStorageProbe: UIViewRepresentable {
    var onResult: (String?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onResult: onResult)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.setURLSchemeHandler(context.coordinator, forURLScheme: "capacitor")

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.isHidden = true
        webView.load(URLRequest(url: URL(string: "capacitor://localhost/legacy-migration.html")!))
        context.coordinator.startTimeout()
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate, WKURLSchemeHandler {
        private var onResult: ((String?) -> Void)?

        init(onResult: @escaping (String?) -> Void) {
            self.onResult = onResult
        }

        func startTimeout() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                self?.finish(nil)
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            let script = """
            (function() {
              try {
                return window.localStorage.getItem('float_budget_v1');
              } catch (error) {
                return null;
              }
            })();
            """

            webView.evaluateJavaScript(script) { [weak self] value, _ in
                self?.finish(value as? String)
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            finish(nil)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            finish(nil)
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self, weak webView] in
                guard let webView else { return }
                self?.webView(webView, didFinish: navigation)
            }
        }

        func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
            let html = """
            <!doctype html>
            <html>
              <head><meta charset="utf-8"></head>
              <body></body>
            </html>
            """
            let data = Data(html.utf8)
            let response = URLResponse(
                url: urlSchemeTask.request.url!,
                mimeType: "text/html",
                expectedContentLength: data.count,
                textEncodingName: "utf-8"
            )
            urlSchemeTask.didReceive(response)
            urlSchemeTask.didReceive(data)
            urlSchemeTask.didFinish()
        }

        func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}

        private func finish(_ value: String?) {
            guard let onResult else { return }
            self.onResult = nil
            DispatchQueue.main.async {
                onResult(value)
            }
        }
    }
}
