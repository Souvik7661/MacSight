import SwiftUI
import AppKit
import ImageIO

public struct AnimatedFaceIDGIFView: View {
    public var size: CGFloat
    public var glowColor: Color
    public var isMatched: Bool

    public init(size: CGFloat = 44, glowColor: Color = Color(red: 0.19, green: 0.82, blue: 0.35), isMatched: Bool = false) {
        self.size = size
        self.glowColor = glowColor
        self.isMatched = isMatched
    }

    public var body: some View {
        ZStack {
            // Subtle ambient glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            (isMatched ? glowColor : Color.white).opacity(isMatched ? 0.35 : 0.08),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: size * 0.2,
                        endRadius: size * 0.75
                    )
                )
                .frame(width: size * 1.4, height: size * 1.4)

            // Native AppKit Face ID GIF View: Still on wrong/detecting, animated on match
            FaceIDNativeGIFRepresentable(size: size, isMatched: isMatched)
                .frame(width: size, height: size * (126.0 / 150.0))
        }
    }
}

// MARK: - Native AppKit Representable
struct FaceIDNativeGIFRepresentable: NSViewRepresentable {
    var size: CGFloat
    var isMatched: Bool

    func makeNSView(context: Context) -> FaceIDNativeGIFNSView {
        let view = FaceIDNativeGIFNSView(frame: NSRect(x: 0, y: 0, width: size, height: size * (126.0 / 150.0)))
        view.setMatched(isMatched)
        return view
    }

    func updateNSView(_ nsView: FaceIDNativeGIFNSView, context: Context) {
        nsView.setMatched(isMatched)
    }
}

// MARK: - Native AppKit View with Static & Animated Modes
final class FaceIDNativeGIFNSView: NSView {
    private let imageView = NSImageView()
    private var isPlaying: Bool = false
    private var gifData: Data?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.autoresizingMask = [.width, .height]
        imageView.frame = bounds
        addSubview(imageView)
        loadData()
        updateDisplay(matched: false)
    }

    func setMatched(_ matched: Bool) {
        if matched != isPlaying {
            isPlaying = matched
            updateDisplay(matched: matched)
        }
    }

    private func updateDisplay(matched: Bool) {
        guard let data = gifData ?? loadData() else { return }

        if matched {
            // MATCHED: Play authentic Apple Face ID animation GIF!
            if let animatedImg = NSImage(data: data) {
                imageView.image = animatedImg
                imageView.animates = true
            }
        } else {
            // STILL / WRONG FACE: Keep animation still, NO change!
            if let source = CGImageSourceCreateWithData(data as CFData, nil),
               let cg = CGImageSourceCreateImageAtIndex(source, 0, nil) {
                let stillImg = NSImage(cgImage: cg, size: NSSize(width: 150, height: 126))
                imageView.image = stillImg
                imageView.animates = false
            }
        }
    }

    @discardableResult
    private func loadData() -> Data? {
        if let d = gifData { return d }

        let searchURLs: [URL?] = [
            Bundle.main.url(forResource: "Apple Face ID", withExtension: "gif"),
            Bundle.module.url(forResource: "Apple Face ID", withExtension: "gif"),
            Bundle.main.resourceURL?.appendingPathComponent("Apple Face ID.gif"),
            Bundle.main.resourceURL?.appendingPathComponent("FaceIDMac_FaceIDMac.bundle/Apple Face ID.gif"),
            URL(fileURLWithPath: "/Users/souvikkundu/Applications/FaceIDMac.app/Contents/Resources/Apple Face ID.gif"),
            URL(fileURLWithPath: "/Users/souvikkundu/Desktop/FaceId/Apple Face ID.gif"),
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("Apple Face ID.gif")
        ]

        for url in searchURLs.compactMap({ $0 }) {
            if let d = try? Data(contentsOf: url), !d.isEmpty {
                self.gifData = d
                return d
            }
        }
        return nil
    }
}
