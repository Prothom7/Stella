import SwiftUI
import FirebaseAuth

struct ProfileView: View {
    @State private var isLoggingOut = false

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
                    .background(Color.red.opacity(0.85), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .disabled(isLoggingOut)
                .opacity(isLoggingOut ? 0.85 : 1)
            }
            .padding(16)
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .background {
            ZStack {
                Image("img_01")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .ignoresSafeArea()

                LinearGradient(
                    colors: [Color.black.opacity(0.5), Color.black.opacity(0.3), Color.black.opacity(0.58)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            }
        }
    }

    private var profileHeader: some View {
        VStack(spacing: 10) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 70))
                .foregroundStyle(.white.opacity(0.95))

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
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.24), lineWidth: 1)
        )
    }

    private var profileInfoCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Account")
                .font(.system(size: 19, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)

            profileRow(icon: "envelope.fill", title: "Email", value: email)
            profileRow(icon: "person.text.rectangle.fill", title: "UID", value: currentUser?.uid ?? "Unavailable")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
                .font(.system(size: 14, weight: .regular, design: .default))
                .foregroundStyle(.white.opacity(0.86))
                .textSelection(.enabled)
                .lineLimit(2)
        }
    }
}

#Preview {
    NavigationStack {
        ProfileView()
    }
}
