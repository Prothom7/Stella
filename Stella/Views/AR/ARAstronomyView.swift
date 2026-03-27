import SwiftUI
import RealityKit
import ARKit
import FirebaseAuth

struct ARAstronomyView: View {
    var body: some View {
        ZStack(alignment: .top) {
            PlanetARContainerView()
                .ignoresSafeArea()

            VStack(spacing: 10) {
                Text("Stella AR")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)

                Text("Move your phone to scan the room. Pinch and rotate the planet to explore.")
                    .font(.system(size: 14, weight: .medium, design: .default))
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)

                Button {
                    try? Auth.auth().signOut()
                } label: {
                    Text("Sign Out")
                        .font(.system(size: 14, weight: .semibold, design: .default))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .foregroundStyle(.white)
                        .background(Color.black.opacity(0.35), in: Capsule())
                        .overlay(
                            Capsule()
                                .stroke(.white.opacity(0.35), lineWidth: 1)
                        )
                }
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
        }
    }
}

private struct PlanetARContainerView: UIViewRepresentable {
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)

        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.environmentTexturing = .automatic
        arView.session.run(configuration)

        let anchor = AnchorEntity(world: [0, 0, -0.8])

        let planetMesh = MeshResource.generateSphere(radius: 0.12)
        let planetMaterial = SimpleMaterial(
            color: UIColor(red: 0.22, green: 0.44, blue: 0.86, alpha: 1),
            roughness: 0.25,
            isMetallic: true
        )

        let planetEntity = ModelEntity(mesh: planetMesh, materials: [planetMaterial])
        planetEntity.name = "planet"

        // Optional orbit ring for visual context around the planet.
        let ringMesh = MeshResource.generateBox(size: [0.36, 0.002, 0.36])
        let ringMaterial = SimpleMaterial(color: .white.withAlphaComponent(0.15), isMetallic: false)
        let ringEntity = ModelEntity(mesh: ringMesh, materials: [ringMaterial])

        anchor.addChild(planetEntity)
        anchor.addChild(ringEntity)
        arView.scene.addAnchor(anchor)

        arView.installGestures([.rotation, .scale], for: planetEntity)

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}
}

#Preview {
    ARAstronomyView()
}
