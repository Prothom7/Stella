import SwiftUI
import RealityKit
import ARKit
import PhotosUI
import CoreImage

struct ConstellationFinderView: View {
    @State private var selectedConstellation: ConstellationGuide = .orion
    @State private var overlayScale: CGFloat = 1.0
    @State private var overlayRotation: Double = 0
    @State private var detectionStatus = "Point at the sky and tap Analyze Live Sky."
    @State private var isAnalyzing = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var snapshotRequestID = 0

    var body: some View {
        ZStack {
            ConstellationCameraARView(snapshotRequestID: $snapshotRequestID) { image in
                runDetection(on: image)
            }
                .ignoresSafeArea()

            VStack(spacing: 14) {
                titlePanel

                constellationPicker

                actionPanel

                Spacer()

                overlayPanel
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)

            ConstellationShape(points: selectedConstellation.normalizedPoints)
                .stroke(
                    LinearGradient(
                        colors: [Color.cyan.opacity(0.95), Color.white.opacity(0.95)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round)
                )
                .frame(width: 190, height: 190)
                .scaleEffect(overlayScale)
                .rotationEffect(.degrees(overlayRotation))
                .shadow(color: .cyan.opacity(0.32), radius: 16, x: 0, y: 0)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.35), lineWidth: 1)
                        .frame(width: 14, height: 14)
                )
                .allowsHitTesting(false)

            reticle
        }
        .navigationTitle("Constellation Finder")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selectedPhotoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        runDetection(on: image)
                    }
                }
            }
        }
    }

    private var titlePanel: some View {
        VStack(spacing: 6) {
            Text("Constellation Finder")
                .font(.system(size: 27, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("Point your phone at the sky and align the glowing shape with stars.")
                .font(.system(size: 13, weight: .medium, design: .default))
                .foregroundStyle(.white.opacity(0.88))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.46))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.2), lineWidth: 1)
        )
    }

    private var constellationPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ConstellationGuide.allCases) { constellation in
                    Button {
                        selectedConstellation = constellation
                    } label: {
                        Text(constellation.name)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(
                                        selectedConstellation == constellation
                                        ? Color.white.opacity(0.24)
                                        : Color.white.opacity(0.11)
                                    )
                            )
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(.white.opacity(selectedConstellation == constellation ? 0.42 : 0.2), lineWidth: 1)
                            )
                    }
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.44))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white.opacity(0.2), lineWidth: 1)
        )
    }

    private var actionPanel: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Button {
                    guard !isAnalyzing else { return }
                    isAnalyzing = true
                    detectionStatus = "Analyzing live sky..."
                    snapshotRequestID += 1
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "camera.viewfinder")
                        Text("Analyze Live Sky")
                    }
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(Color.white.opacity(0.2), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .disabled(isAnalyzing)

                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    HStack(spacing: 6) {
                        Image(systemName: "photo")
                        Text("Analyze Image")
                    }
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(Color.white.opacity(0.2), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }

            HStack(spacing: 7) {
                if isAnalyzing {
                    ProgressView()
                        .tint(.white)
                }
                Text(detectionStatus)
                    .font(.system(size: 12, weight: .medium, design: .default))
                    .foregroundStyle(.white.opacity(0.88))
                    .multilineTextAlignment(.leading)
                Spacer()
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.44))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white.opacity(0.2), lineWidth: 1)
        )
    }

    private var overlayPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Overlay Controls")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 6) {
                Text("Scale")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                Slider(value: $overlayScale, in: 0.7...1.5)
                    .tint(.white)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Rotation")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                Slider(value: $overlayRotation, in: -180...180)
                    .tint(.white)
            }

            Text("Tip: Start with Orion for easier star matching.")
                .font(.system(size: 12, weight: .medium, design: .default))
                .foregroundStyle(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.46))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white.opacity(0.2), lineWidth: 1)
        )
    }

    private func runDetection(on image: UIImage) {
        let detector = ConstellationDetector()

        DispatchQueue.global(qos: .userInitiated).async {
            let result = detector.detectConstellation(in: image)

            DispatchQueue.main.async {
                isAnalyzing = false

                guard let result else {
                    detectionStatus = "No clear constellation found. Try a darker sky image with brighter stars."
                    return
                }

                selectedConstellation = result.constellation
                overlayRotation = result.rotationDegrees
                overlayScale = max(0.7, min(result.scale, 1.5))

                let confidencePercent = Int(result.confidence * 100)
                detectionStatus = "Identified \(result.constellation.name) with \(confidencePercent)% confidence."
            }
        }
    }

    private var reticle: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.42), lineWidth: 1.2)
                .frame(width: 120, height: 120)
            Rectangle()
                .fill(Color.white.opacity(0.38))
                .frame(width: 2, height: 22)
            Rectangle()
                .fill(Color.white.opacity(0.38))
                .frame(width: 22, height: 2)
        }
        .allowsHitTesting(false)
    }
}

