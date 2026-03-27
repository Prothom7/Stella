import SwiftUI

struct AuthInputField: View {
    let title: String
    let placeholder: String
    let symbol: String
    @Binding var text: String
    let labelSize: CGFloat
    let inputHorizontal: CGFloat
    let inputVertical: CGFloat
    let fieldCorner: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: labelSize, weight: .medium, design: .default))
                .foregroundStyle(.white.opacity(0.9))

            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .foregroundStyle(.white.opacity(0.78))
                    .frame(width: 18)

                TextField(
                    "",
                    text: $text,
                    prompt: Text(placeholder).foregroundStyle(.white.opacity(0.72))
                )
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .foregroundStyle(.white)
            }
            .padding(.horizontal, inputHorizontal)
            .padding(.vertical, inputVertical)
            .background(
                RoundedRectangle(cornerRadius: fieldCorner, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .opacity(0.5)
            )
            .overlay(
                RoundedRectangle(cornerRadius: fieldCorner, style: .continuous)
                    .stroke(.white.opacity(0.2), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: fieldCorner, style: .continuous))
        }
    }
}

struct AuthSecureInputField: View {
    let title: String
    let placeholder: String
    let symbol: String
    @Binding var text: String
    let labelSize: CGFloat
    let inputHorizontal: CGFloat
    let inputVertical: CGFloat
    let fieldCorner: CGFloat

    @State private var isRevealed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: labelSize, weight: .medium, design: .default))
                .foregroundStyle(.white.opacity(0.9))

            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .foregroundStyle(.white.opacity(0.78))
                    .frame(width: 18)

                Group {
                    if isRevealed {
                        TextField(
                            "",
                            text: $text,
                            prompt: Text(placeholder).foregroundStyle(.white.opacity(0.72))
                        )
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .foregroundStyle(.white)
                    } else {
                        SecureField(
                            "",
                            text: $text,
                            prompt: Text(placeholder).foregroundStyle(.white.opacity(0.72))
                        )
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .foregroundStyle(.white)
                    }
                }

                Button {
                    isRevealed.toggle()
                } label: {
                    Image(systemName: isRevealed ? "eye.slash" : "eye")
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            .padding(.horizontal, inputHorizontal)
            .padding(.vertical, inputVertical)
            .background(
                RoundedRectangle(cornerRadius: fieldCorner, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .opacity(0.5)
            )
            .overlay(
                RoundedRectangle(cornerRadius: fieldCorner, style: .continuous)
                    .stroke(.white.opacity(0.2), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: fieldCorner, style: .continuous))
        }
    }
}
