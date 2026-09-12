import SwiftUI
import WebKit
import AppKit

public struct AnimatedFaceIDGIFView: View {
    public var size: CGFloat
    public var glowColor: Color

    public init(size: CGFloat = 110, glowColor: Color = Color.green) {
        self.size = size
        self.glowColor = glowColor
    }

    public var body: some View {
        ZStack {
            // Ambient soft glow behind animation
            Circle()
                .fill(
                    RadialGradient(
                        colors: [glowColor.opacity(0.22), Color.clear],
                        center: .center,
                        startRadius: 10,
                        endRadius: size * 0.75
                    )
                )
                .frame(width: size * 1.5, height: size * 1.5)

            // Transparent animated GIF webview player
            FaceIDGIFWebView()
                .frame(width: size, height: size * (126.0 / 150.0))
        }
    }
}

// MARK: - Native WebKit Transparent GIF Engine
struct FaceIDGIFWebView: NSViewRepresentable {
    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        webView.underPageBackgroundColor = .clear

        loadGIF(into: webView)
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        // Continuous playback handled by WebKit
    }

    private func loadGIF(into webView: WKWebView) {
        // Attempt locating the GIF file in various bundle / directory locations
        var gifData: Data? = nil

        let searchURLs = [
            Bundle.module.url(forResource: "Apple Face ID", withExtension: "gif"),
            Bundle.main.url(forResource: "Apple Face ID", withExtension: "gif"),
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("Sources/FaceIDMac/Resources/Apple Face ID.gif"),
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("Apple Face ID.gif")
        ]

        for url in searchURLs.compactMap({ $0 }) {
            if let data = try? Data(contentsOf: url), !data.isEmpty {
                gifData = data
                break
            }
        }

        if let data = gifData {
            let base64 = data.base64EncodedString()
            let html = """
            <!DOCTYPE html>
            <html>
            <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                * { margin: 0; padding: 0; box-sizing: border-box; }
                html, body {
                    background: transparent;
                    width: 100%;
                    height: 100%;
                    overflow: hidden;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                }
                img {
                    width: 100%;
                    height: 100%;
                    object-fit: contain;
                    display: block;
                    filter: drop-shadow(0 4px 12px rgba(48, 209, 88, 0.25));
                }
            </style>
            </head>
            <body>
                <img src="data:image/gif;base64,\(base64)" alt="Face ID" />
            </body>
            </html>
            """
            webView.loadHTMLString(html, baseURL: nil)
        }
    }
}