private struct ConstellationCameraARView: UIViewRepresentable {
    @Binding var snapshotRequestID: Int
    let onSnapshot: (UIImage) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onSnapshot: onSnapshot)
    }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        arView.renderOptions.insert(.disableMotionBlur)
        arView.environment.background = .cameraFeed()

        let configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = .gravity
        arView.session.run(configuration)

        context.coordinator.arView = arView

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        if context.coordinator.lastSnapshotRequestID != snapshotRequestID {
            context.coordinator.lastSnapshotRequestID = snapshotRequestID
            context.coordinator.captureSnapshot()
        }
    }

    final class Coordinator {
        weak var arView: ARView?
        var lastSnapshotRequestID: Int = 0
        private let onSnapshot: (UIImage) -> Void

        init(onSnapshot: @escaping (UIImage) -> Void) {
            self.onSnapshot = onSnapshot
        }

        func captureSnapshot() {
            arView?.snapshot(saveToHDR: false) { image in
                guard let image else { return }
                self.onSnapshot(image)
            }
        }
    }
}

private struct ConstellationShape: Shape {
    let points: [CGPoint]

    func path(in rect: CGRect) -> Path {
        guard let first = points.first else { return Path() }

        var path = Path()
        path.move(to: CGPoint(x: first.x * rect.width, y: first.y * rect.height))

        for point in points.dropFirst() {
            path.addLine(to: CGPoint(x: point.x * rect.width, y: point.y * rect.height))
        }

        return path
    }
}

private struct ConstellationDetectionResult {
    let constellation: ConstellationGuide
    let confidence: Double
    let scale: CGFloat
    let rotationDegrees: Double
}

private final class ConstellationDetector {
    private let targetSize = CGSize(width: 320, height: 320)

    func detectConstellation(in image: UIImage) -> ConstellationDetectionResult? {
        guard let resized = resize(image: image, to: targetSize),
              let stars = detectBrightStars(in: resized),
              stars.count >= 5 else {
            return nil
        }

        var bestResult: ConstellationDetectionResult?

        for constellation in ConstellationGuide.allCases {
            if let match = bestMatch(for: constellation.normalizedPoints, in: stars) {
                if bestResult == nil || match.confidence > (bestResult?.confidence ?? 0) {
                    bestResult = ConstellationDetectionResult(
                        constellation: constellation,
                        confidence: match.confidence,
                        scale: match.scale,
                        rotationDegrees: match.rotationDegrees
                    )
                }
            }
        }

        guard let result = bestResult, result.confidence > 0.45 else {
            return nil
        }

        return result
    }

