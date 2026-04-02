import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import PhotosUI
import UIKit

struct ProfileView: View {
    @State private var isLoggingOut = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var profileUIImage: UIImage?
    @State private var isUploadingImage = false
    @State private var statusMessage = ""
    @State private var isStatusAlertPresented = false

    private var currentUser: User? { Auth.auth().currentUser }
    private var displayName: String {
        let name = currentUser?.displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? "Stella Explorer" : name
    }

    private var email: String {
        currentUser?.email ?? "No email available"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                profileHeader

                profileInfoCard

                Button {
                    isLoggingOut = true
                    try? Auth.auth().signOut()
                    isLoggingOut = false
                } label: {
                    HStack(spacing: 8) {
                        if isLoggingOut {
                            ProgressView().tint(.white)
                        }
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                        Text("Log Out")
                            .font(.system(size: 17, weight: .semibold, design: .default))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundStyle(.white)
                    .background(Color.red.opacity(0.55), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(.white.opacity(0.24), lineWidth: 1)
                    )
                }
                .disabled(isLoggingOut)
                .opacity(isLoggingOut ? 0.85 : 1)
            }
            .padding(16)
        }
        .onAppear {
            loadProfileImageFromFirestore()
        }
        .onChange(of: selectedPhotoItem) { newValue in
            guard let newValue else { return }
            Task {
                await processSelectedPhoto(newValue)
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Profile Photo", isPresented: $isStatusAlertPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(statusMessage)
        }
        .background {
            ZStack {
                Image("img_06")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .ignoresSafeArea()

                LinearGradient(
                    colors: [Color.black.opacity(0.5), Color.black.opacity(0.34), Color.black.opacity(0.58)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            }
        }
    }

    private var profileHeader: some View {
        VStack(spacing: 10) {
            ZStack {
                if let profileUIImage {
                    Image(uiImage: profileUIImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 96, height: 96)
                        .clipShape(Circle())
                } else {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(.white.opacity(0.95))
                }

                if isUploadingImage {
                    Circle()
                        .fill(Color.black.opacity(0.5))
                        .frame(width: 96, height: 96)
                    ProgressView()
                        .tint(.white)
                }
            }

            PhotosPicker(selection: $selectedPhotoItem, matching: .images, photoLibrary: .shared()) {
                Text(profileUIImage == nil ? "Add Profile Photo" : "Change Profile Photo")
                    .font(.system(size: 13, weight: .semibold, design: .default))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.white.opacity(0.18), in: Capsule())
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(.white.opacity(0.28), lineWidth: 1)
                    )
            }
            .disabled(isUploadingImage)

            Text(displayName)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("Mission control for your Stella journey")
                .font(.system(size: 14, weight: .medium, design: .default))
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .background(Color.black.opacity(0.34), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(.white.opacity(0.26), lineWidth: 1)
        )
    }

    private var profileInfoCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Account")
                .font(.system(size: 19, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)

            Text("Profile photo is securely synced to Firestore.")
                .font(.system(size: 13, weight: .medium, design: .default))
                .foregroundStyle(.white.opacity(0.88))

            profileRow(icon: "envelope.fill", title: "Email", value: email)
            profileRow(icon: "person.text.rectangle.fill", title: "UID", value: currentUser?.uid ?? "Unavailable")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.black.opacity(0.32), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(.white.opacity(0.24), lineWidth: 1)
        )
    }

    private func profileRow(icon: String, title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(.white.opacity(0.9))
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .default))
                    .foregroundStyle(.white.opacity(0.92))
            }

            Text(value)
                .font(.system(size: 14, weight: .medium, design: .default))
                .foregroundStyle(.white.opacity(0.92))
                .textSelection(.enabled)
                .lineLimit(2)
        }
    }

    @MainActor
    private func processSelectedPhoto(_ item: PhotosPickerItem) async {
        do {
            guard let imageData = try await item.loadTransferable(type: Data.self) else {
                presentStatus("Could not read the selected image.")
                return
            }

            guard let image = UIImage(data: imageData) else {
                presentStatus("Selected file is not a valid image.")
                return
            }

            guard let compressed = image.jpegData(compressionQuality: 0.5) else {
                presentStatus("Could not compress image for upload.")
                return
            }

            profileUIImage = UIImage(data: compressed)
            await uploadPhotoToFirestore(imageData: compressed)
        } catch {
            presentStatus("Image selection failed: \(error.localizedDescription)")
        }
    }

    private func uploadPhotoToFirestore(imageData: Data) async {
        guard let uid = currentUser?.uid else {
            presentStatus("No active user found.")
            return
        }

        await MainActor.run {
            isUploadingImage = true
        }

        let db = Firestore.firestore()
        let payload: [String: Any] = [
            "profileImageBase64": imageData.base64EncodedString(),
            "email": email,
            "updatedAt": FieldValue.serverTimestamp()
        ]

        do {
            try await db.collection("user_profiles").document(uid).setData(payload, merge: true)
            await MainActor.run {
                isUploadingImage = false
                presentStatus("Profile photo updated successfully.")
            }
        } catch {
            await MainActor.run {
                isUploadingImage = false
                presentStatus("Upload failed: \(error.localizedDescription)")
            }
        }
    }

    private func loadProfileImageFromFirestore() {
        guard let uid = currentUser?.uid else { return }

        Firestore.firestore().collection("user_profiles").document(uid).getDocument { snapshot, error in
            if let error {
                print("Failed to load profile image: \(error.localizedDescription)")
                return
            }

            guard let data = snapshot?.data(),
                  let base64 = data["profileImageBase64"] as? String,
                  let imageData = Data(base64Encoded: base64),
                  let image = UIImage(data: imageData) else {
                return
            }

            DispatchQueue.main.async {
                profileUIImage = image
            }
        }
    }

    private func presentStatus(_ message: String) {
        statusMessage = message
        isStatusAlertPresented = true
    }
}

#Preview {
    NavigationStack {
        ProfileView()
    }
}
