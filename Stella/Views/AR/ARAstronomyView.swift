import SwiftUI
import RealityKit
import ARKit
import FirebaseFirestore

struct ARAstronomyView: View {
    let modelFileName: String
    let topicTitle: String

    init(modelFileName: String = "ISS_stationary.usdz", topicTitle: String = "ISS") {
        self.modelFileName = modelFileName
        self.topicTitle = topicTitle
    }

    @State private var selectedModelInfo: ARModelInfo?
    @State private var isLoadingInfo = false
    @State private var infoError: InfoError?
    @State private var infoCache: [String: ARModelInfo] = [:]

    var body: some View {
        ZStack(alignment: .top) {
            PlanetARContainerView(modelFileName: modelFileName) { modelKey in
                handleModelTap(modelKey: modelKey)
            }
                .ignoresSafeArea()

            VStack(spacing: 10) {
                Text("\(topicTitle) AR")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)

                Text("Move your phone to scan the room. Pinch and rotate the planet to explore.")
                    .font(.system(size: 14, weight: .medium, design: .default))
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.white.opacity(0.25), lineWidth: 1)
            )
            .padding(.top, 20)
            .padding(.horizontal, 16)

            if isLoadingInfo {
                ProgressView("Loading details...")
                    .progressViewStyle(.circular)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.top, 170)
            }
        }
        .sheet(item: $selectedModelInfo) { info in
            ARModelInfoSheet(info: info)
        }
        .alert(item: $infoError) { error in
            Alert(
                title: Text("Could not load details"),
                message: Text(error.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private func handleModelTap(modelKey: String) {
        if let cachedInfo = infoCache[modelKey] {
            selectedModelInfo = cachedInfo
            return
        }

        isLoadingInfo = true
        fetchModelInfo(modelKey: modelKey) { result in
            isLoadingInfo = false

            switch result {
            case .success(let info):
                infoCache[modelKey] = info
                selectedModelInfo = info
            case .failure(let error):
                infoError = InfoError(message: error.localizedDescription)
            }
        }
    }

    private func fetchModelInfo(modelKey: String, completion: @escaping (Result<ARModelInfo, Error>) -> Void) {
        let db = Firestore.firestore()
        let collection = db.collection("ar_models")

        collection.document(modelKey).getDocument { snapshot, error in
            if let error {
                completion(.failure(error))
                return
            }

            if let snapshot, snapshot.exists, let data = snapshot.data() {
                completion(.success(ARModelInfo.from(data: data, fallbackKey: modelKey)))
                return
            }

            collection
                .whereField("modelFileName", isEqualTo: "\(modelKey).usdz")
                .limit(to: 1)
                .getDocuments { querySnapshot, queryError in
                    if let queryError {
                        completion(.failure(queryError))
                        return
                    }

                    if let document = querySnapshot?.documents.first {
                        completion(.success(ARModelInfo.from(data: document.data(), fallbackKey: modelKey)))
                        return
                    }

                    let notFoundError = NSError(
                        domain: "Stella.ARInfo",
                        code: 404,
                        userInfo: [NSLocalizedDescriptionKey: "No Firestore details found for \(modelKey)."]
                    )
                    completion(.failure(notFoundError))
                }
        }
    }
}

private struct PlanetARContainerView: UIViewRepresentable {
    let modelFileName: String
    private var defaultModelKey: String {
        (modelFileName as NSString).deletingPathExtension
    }

    let onModelTapped: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onModelTapped: onModelTapped, modelKey: defaultModelKey)
    }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)

        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.environmentTexturing = .automatic
        configuration.isAutoFocusEnabled = true
        arView.session.run(configuration)

        let anchor = AnchorEntity(world: [0, 0, -0.8])

        let planetEntity = makePlanetEntity()
        planetEntity.name = defaultModelKey

        // Optional orbit ring for visual context around the planet.
        let ringMesh = MeshResource.generateBox(size: [0.36, 0.002, 0.36])
        let ringMaterial = SimpleMaterial(color: .white.withAlphaComponent(0.15), isMetallic: false)
        let ringEntity = ModelEntity(mesh: ringMesh, materials: [ringMaterial])

        anchor.addChild(planetEntity)
        anchor.addChild(ringEntity)
        arView.scene.addAnchor(anchor)

        planetEntity.generateCollisionShapes(recursive: true)

        context.coordinator.arView = arView
        context.coordinator.modelEntity = planetEntity
        context.coordinator.setInitialScale(from: planetEntity.scale)
        context.coordinator.initialScale = planetEntity.scale
        context.coordinator.initialPosition = planetEntity.position
        context.coordinator.initialOrientation = planetEntity.orientation

        let tapRecognizer = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        let doubleTapRecognizer = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleTap(_:)))
        doubleTapRecognizer.numberOfTapsRequired = 2
        let panRecognizer = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        panRecognizer.maximumNumberOfTouches = 1
        let pinchRecognizer = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePinch(_:)))
        let rotationRecognizer = UIRotationGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleRotation(_:)))
        let longPressRecognizer = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleLongPress(_:)))
        longPressRecognizer.minimumPressDuration = 0.45

        tapRecognizer.delegate = context.coordinator
        doubleTapRecognizer.delegate = context.coordinator
        panRecognizer.delegate = context.coordinator
        pinchRecognizer.delegate = context.coordinator
        rotationRecognizer.delegate = context.coordinator
        longPressRecognizer.delegate = context.coordinator
        tapRecognizer.require(toFail: doubleTapRecognizer)
        tapRecognizer.require(toFail: panRecognizer)

        arView.addGestureRecognizer(tapRecognizer)
        arView.addGestureRecognizer(doubleTapRecognizer)
        arView.addGestureRecognizer(panRecognizer)
        arView.addGestureRecognizer(pinchRecognizer)
        arView.addGestureRecognizer(rotationRecognizer)
        arView.addGestureRecognizer(longPressRecognizer)

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}

    private func makePlanetEntity() -> ModelEntity {
        var loadedModel: ModelEntity?
        let baseFileName = modelFileName.hasSuffix(".usdz") ? String(modelFileName.dropLast(5)) : modelFileName
        
        print("[AR DEBUG] Attempting to load model: \(modelFileName)")
        
        // PRIORITY: Load from PlanetModels subfolder via URL (most reliable method)
        if let url = Bundle.main.url(forResource: baseFileName, withExtension: "usdz", subdirectory: "PlanetModels") {
            do {
                print("[AR DEBUG] Found URL in PlanetModels: \(url.path)")
                let model = try ModelEntity.loadModel(contentsOf: url)
                print("[AR DEBUG] ✓ Successfully loaded from PlanetModels URL")
                loadedModel = model
            } catch {
                print("[AR DEBUG] ✗ Failed to load from PlanetModels URL: \(error)")
            }
        } else {
            print("[AR DEBUG] ✗ Could not find URL in PlanetModels")
        }
        
        // Fallback: Try root bundle
        if loadedModel == nil, let url = Bundle.main.url(forResource: baseFileName, withExtension: "usdz") {
            do {
                print("[AR DEBUG] Found URL in bundle root: \(url.path)")
                let model = try ModelEntity.loadModel(contentsOf: url)
                print("[AR DEBUG] ✓ Successfully loaded from root bundle URL")
                loadedModel = model
            } catch {
                print("[AR DEBUG] ✗ Failed to load from root URL: \(error)")
            }
        }
        
        // Fallback: Try named loading
        if loadedModel == nil, let model = try? ModelEntity.loadModel(named: baseFileName) {
            print("[AR DEBUG] ✓ Loaded via named:\(baseFileName)")
            loadedModel = model
        }
        
        // Fallback: Try with full filename including extension
        if loadedModel == nil, let model = try? ModelEntity.loadModel(named: modelFileName) {
            print("[AR DEBUG] ✓ Loaded via named:\(modelFileName)")
            loadedModel = model
        }
        
        if let loadedModel {
            // Recenter and normalize scale so models authored with odd pivots still appear in view.
            return normalizedVisibleModel(from: loadedModel)
        }

        // Fallback keeps AR view functional until USDZ files are added to the app bundle.
        print("[AR DEBUG] ✗ All load attempts failed. Using fallback sphere.")
        print("[AR DEBUG] Checking bundle resources for '\(baseFileName)'...")
        
        // Debug: List available resources
        if let resourcePath = Bundle.main.resourcePath,
           let contents = try? FileManager.default.contentsOfDirectory(atPath: resourcePath) {
            let usdFiles = contents.filter { $0.hasSuffix(".usdz") }
            print("[AR DEBUG] USDZ files in bundle: \(usdFiles)")
        }
        
        let fallbackMesh = MeshResource.generateSphere(radius: 0.12)
        let fallbackMaterial = SimpleMaterial(
            color: UIColor(red: 0.22, green: 0.44, blue: 0.86, alpha: 1),
            roughness: 0.25,
            isMetallic: true
        )
        return ModelEntity(mesh: fallbackMesh, materials: [fallbackMaterial])
    }

    private func normalizedVisibleModel(from model: ModelEntity) -> ModelEntity {
        let bounds = model.visualBounds(relativeTo: nil)
        let extents = bounds.extents
        let maxDimension = max(extents.x, max(extents.y, extents.z))

        // Move model so its visual center is at the local origin.
        model.position -= bounds.center

        let container = ModelEntity()
        container.addChild(model)

        // Ensure tiny/invalid bounds do not cause invisible results.
        let safeDimension = (maxDimension.isFinite && maxDimension > 0.0001) ? maxDimension : 1.0
        // Keep default size moderate so textures stay crisp instead of over-stretched.
        let targetDiameter: Float = 0.18
        let uniformScale = targetDiameter / safeDimension
        container.scale = SIMD3<Float>(repeating: uniformScale)

        return container
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        weak var arView: ARView?
        var modelEntity: ModelEntity?
        private let onModelTapped: (String) -> Void
        private let modelKey: String
        var initialScale: SIMD3<Float> = .one
        var initialPosition: SIMD3<Float> = .zero
        var initialOrientation: simd_quatf = simd_quatf(angle: 0, axis: [0, 1, 0])
        private var isDraggingModel = false
        private var smoothedDragPosition: SIMD3<Float>?
        private var dragDistanceFromCamera: Float?
        private var minScale: Float = 0.05
        private var maxScale: Float = 2.0

        init(onModelTapped: @escaping (String) -> Void, modelKey: String) {
            self.onModelTapped = onModelTapped
            self.modelKey = modelKey
        }

        func setInitialScale(from scale: SIMD3<Float>) {
            let base = max(scale.x, 0.01)
            minScale = base * 0.2
            maxScale = base * 8
        }

        @objc
        func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard let arView else { return }

            let tapLocation = recognizer.location(in: arView)
            guard let tappedEntity = arView.entity(at: tapLocation) else { return }
            guard let modelEntity = findModelEntity(startingAt: tappedEntity) else { return }
            guard !modelEntity.name.isEmpty else { return }

            onModelTapped(modelEntity.name)
        }

        @objc
        func handleDoubleTap(_ recognizer: UITapGestureRecognizer) {
            guard let modelEntity else { return }
            modelEntity.setPosition(initialPosition, relativeTo: nil)
            modelEntity.orientation = initialOrientation
            modelEntity.scale = initialScale
        }

        @objc
        func handleLongPress(_ recognizer: UILongPressGestureRecognizer) {
            guard recognizer.state == .began, let arView, let modelEntity else { return }
            let center = CGPoint(x: arView.bounds.midX, y: arView.bounds.midY)
            guard let worldPoint = worldPositionAlongCameraRay(from: center, in: arView, distance: 0.65) else { return }
            let targetTransform = Transform(scale: modelEntity.scale, rotation: modelEntity.orientation, translation: worldPoint)
            modelEntity.move(to: targetTransform, relativeTo: nil, duration: 0.22, timingFunction: .easeInOut)
        }

        @objc
        func handlePan(_ recognizer: UIPanGestureRecognizer) {
            guard let arView, let modelEntity else { return }

            let location = recognizer.location(in: arView)

            switch recognizer.state {
            case .began:
                if let hit = arView.entity(at: location), findModelEntity(startingAt: hit) != nil {
                    isDraggingModel = true
                    smoothedDragPosition = modelEntity.position(relativeTo: nil)
                    if let cameraPosition = cameraWorldPosition(in: arView) {
                        let modelWorldPosition = modelEntity.position(relativeTo: nil)
                        dragDistanceFromCamera = simd_distance(modelWorldPosition, cameraPosition)
                    }
                }
            case .changed:
                guard isDraggingModel else { return }

                if let dragDistanceFromCamera,
                   let worldPosition = worldPositionAlongCameraRay(
                    from: location,
                    in: arView,
                    distance: max(dragDistanceFromCamera, 0.05)
                   ) {
                    let current = smoothedDragPosition ?? modelEntity.position(relativeTo: nil)
                    let smoothed = simd_mix(current, worldPosition, SIMD3<Float>(repeating: 0.22))
                    smoothedDragPosition = smoothed
                    modelEntity.setPosition(smoothed, relativeTo: nil)
                }
            case .ended, .cancelled, .failed:
                isDraggingModel = false
                dragDistanceFromCamera = nil
                smoothedDragPosition = nil
            default:
                break
            }
        }

        @objc
        func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
            guard let modelEntity else { return }
            guard recognizer.state == .began || recognizer.state == .changed else { return }

            let current = modelEntity.scale.x
            let pinchDelta = pow(Float(recognizer.scale), 0.65)
            let target = max(min(current * pinchDelta, maxScale), minScale)
            let smoothed = current + (target - current) * 0.38
            modelEntity.scale = SIMD3<Float>(repeating: smoothed)
            recognizer.scale = 1
        }

        @objc
        func handleRotation(_ recognizer: UIRotationGestureRecognizer) {
            guard let modelEntity else { return }
            guard recognizer.state == .began || recognizer.state == .changed else { return }

            let delta = Float(recognizer.rotation) * 0.7
            let targetOrientation = simd_quatf(angle: delta, axis: [0, 1, 0]) * modelEntity.orientation
            modelEntity.orientation = simd_slerp(modelEntity.orientation, targetOrientation, 0.45)
            recognizer.rotation = 0
        }

        private func findModelEntity(startingAt entity: Entity) -> Entity? {
            var current: Entity? = entity

            while let entity = current {
                if entity.name == modelKey {
                    return entity
                }
                current = entity.parent
            }

            return nil
        }

        private func worldPositionAlongCameraRay(from location: CGPoint, in arView: ARView, distance: Float) -> SIMD3<Float>? {
            guard let ray = arView.ray(through: location) else { return nil }
            return ray.origin + simd_normalize(ray.direction) * distance
        }

        private func cameraWorldPosition(in arView: ARView) -> SIMD3<Float>? {
            guard let frame = arView.session.currentFrame else { return nil }
            let cameraTransform = frame.camera.transform.columns.3
            return SIMD3<Float>(cameraTransform.x, cameraTransform.y, cameraTransform.z)
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            let isPinchOrRotate = gestureRecognizer is UIPinchGestureRecognizer || gestureRecognizer is UIRotationGestureRecognizer
            let otherIsPinchOrRotate = otherGestureRecognizer is UIPinchGestureRecognizer || otherGestureRecognizer is UIRotationGestureRecognizer
            return isPinchOrRotate && otherIsPinchOrRotate
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            guard let arView, gestureRecognizer is UITapGestureRecognizer else { return true }

            let location = touch.location(in: arView)
            guard let entity = arView.entity(at: location) else { return false }
            return findModelEntity(startingAt: entity) != nil
        }
    }
}