    private func resize(image: UIImage, to size: CGSize) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    private func detectBrightStars(in image: UIImage) -> [CGPoint]? {
        guard let cgImage = image.cgImage else { return nil }

        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let bitsPerComponent = 8

        var raw = [UInt8](repeating: 0, count: width * height * bytesPerPixel)

        guard let context = CGContext(
            data: &raw,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        struct Candidate {
            let point: CGPoint
            let brightness: Double
        }

        var candidates: [Candidate] = []
        candidates.reserveCapacity(1000)

        for y in stride(from: 0, to: height, by: 2) {
            for x in stride(from: 0, to: width, by: 2) {
                let i = (y * width + x) * bytesPerPixel
                let r = Double(raw[i])
                let g = Double(raw[i + 1])
                let b = Double(raw[i + 2])
                let brightness = (0.299 * r) + (0.587 * g) + (0.114 * b)

                if brightness > 222 {
                    let px = CGFloat(x) / CGFloat(width)
                    let py = CGFloat(y) / CGFloat(height)
                    candidates.append(Candidate(point: CGPoint(x: px, y: py), brightness: brightness))
                }
            }
        }

        if candidates.isEmpty {
            return nil
        }

        candidates.sort { $0.brightness > $1.brightness }

        var selected: [CGPoint] = []
        let minDistance: CGFloat = 0.04

        for candidate in candidates {
            let tooClose = selected.contains { existing in
                hypot(existing.x - candidate.point.x, existing.y - candidate.point.y) < minDistance
            }

            if !tooClose {
                selected.append(candidate.point)
            }

            if selected.count >= 35 {
                break
            }
        }

        return selected
    }

    private struct MatchMetrics {
        let confidence: Double
        let scale: CGFloat
        let rotationDegrees: Double
    }

    private func bestMatch(for template: [CGPoint], in stars: [CGPoint]) -> MatchMetrics? {
        guard template.count >= 2, stars.count >= template.count else {
            return nil
        }

        var bestScore: Double = -1
        var bestScale: CGFloat = 1
        var bestAngle: Double = 0

        for i in 0..<(template.count - 1) {
            for j in (i + 1)..<template.count {
                let t1 = template[i]
                let t2 = template[j]
                let tv = CGVector(dx: t2.x - t1.x, dy: t2.y - t1.y)
                let tLen = hypot(tv.dx, tv.dy)
                if tLen < 0.0001 { continue }

                for a in 0..<(stars.count - 1) {
                    for b in (a + 1)..<stars.count {
                        let s1 = stars[a]
                        let s2 = stars[b]
                        let sv = CGVector(dx: s2.x - s1.x, dy: s2.y - s1.y)
                        let sLen = hypot(sv.dx, sv.dy)
                        if sLen < 0.0001 { continue }

                        let scale = sLen / tLen
                        if scale < 0.3 || scale > 3.0 { continue }

                        let angle = atan2(sv.dy, sv.dx) - atan2(tv.dy, tv.dx)
                        let cosA = cos(angle)
                        let sinA = sin(angle)

                        var matchedCount = 0
                        var totalDistance: Double = 0

                        for tp in template {
                            let dx = tp.x - t1.x
                            let dy = tp.y - t1.y

                            let rx = (dx * cosA) - (dy * sinA)
                            let ry = (dx * sinA) + (dy * cosA)

                            let mapped = CGPoint(
                                x: s1.x + (rx * scale),
                                y: s1.y + (ry * scale)
                            )

                            var nearest = Double.greatestFiniteMagnitude
                            for star in stars {
                                let d = hypot(Double(mapped.x - star.x), Double(mapped.y - star.y))
                                if d < nearest { nearest = d }
                            }

                            if nearest < 0.055 {
                                matchedCount += 1
                                totalDistance += nearest
                            }
                        }

                        let base = Double(matchedCount) / Double(template.count)
                        let proximityBonus = matchedCount > 0 ? max(0, 0.3 - (totalDistance / Double(matchedCount))) : 0
                        let score = base + proximityBonus

                        if score > bestScore {
                            bestScore = score
                            bestScale = CGFloat(scale)
                            bestAngle = angle * 180 / .pi
                        }
                    }
                }
            }
        }

        guard bestScore > 0 else { return nil }

        let confidence = min(1.0, max(0.0, bestScore / 1.2))
        return MatchMetrics(confidence: confidence, scale: bestScale, rotationDegrees: bestAngle)
    }
}

private enum ConstellationGuide: String, CaseIterable, Identifiable {
    case orion
    case cassiopeia
    case ursaMajor
    case scorpius

    var id: String { rawValue }

    var name: String {
        switch self {
        case .orion: return "Orion"
        case .cassiopeia: return "Cassiopeia"
        case .ursaMajor: return "Ursa Major"
        case .scorpius: return "Scorpius"
        }
    }

    var normalizedPoints: [CGPoint] {
        switch self {
        case .orion:
            return [
                CGPoint(x: 0.2, y: 0.2), CGPoint(x: 0.45, y: 0.36), CGPoint(x: 0.7, y: 0.22),
                CGPoint(x: 0.62, y: 0.5), CGPoint(x: 0.5, y: 0.68), CGPoint(x: 0.38, y: 0.52),
                CGPoint(x: 0.28, y: 0.78)
            ]
        case .cassiopeia:
            return [
                CGPoint(x: 0.12, y: 0.5), CGPoint(x: 0.3, y: 0.32), CGPoint(x: 0.48, y: 0.56),
                CGPoint(x: 0.66, y: 0.34), CGPoint(x: 0.84, y: 0.56)
            ]
        case .ursaMajor:
            return [
                CGPoint(x: 0.15, y: 0.3), CGPoint(x: 0.35, y: 0.3), CGPoint(x: 0.45, y: 0.44),
                CGPoint(x: 0.34, y: 0.58), CGPoint(x: 0.52, y: 0.62), CGPoint(x: 0.68, y: 0.52),
                CGPoint(x: 0.84, y: 0.45)
            ]
        case .scorpius:
            return [
                CGPoint(x: 0.16, y: 0.24), CGPoint(x: 0.3, y: 0.36), CGPoint(x: 0.42, y: 0.47),
                CGPoint(x: 0.52, y: 0.61), CGPoint(x: 0.66, y: 0.71), CGPoint(x: 0.76, y: 0.62),
                CGPoint(x: 0.83, y: 0.74)
            ]
        }
    }
}

#Preview {
    NavigationStack {
        ConstellationFinderView()
    }
}
