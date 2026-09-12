import SwiftUI
import WebKit

public enum FaceIDVisualState: String, CaseIterable {
    case idle = "idle"
    case searching = "searching"
    case scanning = "scanning"
    case success = "success"
    case failure = "failure"
    case playFull = "play_full"
}

public struct FaceIDLottieView: NSViewRepresentable {
    @Binding public var state: FaceIDVisualState
    public var onReady: (() -> Void)?
    public var onComplete: ((FaceIDVisualState) -> Void)?

    public init(
        state: Binding<FaceIDVisualState>,
        onReady: (() -> Void)? = nil,
        onComplete: ((FaceIDVisualState) -> Void)? = nil
    ) {
        self._state = state
        self.onReady = onReady
        self.onComplete = onComplete
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "faceIDBridge")
        configuration.userContentController = contentController

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.setValue(false, forKey: "drawsBackground")
        webView.underPageBackgroundColor = .clear
        context.coordinator.webView = webView

        loadPlayer(into: webView)
        return webView
    }

    public func updateNSView(_ nsView: WKWebView, context: Context) {
        context.coordinator.parent = self
        if context.coordinator.lastState != state {
            context.coordinator.lastState = state
            nsView.evaluateJavaScript("setVisualState('\(state.rawValue)')", completionHandler: nil)
        }
    }

    private func loadPlayer(into webView: WKWebView) {
        if let htmlURL = Bundle.module.url(forResource: "player", withExtension: "html", subdirectory: nil) ??
                         Bundle.main.url(forResource: "player", withExtension: "html") {
            let directory = htmlURL.deletingLastPathComponent()
            webView.loadFileURL(htmlURL, allowingReadAccessTo: directory)
        } else if let resourcePath = Bundle.main.resourcePath {
            let directURL = URL(fileURLWithPath: resourcePath).appendingPathComponent("player.html")
            webView.loadFileURL(directURL, allowingReadAccessTo: directURL.deletingLastPathComponent())
        }
    }

    public class Coordinator: NSObject, WKScriptMessageHandler {
        var parent: FaceIDLottieView
        weak var webView: WKWebView?
        var lastState: FaceIDVisualState?
        var isReady = false

        init(_ parent: FaceIDLottieView) {
            self.parent = parent
        }

        public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let dict = message.body as? [String: Any],
                  let event = dict["event"] as? String else { return }

            DispatchQueue.main.async {
                switch event {
                case "ready":
                    self.isReady = true
                    self.parent.onReady?()
                    self.webView?.evaluateJavaScript("setVisualState('\(self.parent.state.rawValue)')", completionHandler: nil)
                case "complete":
                    if let stateStr = dict["state"] as? String,
                       let state = FaceIDVisualState(rawValue: stateStr) {
                        self.parent.onComplete?(state)
                    }
                default:
                    break
                }
            }
        }
    }
}
