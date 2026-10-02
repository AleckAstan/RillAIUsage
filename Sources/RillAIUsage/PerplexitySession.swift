import AppKit
import WebKit

@MainActor
final class PerplexitySession: NSObject, WKNavigationDelegate, NSWindowDelegate {
    private var webView: WKWebView?
    private var signInWindow: NSWindow?
    private var navigation: CheckedContinuation<Void, Error>?
    private var timeout: Task<Void, Never>?

    func fetch() async throws -> Data {
        let cookies = await WKWebsiteDataStore.default().httpCookieStore.allCookies()
        guard cookies.contains(where: { $0.domain.hasSuffix("perplexity.ai") && $0.name.contains("session-token") }) else {
            throw UsageError.signIn
        }
        if webView == nil {
            let configuration = WKWebViewConfiguration()
            configuration.websiteDataStore = .default()
            let view = WKWebView(frame: NSRect(x: 0, y: 0, width: 900, height: 700), configuration: configuration)
            view.navigationDelegate = self
            webView = view
        }
        guard let webView else { throw UsageError.unavailable }
        if webView.url?.host != "www.perplexity.ai" {
            try await withCheckedThrowingContinuation { continuation in
                navigation = continuation
                timeout = Task { [weak self] in
                    do { try await Task.sleep(for: .seconds(20)) } catch { return }
                    self?.finishNavigation(.failure(UsageError.unavailable))
                }
                webView.load(URLRequest(url: URL(string: "https://www.perplexity.ai")!))
            }
        }
        let value = try await webView.callAsyncJavaScript(
            """
            const response = await fetch('/rest/rate-limit/all', {credentials: 'include'});
            return JSON.stringify({status: response.status, body: await response.text()});
            """, arguments: [:], in: nil, contentWorld: .page)
        guard let text = value as? String else { throw UsageError.invalidResponse }
        struct Result: Decodable { let status: Int; let body: String }
        let result = try JSONDecoder().decode(Result.self, from: Data(text.utf8))
        if result.status == 401 || result.status == 403 { throw UsageError.signIn }
        if result.status == 429 { throw UsageError.rateLimited(300) }
        guard (200..<300).contains(result.status), result.body.utf8.count <= 1_048_576 else {
            throw UsageError.invalidResponse
        }
        return Data(result.body.utf8)
    }

    func showSignIn() {
        NSApplication.shared.setActivationPolicy(.regular)
        let webView = WKWebView(frame: .zero)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 960, height: 760),
                              styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.title = "RillAIUsage: sign in to Perplexity, then close this window"
        window.contentView = webView
        window.delegate = self
        window.isReleasedWhenClosed = false
        window.center(); window.makeKeyAndOrderFront(nil)
        webView.load(URLRequest(url: URL(string: "https://www.perplexity.ai")!))
        signInWindow = window
        NSApplication.shared.activate(ignoringOtherApps: true)
        NSApplication.shared.run()
    }

    func windowWillClose(_ notification: Notification) { NSApplication.shared.terminate(nil) }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        finishNavigation(.success(()))
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        finishNavigation(.failure(UsageError.unavailable))
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        finishNavigation(.failure(UsageError.unavailable))
    }

    private func finishNavigation(_ result: Result<Void, Error>) {
        timeout?.cancel(); timeout = nil
        let continuation = navigation; navigation = nil
        continuation?.resume(with: result)
    }
}
