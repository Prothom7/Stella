import SwiftUI
import RealityKit
import ARKit
import CoreImage

struct ConstellationFinderView: View {
    @State private var selectedConstellation: ConstellationGuide = .orion
    @State private var overlayScale: CGFloat = 1.0
    @State private var overlayRotation: Double = 0
    @State private var isAnalyzing = false
    @State private var snapshotRequestID = 0
    @State private var detectionPopup: DetectionPopup?
    @State private var detectionFrameBuffer: [DetectionFrame] = []
    @State private var captureCandidates: [CaptureCandidate] = []
    @State private var captureProgressText = ""
    @State private var qualityHintText = ""
    @State private var guidedCountdownValue: Int?
    @State private var hasTriggeredBurstAnalysis = false
    @State private var guidedCaptureTask: Task<Void, Never>?
    @State private var guidedPhase: GuidedCapturePhase = .idle
    @State private var stabilityProbeFrames: [UIImage] = []
    private let maxFramesInBuffer = 5
    private let guidedCountdownSeconds = 2
    private let burstFrameCount = 5
    private let burstFrameIntervalNanoseconds: UInt64 = 180_000_000
    private let probeFrameCount = 3
    private let probeFrameIntervalNanoseconds: UInt64 = 140_000_000

    var body: some View {
        ZStack {
            ConstellationCameraARView(snapshotRequestID: $snapshotRequestID) { image in
                handleCapturedSnapshot(image)
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
        .onDisappear {
            guidedCaptureTask?.cancel()
        }
        .navigationTitle("Constellation Finder")
        .navigationBarTitleDisplayMode(.inline)
        .alert(item: $detectionPopup) { popup in
            if let result = popup.result {
                return Alert(
                    title: Text(popup.title),
                    message: Text(popup.message),
                    primaryButton: .default(Text("Use Overlay")) {
                        selectedConstellation = result.constellation
                        overlayRotation = result.rotationDegrees
                        overlayScale = max(0.72, min(result.scale, 1.5))
                    },
                    secondaryButton: .cancel(Text("Keep Current"))
                )
            }
            return Alert(
                title: Text(popup.title),
                message: Text(popup.message),
                dismissButton: .default(Text("Try Again"))
            )
        }
    }

    private var titlePanel: some View {
        VStack(spacing: 6) {
            Text("Constellation Finder")
                .font(.system(size: 27, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("Point your phone at the sky and analyze live stars for smart matching.")
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
        HStack(spacing: 8) {
            ForEach(ConstellationGuide.allCases) { constellation in
                Button {
                    selectedConstellation = constellation
                } label: {
                    Text(constellation.name)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
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
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 2)
    }

    private var actionPanel: some View {
        VStack(spacing: 10) {
            Button {
                startGuidedCapture()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "sparkle.magnifyingglass")
                    Text(primaryAnalyzeButtonText)
                }
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(.white.opacity(0.3), lineWidth: 1)
                )
            }
            .disabled(isAnalyzing)

            if !captureProgressText.isEmpty {
                Text(captureProgressText)
                    .font(.system(size: 12, weight: .semibold, design: .default))
                    .foregroundStyle(.white.opacity(0.95))
                    .multilineTextAlignment(.center)
            }

            if !qualityHintText.isEmpty {
                Text(qualityHintText)
                    .font(.system(size: 11, weight: .medium, design: .default))
                    .foregroundStyle(.white.opacity(0.84))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, 2)
    }

    private var primaryAnalyzeButtonText: String {
        if let countdown = guidedCountdownValue {
            return "Hold Steady \(countdown)s"
        }

        if guidedPhase == .stabilityProbe {
            return "Checking Stability..."
        }

        if isAnalyzing {
            return "Analyzing..."
        }

        return "Analyze Live Sky"
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

    private func startGuidedCapture() {
        guard !isAnalyzing else { return }

        guidedCaptureTask?.cancel()
        captureCandidates.removeAll()
        stabilityProbeFrames.removeAll()
        hasTriggeredBurstAnalysis = false
        guidedCountdownValue = guidedCountdownSeconds
        captureProgressText = "Hold steady..."
        qualityHintText = "Keep the constellation centered in the reticle."
        guidedPhase = .countdown
        isAnalyzing = true

        guidedCaptureTask = Task {
            await runGuidedCaptureSequence()
        }
    }

    private func runGuidedCaptureSequence() async {
        for remaining in stride(from: guidedCountdownSeconds, through: 1, by: -1) {
            if Task.isCancelled { return }
            await MainActor.run {
                guidedCountdownValue = remaining
                captureProgressText = "Hold steady..."
            }

            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }

        await MainActor.run {
            guidedCountdownValue = nil
            guidedPhase = .stabilityProbe
            stabilityProbeFrames.removeAll()
            captureProgressText = "Checking camera stability..."
            qualityHintText = "Keep still for a moment."
        }

        for _ in 1...probeFrameCount {
            if Task.isCancelled { return }

            await MainActor.run {
                snapshotRequestID += 1
            }

            try? await Task.sleep(nanoseconds: probeFrameIntervalNanoseconds)
        }

        try? await Task.sleep(nanoseconds: 300_000_000)

        await MainActor.run {
            if !isAnalyzing || guidedPhase != .stabilityProbe {
                return
            }

            let stable = isCaptureStable(stabilityProbeFrames)
            if stable {
                guidedPhase = .burstCapture
                captureProgressText = "Stability confirmed. Capturing frames..."
                qualityHintText = "Great. Keep the pattern centered."
            } else {
                guidedPhase = .idle
                isAnalyzing = false
                captureProgressText = ""
                qualityHintText = "Too much motion. Hold your phone still and try again."
            }
        }

        guard !Task.isCancelled else { return }

        for frameIndex in 1...burstFrameCount {
            if Task.isCancelled { return }

            await MainActor.run {
                guard isAnalyzing, guidedPhase == .burstCapture else { return }
                captureProgressText = "Capturing frame \(frameIndex)/\(burstFrameCount)"
                snapshotRequestID += 1
            }

            try? await Task.sleep(nanoseconds: burstFrameIntervalNanoseconds)
        }

        try? await Task.sleep(nanoseconds: 650_000_000)

        await MainActor.run {
            if isAnalyzing,
               !hasTriggeredBurstAnalysis,
               !captureCandidates.isEmpty {
                hasTriggeredBurstAnalysis = true
                analyzeBestCapturedFrames()
            } else if isAnalyzing,
                      captureCandidates.isEmpty {
                isAnalyzing = false
                captureProgressText = ""
                qualityHintText = "No frames captured. Try again while keeping the phone steady."
            }
        }
    }

    private func handleCapturedSnapshot(_ image: UIImage) {
        guard isAnalyzing else { return }

        if guidedPhase == .stabilityProbe {
            stabilityProbeFrames.append(image)
            return
        }

        guard guidedPhase == .burstCapture else { return }

        let report = evaluateCaptureQuality(image)
        captureCandidates.append(CaptureCandidate(image: image, qualityScore: report.score, report: report))
        qualityHintText = report.hint

        if captureCandidates.count >= burstFrameCount,
           !hasTriggeredBurstAnalysis {
            hasTriggeredBurstAnalysis = true
            analyzeBestCapturedFrames()
        }
    }

    private func analyzeBestCapturedFrames() {
        let rankedCandidates = captureCandidates.sorted { $0.qualityScore > $1.qualityScore }
        captureProgressText = "Analyzing best frame..."
        guidedPhase = .analyzing

        if let bestQuality = rankedCandidates.first, bestQuality.qualityScore < 0.24 {
            isAnalyzing = false
            guidedPhase = .idle
            captureProgressText = ""
            qualityHintText = bestQuality.report.hint
            detectionPopup = DetectionPopup(
                title: "Unknown Pattern",
                message: "Capture quality is too low for reliable matching. \(bestQuality.report.hint)",
                result: nil
            )
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let detector = ConstellationDetector()
            var bestResult: ConstellationDetectionResult?

            for candidate in rankedCandidates.prefix(3) {
                if let detected = detector.detectConstellation(in: candidate.image) {
                    bestResult = detected
                    break
                }
            }

            let frame = DetectionFrame(timestamp: Date(), result: bestResult)

            DispatchQueue.main.async {
                detectionFrameBuffer.append(frame)
                if detectionFrameBuffer.count > maxFramesInBuffer {
                    detectionFrameBuffer.removeFirst()
                }

                isAnalyzing = false
                guidedPhase = .idle
                captureProgressText = ""

                if let topQuality = rankedCandidates.first {
                    qualityHintText = topQuality.report.hint
                }

                let smoothedResult = temporalSmoothing(from: detectionFrameBuffer)

                guard let smoothedResult else {
                    detectionPopup = DetectionPopup(
                        title: "Unknown Pattern",
                        message: "The capture is ambiguous. Try again. Hint: \(qualityHintText)",
                        result: nil
                    )
                    return
                }

                let confidencePercent = Int(smoothedResult.confidence * 100)
                detectionPopup = DetectionPopup(
                    title: smoothedResult.constellation.name,
                    message: "Detected \(smoothedResult.constellation.name) with \(confidencePercent)% confidence.",
                    result: smoothedResult
                )
            }
        }
    }

    private func isCaptureStable(_ frames: [UIImage]) -> Bool {
        guard frames.count >= 2 else { return false }

        var differences: [Double] = []
        differences.reserveCapacity(frames.count - 1)

        for idx in 1..<frames.count {
            let diff = normalizedFrameDifference(frames[idx - 1], frames[idx])
            differences.append(diff)
        }

        guard !differences.isEmpty else { return false }
        let averageDiff = differences.reduce(0, +) / Double(differences.count)
        return averageDiff < 0.055
    }

    private func normalizedFrameDifference(_ lhs: UIImage, _ rhs: UIImage) -> Double {
        guard let left = lhs.cgImage,
              let right = rhs.cgImage,
              let resizedLeft = resizeForQualityAnalysis(left, to: CGSize(width: 64, height: 64)),
              let resizedRight = resizeForQualityAnalysis(right, to: CGSize(width: 64, height: 64)) else {
            return 1.0
        }

        let width = resizedLeft.width
        let height = resizedLeft.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let bitsPerComponent = 8

        var leftRaw = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        var rightRaw = [UInt8](repeating: 0, count: width * height * bytesPerPixel)

        guard let leftContext = CGContext(
            data: &leftRaw,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ),
        let rightContext = CGContext(
            data: &rightRaw,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return 1.0
        }

        leftContext.draw(resizedLeft, in: CGRect(x: 0, y: 0, width: width, height: height))
        rightContext.draw(resizedRight, in: CGRect(x: 0, y: 0, width: width, height: height))

        var diffSum = 0.0
        var sampleCount = 0

        let xStart = width / 6
        let xEnd = width - xStart
        let yStart = height / 6
        let yEnd = height - yStart

        for y in yStart..<yEnd {
            for x in xStart..<xEnd {
                let i = (y * width + x) * bytesPerPixel

                let l = (0.299 * Double(leftRaw[i])) + (0.587 * Double(leftRaw[i + 1])) + (0.114 * Double(leftRaw[i + 2]))
                let r = (0.299 * Double(rightRaw[i])) + (0.587 * Double(rightRaw[i + 1])) + (0.114 * Double(rightRaw[i + 2]))
                diffSum += abs(l - r)
                sampleCount += 1
            }
        }

        guard sampleCount > 0 else { return 1.0 }
        let averageAbsDifference = diffSum / Double(sampleCount)
        return averageAbsDifference / 255.0
    }

    private func evaluateCaptureQuality(_ image: UIImage) -> CaptureQualityReport {
        guard let cgImage = image.cgImage,
              let resized = resizeForQualityAnalysis(cgImage, to: CGSize(width: 160, height: 160)) else {
            return CaptureQualityReport(score: 0.1, hint: "Capture failed. Try again.")
        }

        let width = resized.width
        let height = resized.height
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
            return CaptureQualityReport(score: 0.1, hint: "Camera quality check failed.")
        }

        context.draw(resized, in: CGRect(x: 0, y: 0, width: width, height: height))

        var grayscale = [Double](repeating: 0, count: width * height)
        var sumBrightness = 0.0

        for y in 0..<height {
            for x in 0..<width {
                let i = (y * width + x) * bytesPerPixel
                let r = Double(raw[i])
                let g = Double(raw[i + 1])
                let b = Double(raw[i + 2])
                let brightness = (0.299 * r) + (0.587 * g) + (0.114 * b)
                grayscale[(y * width) + x] = brightness
                sumBrightness += brightness
            }
        }

        let meanBrightness = sumBrightness / Double(width * height)

        var lapSum = 0.0
        var lapSqSum = 0.0
        var lapCount = 0

        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                let center = grayscale[(y * width) + x]
                let left = grayscale[(y * width) + (x - 1)]
                let right = grayscale[(y * width) + (x + 1)]
                let up = grayscale[((y - 1) * width) + x]
                let down = grayscale[((y + 1) * width) + x]

                let laplacian = (left + right + up + down) - (4.0 * center)
                lapSum += laplacian
                lapSqSum += laplacian * laplacian
                lapCount += 1
            }
        }

        let lapMean = lapCount > 0 ? lapSum / Double(lapCount) : 0
        let lapVariance = lapCount > 0 ? max(0, (lapSqSum / Double(lapCount)) - (lapMean * lapMean)) : 0

        var starLikeCount = 0
        let brightThreshold = meanBrightness + 34.0
        for y in stride(from: 2, to: height - 2, by: 2) {
            for x in stride(from: 2, to: width - 2, by: 2) {
                let center = grayscale[(y * width) + x]
                guard center > brightThreshold else { continue }

                var isLocalMax = true
                for dy in -1...1 {
                    for dx in -1...1 where !(dx == 0 && dy == 0) {
                        if grayscale[((y + dy) * width) + (x + dx)] > center {
                            isLocalMax = false
                            break
                        }
                    }
                    if !isLocalMax { break }
                }

                if isLocalMax {
                    starLikeCount += 1
                }
            }
        }

        let brightnessScore = max(0, 1.0 - min(1.0, abs(meanBrightness - 120.0) / 120.0))
        let blurScore = min(1.0, lapVariance / 220.0)
        let starScore = min(1.0, Double(starLikeCount) / 35.0)
        let finalScore = (blurScore * 0.4) + (starScore * 0.35) + (brightnessScore * 0.25)

        let hint: String
        if blurScore < 0.22 {
            hint = "Too blurry. Hold your phone steady for 2 seconds."
        } else if meanBrightness > 215 {
            hint = "Too bright. Lower the other screen brightness."
        } else if meanBrightness < 35 {
            hint = "Too dark. Increase brightness or move closer."
        } else if starLikeCount < 10 {
            hint = "Low star detail. Move closer and center the pattern."
        } else {
            hint = "Good capture quality."
        }

        return CaptureQualityReport(score: finalScore, hint: hint)
    }

    private func resizeForQualityAnalysis(_ image: CGImage, to size: CGSize) -> CGImage? {
        let renderer = UIGraphicsImageRenderer(size: size)
        let rendered = renderer.image { _ in
            UIImage(cgImage: image).draw(in: CGRect(origin: .zero, size: size))
        }
        return rendered.cgImage
    }

    private func temporalSmoothing(from frames: [DetectionFrame]) -> ConstellationDetectionResult? {
        guard !frames.isEmpty else { return nil }
        
        let recentFrames = frames.suffix(min(3, frames.count))
        var constellationScores: [String: (confidence: Double, scale: CGFloat, rotation: Double, count: Int)] = [:]
        
        for frame in recentFrames {
            guard let result = frame.result else { continue }
            let key = result.constellation.rawValue
            
            if var existing = constellationScores[key] {
                existing.confidence += result.confidence
                existing.scale += result.scale
                existing.rotation += result.rotationDegrees
                existing.count += 1
                constellationScores[key] = existing
            } else {
                constellationScores[key] = (result.confidence, result.scale, result.rotationDegrees, 1)
            }
        }
        
        let sorted = constellationScores.sorted { $0.value.confidence > $1.value.confidence }
        guard let first = sorted.first else {
            return nil
        }

        let key = first.key
        let scores = first.value
        let secondBestConfidence = sorted.dropFirst().first?.value.confidence ?? 0
        
        let avgConfidence = scores.confidence / Double(scores.count)
        let runnerUpAvg = secondBestConfidence > 0 ? (secondBestConfidence / Double(max(1, sorted.dropFirst().first?.value.count ?? 1))) : 0
        let dominance = avgConfidence - runnerUpAvg
        let hasStrongConfidence = avgConfidence > 0.48
        let hasSufficientSupport = scores.count >= 2 || avgConfidence > 0.72
        let isDominant = dominance > 0.1 || avgConfidence > 0.75

        guard hasStrongConfidence, hasSufficientSupport, isDominant else { return nil }
        
        guard let constellation = ConstellationGuide(rawValue: key) else { return nil }
        
        return ConstellationDetectionResult(
            constellation: constellation,
            confidence: avgConfidence,
            matchedRatio: 0.6,
            scale: scores.scale / CGFloat(scores.count),
            rotationDegrees: scores.rotation / Double(scores.count)
        )
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

private enum GuidedCapturePhase {
    case idle
    case countdown
    case stabilityProbe
    case burstCapture
    case analyzing
}

private struct DetectionPopup: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let result: ConstellationDetectionResult?
}

private struct DetectionFrame {
    let timestamp: Date
    let result: ConstellationDetectionResult?
}

private struct CaptureQualityReport {
    let score: Double
    let hint: String
}

private struct CaptureCandidate {
    let image: UIImage
    let qualityScore: Double
    let report: CaptureQualityReport
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
    let matchedRatio: Double
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

        var scoredResults: [ConstellationDetectionResult] = []

        for constellation in ConstellationGuide.allCases {
            if let match = bestMatch(for: constellation.normalizedPoints, in: stars) {
                scoredResults.append(
                    ConstellationDetectionResult(
                        constellation: constellation,
                        confidence: match.confidence,
                        matchedRatio: match.matchedRatio,
                        scale: match.scale,
                        rotationDegrees: match.rotationDegrees
                    )
                )
            }
        }

        guard !scoredResults.isEmpty else { return nil }
        scoredResults.sort { $0.confidence > $1.confidence }

        guard let bestResult = scoredResults.first else { return nil }
        let secondBest = scoredResults.dropFirst().first

                // Require solid confidence and enough separation from the runner-up match.
        let margin = bestResult.confidence - (secondBest?.confidence ?? 0)
                let confidentlyDominant = bestResult.confidence > 0.72 && bestResult.matchedRatio > 0.62
                let balancedPass = bestResult.confidence > 0.46 && bestResult.matchedRatio > 0.55 && margin > 0.035

                guard confidentlyDominant || balancedPass else {
            return nil
        }

        return bestResult
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

        // Apply contrast enhancement for better detection (especially for screen captures).
        let processedImage = enhanceImageContrast(cgImage)

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

        context.draw(processedImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var brightnessMap = [Double](repeating: 0, count: width * height)

        for y in 0..<height {
            for x in 0..<width {
                let i = (y * width + x) * bytesPerPixel
                let r = Double(raw[i])
                let g = Double(raw[i + 1])
                let b = Double(raw[i + 2])
                let brightness = (0.299 * r) + (0.587 * g) + (0.114 * b)
                brightnessMap[(y * width) + x] = brightness
            }
        }

        // Use Laplacian-of-Gaussian (LoG) for robust blob detection
        let stars = detectStarsWithLoG(brightnessMap: brightnessMap, width: width, height: height)
        return stars.isEmpty ? nil : stars
    }

    private func detectStarsWithLoG(brightnessMap: [Double], width: Int, height: Int) -> [CGPoint] {
        // Gaussian-based blob detection (more robust than LoG)
        struct Candidate {
            let point: CGPoint
            let brightness: Double
        }

        var candidates: [Candidate] = []
        candidates.reserveCapacity(500)

        // Compute local contrast for each pixel
        for y in 2..<(height - 2) {
            for x in 2..<(width - 2) {
                let centerBrightness = brightnessMap[(y * width) + x]
                
                // Compute local mean in 5x5 neighborhood
                var neighSum: Double = 0
                var neighCount = 0
                for dy in -2...2 {
                    for dx in -2...2 where !(dx == 0 && dy == 0) {
                        neighSum += brightnessMap[((y + dy) * width) + (x + dx)]
                        neighCount += 1
                    }
                }
                
                let localMean = neighCount > 0 ? (neighSum / Double(neighCount)) : centerBrightness
                let contrast = centerBrightness - localMean
                
                // Check if this is a local maximum with strong contrast
                guard contrast > 8.0 else { continue }
                
                var isLocalMax = true
                for dy in -1...1 {
                    for dx in -1...1 where !(dx == 0 && dy == 0) {
                        if brightnessMap[((y + dy) * width) + (x + dx)] > centerBrightness {
                            isLocalMax = false
                            break
                        }
                    }
                    if !isLocalMax { break }
                }
                
                guard isLocalMax else { continue }
                
                let px = CGFloat(x) / CGFloat(width)
                let py = CGFloat(y) / CGFloat(height)
                candidates.append(Candidate(point: CGPoint(x: px, y: py), brightness: centerBrightness))
            }
        }
        
        // Sort by brightness and deduplicate
        candidates.sort { $0.brightness > $1.brightness }
        
        var selected: [CGPoint] = []
        let minDistance: CGFloat = 0.024
        
        for candidate in candidates {
            let isDuplicate = selected.contains { existing in
                hypot(existing.x - candidate.point.x, existing.y - candidate.point.y) < minDistance
            }
            
            if !isDuplicate {
                selected.append(candidate.point)
            }
            
            if selected.count >= 70 {
                break
            }
        }
        
        return selected
    }

    private func enhanceImageContrast(_ cgImage: CGImage) -> CGImage {
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
            return cgImage
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Compute histogram for each channel.
        var rMin: UInt8 = 255, rMax: UInt8 = 0
        var gMin: UInt8 = 255, gMax: UInt8 = 0
        var bMin: UInt8 = 255, bMax: UInt8 = 0

        for i in stride(from: 0, to: raw.count, by: bytesPerPixel) {
            let r = raw[i]
            let g = raw[i + 1]
            let b = raw[i + 2]

            rMin = min(rMin, r)
            rMax = max(rMax, r)
            gMin = min(gMin, g)
            gMax = max(gMax, g)
            bMin = min(bMin, b)
            bMax = max(bMax, b)
        }

        // Apply linear stretch to expand the range.
        let rRange = max(1, Int(rMax) - Int(rMin))
        let gRange = max(1, Int(gMax) - Int(gMin))
        let bRange = max(1, Int(bMax) - Int(bMin))

        for i in stride(from: 0, to: raw.count, by: bytesPerPixel) {
            let r = Int(raw[i])
            let g = Int(raw[i + 1])
            let b = Int(raw[i + 2])

            raw[i] = UInt8(clamp(((r - Int(rMin)) * 255) / rRange, min: 0, max: 255))
            raw[i + 1] = UInt8(clamp(((g - Int(gMin)) * 255) / gRange, min: 0, max: 255))
            raw[i + 2] = UInt8(clamp(((b - Int(bMin)) * 255) / bRange, min: 0, max: 255))
        }

        guard let enhancedImage = context.makeImage() else {
            return cgImage
        }

        return enhancedImage
    }

    private func clamp(_ value: Int, min: Int, max: Int) -> Int {
        if value < min { return min }
        if value > max { return max }
        return value
    }

    private struct MatchMetrics {
        let confidence: Double
        let scale: CGFloat
        let rotationDegrees: Double
        let matchedRatio: Double
    }

    private struct SimilarityTransform {
        let scale: Double
        let angleRadians: Double
        let translation: CGPoint
    }

    private struct Correspondence {
        let templateIndex: Int
        let starIndex: Int
        let distance: Double
    }

    private struct MatchObservation {
        let correspondences: [Correspondence]
        let matchedRatio: Double
        let averageDistance: Double
    }

    private func bestMatch(for template: [CGPoint], in stars: [CGPoint]) -> MatchMetrics? {
        guard template.count >= 2, stars.count >= template.count else {
            return nil
        }

        // Use the brightest subset for matching to reduce random noise alignments.
        let matchingStarLimit = min(stars.count, 40)
        let matchingStars = Array(stars.prefix(matchingStarLimit))

        var bestScore: Double = -1
        var bestScale: CGFloat = 1
        var bestAngle: Double = 0
        var bestMatchedRatio: Double = 0

        // Limit anchor pairs to brighter stars first to reduce noise from dim artifacts.
        let anchorStarLimit = min(matchingStars.count, 30)
        let anchorStars = Array(matchingStars.prefix(anchorStarLimit))

        for i in 0..<(template.count - 1) {
            for j in (i + 1)..<template.count {
                let t1 = template[i]
                let t2 = template[j]
                let tv = CGVector(dx: t2.x - t1.x, dy: t2.y - t1.y)
                let tLen = hypot(tv.dx, tv.dy)
                if tLen < 0.0001 { continue }

                for a in 0..<(anchorStars.count - 1) {
                    for b in (a + 1)..<anchorStars.count {
                        let s1 = anchorStars[a]
                        let s2 = anchorStars[b]
                        let sv = CGVector(dx: s2.x - s1.x, dy: s2.y - s1.y)
                        let sLen = hypot(sv.dx, sv.dy)
                        if sLen < 0.0001 { continue }

                        let scale = sLen / tLen
                        if scale < 0.35 || scale > 2.6 { continue }

                        let angle = atan2(sv.dy, sv.dx) - atan2(tv.dy, tv.dx)
                        let initialTransform = SimilarityTransform(
                            scale: Double(scale),
                            angleRadians: angle,
                            translation: CGPoint(x: s1.x, y: s1.y)
                        )
                        let initialDistanceThreshold = max(0.034, min(0.058, 0.036 + (Double(scale) * 0.007)))

                        let firstPass = matchTemplate(
                            template,
                            stars: matchingStars,
                            anchorTemplate: t1,
                            transform: initialTransform,
                            distanceThreshold: initialDistanceThreshold
                        )

                        guard firstPass.matchedRatio >= 0.4,
                              firstPass.correspondences.count >= 3 else {
                            continue
                        }

                        let refinedTransform = refineTransform(
                            template: template,
                            stars: matchingStars,
                            correspondences: firstPass.correspondences,
                            fallback: initialTransform
                        )

                        let refinedDistanceThreshold = max(0.03, min(0.052, initialDistanceThreshold * 0.9))
                        let secondPass = matchTemplate(
                            template,
                            stars: matchingStars,
                            anchorTemplate: t1,
                            transform: refinedTransform,
                            distanceThreshold: refinedDistanceThreshold
                        )

                        let matchedRatio = secondPass.matchedRatio
                        let proximityScore = max(0, 1.0 - (secondPass.averageDistance / refinedDistanceThreshold))
                        let coverageScore = min(1.0, Double(secondPass.correspondences.count) / Double(min(template.count, matchingStars.count)))
                        let structureScore = shapeConsistencyScore(
                            template: template,
                            stars: matchingStars,
                            correspondences: secondPass.correspondences,
                            expectedScale: refinedTransform.scale
                        )
                        let topologyScore = topologyScore(
                            template: template,
                            stars: matchingStars,
                            correspondences: secondPass.correspondences
                        )
                        let score = (matchedRatio * 0.44)
                            + (proximityScore * 0.16)
                            + (coverageScore * 0.1)
                            + (structureScore * 0.14)
                            + (topologyScore * 0.16)

                        if score > bestScore {
                            bestScore = score
                            bestScale = CGFloat(refinedTransform.scale)
                            bestAngle = refinedTransform.angleRadians * 180 / .pi
                            bestMatchedRatio = matchedRatio
                        }
                    }
                }
            }
        }

        guard bestScore > 0 else { return nil }

        let confidence = min(1.0, max(0.0, (bestScore - 0.35) / 0.55))
        return MatchMetrics(
            confidence: confidence,
            scale: bestScale,
            rotationDegrees: bestAngle,
            matchedRatio: bestMatchedRatio
        )
    }

    private func matchTemplate(
        _ template: [CGPoint],
        stars: [CGPoint],
        anchorTemplate: CGPoint,
        transform: SimilarityTransform,
        distanceThreshold: Double
    ) -> MatchObservation {
        let cosA = cos(transform.angleRadians)
        let sinA = sin(transform.angleRadians)

        var correspondences: [Correspondence] = []
        correspondences.reserveCapacity(template.count)
        var usedStarIndices = Set<Int>()
        var totalDistance: Double = 0

        for (templateIndex, tp) in template.enumerated() {
            let dx = Double(tp.x - anchorTemplate.x)
            let dy = Double(tp.y - anchorTemplate.y)

            let rx = (dx * cosA) - (dy * sinA)
            let ry = (dx * sinA) + (dy * cosA)

            let mapped = CGPoint(
                x: transform.translation.x + CGFloat(rx * transform.scale),
                y: transform.translation.y + CGFloat(ry * transform.scale)
            )

            if mapped.x < -0.1 || mapped.x > 1.1 || mapped.y < -0.1 || mapped.y > 1.1 {
                continue
            }

            var nearest = Double.greatestFiniteMagnitude
            var nearestIndex: Int?
            for (starIndex, star) in stars.enumerated() where !usedStarIndices.contains(starIndex) {
                let d = hypot(Double(mapped.x - star.x), Double(mapped.y - star.y))
                if d < nearest {
                    nearest = d
                    nearestIndex = starIndex
                }
            }

            if nearest < distanceThreshold, let nearestIndex {
                usedStarIndices.insert(nearestIndex)
                correspondences.append(
                    Correspondence(templateIndex: templateIndex, starIndex: nearestIndex, distance: nearest)
                )
                totalDistance += nearest
            }
        }

        let matchedRatio = Double(correspondences.count) / Double(template.count)
        let averageDistance = correspondences.isEmpty ? 1.0 : (totalDistance / Double(correspondences.count))

        return MatchObservation(
            correspondences: correspondences,
            matchedRatio: matchedRatio,
            averageDistance: averageDistance
        )
    }

    private func refineTransform(
        template: [CGPoint],
        stars: [CGPoint],
        correspondences: [Correspondence],
        fallback: SimilarityTransform
    ) -> SimilarityTransform {
        guard correspondences.count >= 2 else { return fallback }

        let templatePoints = correspondences.map { template[$0.templateIndex] }
        let starPoints = correspondences.map { stars[$0.starIndex] }

        let ct = centroid(of: templatePoints)
        let cs = centroid(of: starPoints)

        var cross = 0.0
        var dot = 0.0
        var templateEnergy = 0.0
        var starEnergy = 0.0

        for idx in 0..<templatePoints.count {
            let tx = Double(templatePoints[idx].x - ct.x)
            let ty = Double(templatePoints[idx].y - ct.y)
            let sx = Double(starPoints[idx].x - cs.x)
            let sy = Double(starPoints[idx].y - cs.y)

            dot += (tx * sx) + (ty * sy)
            cross += (tx * sy) - (ty * sx)
            templateEnergy += (tx * tx) + (ty * ty)
            starEnergy += (sx * sx) + (sy * sy)
        }

        guard templateEnergy > 1e-7, starEnergy > 1e-7 else { return fallback }

        let angle = atan2(cross, dot)
        let scale = sqrt(starEnergy / templateEnergy)
        if !scale.isFinite || scale < 0.2 || scale > 3.2 {
            return fallback
        }

        let cosA = cos(angle)
        let sinA = sin(angle)
        let rotatedCx = (Double(ct.x) * cosA) - (Double(ct.y) * sinA)
        let rotatedCy = (Double(ct.x) * sinA) + (Double(ct.y) * cosA)

        let translation = CGPoint(
            x: cs.x - CGFloat(rotatedCx * scale),
            y: cs.y - CGFloat(rotatedCy * scale)
        )

        return SimilarityTransform(
            scale: scale,
            angleRadians: angle,
            translation: translation
        )
    }

    private func shapeConsistencyScore(
        template: [CGPoint],
        stars: [CGPoint],
        correspondences: [Correspondence],
        expectedScale: Double
    ) -> Double {
        guard correspondences.count >= 3 else { return 0 }

        var pairErrorSum = 0.0
        var pairCount = 0

        for i in 0..<(correspondences.count - 1) {
            for j in (i + 1)..<correspondences.count {
                let tA = template[correspondences[i].templateIndex]
                let tB = template[correspondences[j].templateIndex]
                let sA = stars[correspondences[i].starIndex]
                let sB = stars[correspondences[j].starIndex]

                let dt = Double(hypot(tA.x - tB.x, tA.y - tB.y))
                let ds = Double(hypot(sA.x - sB.x, sA.y - sB.y))

                guard dt > 1e-5 else { continue }

                let ratio = ds / dt
                let error = abs(ratio - expectedScale) / max(expectedScale, 1e-5)
                pairErrorSum += error
                pairCount += 1
            }
        }

        guard pairCount > 0 else { return 0 }

        let averageError = pairErrorSum / Double(pairCount)
        return max(0, 1.0 - (averageError / 0.35))
    }

    private func topologyScore(
        template: [CGPoint],
        stars: [CGPoint],
        correspondences: [Correspondence]
    ) -> Double {
        guard correspondences.count >= 4 else { return 0 }

        var mapping: [Int: CGPoint] = [:]
        mapping.reserveCapacity(correspondences.count)
        for correspondence in correspondences {
            mapping[correspondence.templateIndex] = stars[correspondence.starIndex]
        }

        var angleErrorSum = 0.0
        var angleCount = 0
        var ratioErrorSum = 0.0
        var ratioCount = 0

        if template.count >= 3 {
            for center in 1..<(template.count - 1) {
                guard let s0 = mapping[center - 1],
                      let s1 = mapping[center],
                      let s2 = mapping[center + 1] else {
                    continue
                }

                let t0 = template[center - 1]
                let t1 = template[center]
                let t2 = template[center + 1]

                let tv1 = CGVector(dx: t1.x - t0.x, dy: t1.y - t0.y)
                let tv2 = CGVector(dx: t2.x - t1.x, dy: t2.y - t1.y)
                let sv1 = CGVector(dx: s1.x - s0.x, dy: s1.y - s0.y)
                let sv2 = CGVector(dx: s2.x - s1.x, dy: s2.y - s1.y)

                let tLen1 = Double(hypot(tv1.dx, tv1.dy))
                let tLen2 = Double(hypot(tv2.dx, tv2.dy))
                let sLen1 = Double(hypot(sv1.dx, sv1.dy))
                let sLen2 = Double(hypot(sv2.dx, sv2.dy))

                guard tLen1 > 1e-6, tLen2 > 1e-6, sLen1 > 1e-6, sLen2 > 1e-6 else {
                    continue
                }

                let tAngle = atan2(Double(tv1.dx * tv2.dy - tv1.dy * tv2.dx), Double(tv1.dx * tv2.dx + tv1.dy * tv2.dy))
                let sAngle = atan2(Double(sv1.dx * sv2.dy - sv1.dy * sv2.dx), Double(sv1.dx * sv2.dx + sv1.dy * sv2.dy))
                let deltaAngle = wrappedAbsAngleDifference(tAngle, sAngle)
                angleErrorSum += min(.pi, deltaAngle) / .pi
                angleCount += 1

                let tRatio = tLen1 / tLen2
                let sRatio = sLen1 / sLen2
                let ratioError = abs(log(max(1e-6, sRatio) / max(1e-6, tRatio)))
                ratioErrorSum += ratioError
                ratioCount += 1
            }
        }

        guard angleCount > 0 || ratioCount > 0 else { return 0 }

        let angleScore = angleCount > 0 ? max(0, 1.0 - (angleErrorSum / Double(angleCount)) * 1.15) : 0
        let ratioScore = ratioCount > 0 ? max(0, 1.0 - (ratioErrorSum / Double(ratioCount)) / 0.55) : 0

        if angleCount == 0 { return ratioScore }
        if ratioCount == 0 { return angleScore }
        return (angleScore * 0.62) + (ratioScore * 0.38)
    }

    private func wrappedAbsAngleDifference(_ a: Double, _ b: Double) -> Double {
        var delta = a - b
        while delta > .pi { delta -= 2 * .pi }
        while delta < -.pi { delta += 2 * .pi }
        return abs(delta)
    }

    private func centroid(of points: [CGPoint]) -> CGPoint {
        guard !points.isEmpty else { return .zero }

        var sx: CGFloat = 0
        var sy: CGFloat = 0
        for point in points {
            sx += point.x
            sy += point.y
        }

        return CGPoint(x: sx / CGFloat(points.count), y: sy / CGFloat(points.count))
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
