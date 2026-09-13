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
                .frame(width: size * 1.3, height: size * 1.3)

            // Native AppKit Face ID GIF View: Still on wrong/detecting, animated on match
            FaceIDNativeGIFRepresentable(size: size, isMatched: isMatched)
                .frame(width: size, height: size)
        }
    }
}

// MARK: - Native AppKit Representable
struct FaceIDNativeGIFRepresentable: NSViewRepresentable {
    var size: CGFloat
    var isMatched: Bool

    func makeNSView(context: Context) -> FaceIDNativeGIFNSView {
        let view = FaceIDNativeGIFNSView(frame: NSRect(x: 0, y: 0, width: size, height: size))
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
    private var matchData: Data?
    private var stillData: Data?

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
        loadData()

        if matched {
            // MATCHED: Play authentic Apple Face ID animation GIF confirming match!
            if let data = matchData, let animatedImg = NSImage(data: data) {
                imageView.image = animatedImg
                imageView.animates = true
            }
        } else {
            // STILL / WRONG FACE: Keep animation still, NO change!
            if let data = stillData, let stillImg = NSImage(data: data) {
                imageView.image = stillImg
                imageView.animates = false
            } else if let data = matchData,
                      let source = CGImageSourceCreateWithData(data as CFData, nil),
                      let cg = CGImageSourceCreateImageAtIndex(source, 0, nil) {
                let stillImg = NSImage(cgImage: cg, size: NSSize(width: bounds.width, height: bounds.height))
                imageView.image = stillImg
                imageView.animates = false
            }
        }
    }

    private func loadData() {
        if stillData == nil {
            let stillURLs: [URL?] = [
                Bundle.main.url(forResource: "faceid_squircle_still", withExtension: "png"),
                Bundle.module.url(forResource: "faceid_squircle_still", withExtension: "png"),
                Bundle.main.resourceURL?.appendingPathComponent("faceid_squircle_still.png"),
                Bundle.main.resourceURL?.appendingPathComponent("FaceIDMac_FaceIDMac.bundle/faceid_squircle_still.png"),
                URL(fileURLWithPath: "/Users/souvikkundu/Applications/FaceIDMac.app/Contents/Resources/faceid_squircle_still.png"),
                URL(fileURLWithPath: "/Users/souvikkundu/Desktop/FaceId/Sources/FaceIDMac/Resources/faceid_squircle_still.png")
            ]
            for url in stillURLs.compactMap({ $0 }) {
                if let d = try? Data(contentsOf: url), !d.isEmpty {
                    self.stillData = d
                    break
                }
            }
        }

        if matchData == nil {
            let matchURLs: [URL?] = [
                Bundle.main.url(forResource: "faceid_squircle_match", withExtension: "gif"),
                Bundle.module.url(forResource: "faceid_squircle_match", withExtension: "gif"),
                Bundle.main.resourceURL?.appendingPathComponent("faceid_squircle_match.gif"),
                Bundle.main.resourceURL?.appendingPathComponent("FaceIDMac_FaceIDMac.bundle/faceid_squircle_match.gif"),
                URL(fileURLWithPath: "/Users/souvikkundu/Applications/FaceIDMac.app/Contents/Resources/faceid_squircle_match.gif"),
                URL(fileURLWithPath: "/Users/souvikkundu/Desktop/FaceId/Sources/FaceIDMac/Resources/faceid_squircle_match.gif"),
                Bundle.main.url(forResource: "Apple Face ID", withExtension: "gif"),
                URL(fileURLWithPath: "/Users/souvikkundu/Desktop/FaceId/Apple Face ID.gif")
            ]
            for url in matchURLs.compactMap({ $0 }) {
                if let d = try? Data(contentsOf: url), !d.isEmpty {
                    self.matchData = d
                    break
                }
            }
        }
    }
}