private struct ARModelInfo: Identifiable {
    let id: String
    let title: String
    let launched: String
    let summary: String
    let funFacts: [String]

    static func from(data: [String: Any], fallbackKey: String) -> ARModelInfo {
        let title = (data["title"] as? String) ?? fallbackKey.replacingOccurrences(of: "_", with: " ")
        let launched = displayString(from: data["launched"] ?? data["launchDate"]) ?? "Unknown"
        let summary = (data["summary"] as? String) ?? (data["description"] as? String) ?? "No summary available."
        let funFacts = (data["funFacts"] as? [String]) ?? []

        return ARModelInfo(
            id: fallbackKey,
            title: title,
            launched: launched,
            summary: summary,
            funFacts: funFacts
        )
    }

    private static func displayString(from value: Any?) -> String? {
        switch value {
        case let string as String:
            return string
        case let timestamp as Timestamp:
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: timestamp.dateValue())
        case let date as Date:
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        default:
            return nil
        }
    }
}

private struct ARModelInfoSheet: View {
    let info: ARModelInfo

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(info.title)
                        .font(.title2.weight(.semibold))

                    Label("Launched: \(info.launched)", systemImage: "calendar")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)

                    Text(info.summary)
                        .font(.body)

                    if !info.funFacts.isEmpty {
                        Text("Fun Facts")
                            .font(.headline)

                        ForEach(info.funFacts, id: \.self) { fact in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "sparkles")
                                    .foregroundStyle(.blue)
                                    .padding(.top, 2)
                                Text(fact)
                                    .font(.body)
                            }
                        }
                    }
                }
                .padding(20)
            }
            .navigationTitle("Model Details")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct InfoError: Identifiable {
    let id = UUID()
    let message: String
}

#Preview {
    ARAstronomyView()
}
