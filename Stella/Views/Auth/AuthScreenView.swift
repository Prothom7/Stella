import SwiftUI
import FirebaseAuth

struct AuthScreenView: View {
    @State private var authMode: AuthMode = .login

    @State private var loginEmail = ""
    @State private var loginPassword = ""

    @State private var signupName = ""
    @State private var signupEmail = ""
    @State private var signupPassword = ""
    @State private var confirmPassword = ""

    @State private var isLoading = false
    @State private var authMessage = ""
    @State private var authMessageIsError = false

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let topInset = geo.safeAreaInsets.top
            let bottomInset = geo.safeAreaInsets.bottom

            let horizontalPadding = max(14, width * 0.045)
            let contentWidth = max(0, width - (horizontalPadding * 2))
            let cardWidth = min(contentWidth, 480)

            let headingSize = max(34, min(width * 0.11, 52))
            let headerTop = max(24, min(height * 0.05, 56)) + topInset * 0.35
            let sectionSpacing = max(16, min(height * 0.025, 28))
            let titleSpacing = max(6, min(height * 0.011, 10))

            let cardPadding = max(16, min(width * 0.05, 28))
            let cardCorner = max(20, min(width * 0.06, 28))
            let controlHeight = max(46, min(height * 0.068, 58))
            let inputVertical = max(10, min(height * 0.014, 13))
            let inputHorizontal = max(12, min(width * 0.035, 16))
            let labelSize = max(12, min(width * 0.033, 14))

            ScrollView(showsIndicators: false) {
                VStack(spacing: sectionSpacing) {
                    header(headingSize: headingSize, subtitleSize: max(13, min(width * 0.038, 17)), titleSpacing: titleSpacing)
                        .frame(maxWidth: cardWidth)
                        .padding(.top, headerTop)

                    modePicker
                        .frame(maxWidth: cardWidth)

                    Group {
                        if authMode == .login {
                            loginCard(
                                cardPadding: cardPadding,
                                cardCorner: cardCorner,
                                controlHeight: controlHeight,
                                inputHorizontal: inputHorizontal,
                                inputVertical: inputVertical,
                                labelSize: labelSize
                            )
                            .transition(.move(edge: .leading).combined(with: .opacity))
                        } else {
                            signupCard(
                                cardPadding: cardPadding,
                                cardCorner: cardCorner,
                                controlHeight: controlHeight,
                                inputHorizontal: inputHorizontal,
                                inputVertical: inputVertical,
                                labelSize: labelSize
                            )
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                        }
                    }
                    .frame(maxWidth: cardWidth)
                    .animation(.spring(response: 0.35, dampingFraction: 0.86), value: authMode)

                    if !authMessage.isEmpty {
                        Text(authMessage)
                            .font(.system(size: 14, weight: .medium, design: .default))
                            .foregroundStyle(authMessageIsError ? .red : .green)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: cardWidth, alignment: .center)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, horizontalPadding)
                .padding(.bottom, max(18, height * 0.03) + bottomInset * 0.4)
            }
            .background {
                AuthBackgroundView(
                    width: width,
                    height: height,
                    topInset: topInset,
                    bottomInset: bottomInset,
                    horizontalInsetLeading: geo.safeAreaInsets.leading,
                    horizontalInsetTrailing: geo.safeAreaInsets.trailing
                )
            }
        }
    }

    private var modePicker: some View {
        Picker("Auth Mode", selection: $authMode) {
            ForEach(AuthMode.allCases, id: \.self) { mode in
                Text(mode.title).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .padding(6)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white.opacity(0.22), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.18), radius: 14, x: 0, y: 8)
    }

    private func header(headingSize: CGFloat, subtitleSize: CGFloat, titleSpacing: CGFloat) -> some View {
        VStack(spacing: titleSpacing) {
            Text("Stella")
                .font(.system(size: headingSize, weight: .semibold, design: .default))
                .tracking(0.4)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text("Welcome back. Let's get you in.")
                .font(.system(size: subtitleSize, weight: .regular, design: .default))
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)
        }
    }

    private func loginCard(
        cardPadding: CGFloat,
        cardCorner: CGFloat,
        controlHeight: CGFloat,
        inputHorizontal: CGFloat,
        inputVertical: CGFloat,
        labelSize: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Login")
                .font(.system(size: 29, weight: .semibold, design: .default))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .center)

            AuthInputField(
                title: "Email",
                placeholder: "name@email.com",
                symbol: "envelope",
                text: $loginEmail,
                labelSize: labelSize,
                inputHorizontal: inputHorizontal,
                inputVertical: inputVertical,
                fieldCorner: controlHeight * 0.25
            )

            AuthSecureInputField(
                title: "Password",
                placeholder: "Enter password",
                symbol: "lock",
                text: $loginPassword,
                labelSize: labelSize,
                inputHorizontal: inputHorizontal,
                inputVertical: inputVertical,
                fieldCorner: controlHeight * 0.25
            )

            Button {
                loginUser()
            } label: {
                HStack(spacing: 8) {
                    if isLoading && authMode == .login {
                        ProgressView()
                            .tint(.white)
                    }

                    Text("Sign In")
                        .font(.system(size: 17, weight: .semibold, design: .default))
                }
                .frame(maxWidth: .infinity)
                .frame(height: controlHeight)
                .background(
                    LinearGradient(
                        colors: [Color(red: 0.11, green: 0.21, blue: 0.52), Color(red: 0.18, green: 0.33, blue: 0.72)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .disabled(isLoading)
            .opacity(isLoading ? 0.85 : 1)

            Button("Forgot password?") {}
                .font(.system(size: 14, weight: .medium, design: .default))
                .foregroundStyle(.white.opacity(0.92))
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(cardPadding)
        .background(glassCardBackground(corner: cardCorner))
        .clipShape(RoundedRectangle(cornerRadius: cardCorner, style: .continuous))
        .overlay(glassCardStroke(corner: cardCorner))
        .shadow(color: .black.opacity(0.2), radius: 18, x: 0, y: 12)
    }

    private func signupCard(
        cardPadding: CGFloat,
        cardCorner: CGFloat,
        controlHeight: CGFloat,
        inputHorizontal: CGFloat,
        inputVertical: CGFloat,
        labelSize: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Create Account")
                .font(.system(size: 29, weight: .semibold, design: .default))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .center)

            AuthInputField(
                title: "Full Name",
                placeholder: "Your full name",
                symbol: "person",
                text: $signupName,
                labelSize: labelSize,
                inputHorizontal: inputHorizontal,
                inputVertical: inputVertical,
                fieldCorner: controlHeight * 0.25
            )

            AuthInputField(
                title: "Email",
                placeholder: "name@email.com",
                symbol: "envelope",
                text: $signupEmail,
                labelSize: labelSize,
                inputHorizontal: inputHorizontal,
                inputVertical: inputVertical,
                fieldCorner: controlHeight * 0.25
            )

            AuthSecureInputField(
                title: "Password",
                placeholder: "Create password",
                symbol: "lock",
                text: $signupPassword,
                labelSize: labelSize,
                inputHorizontal: inputHorizontal,
                inputVertical: inputVertical,
                fieldCorner: controlHeight * 0.25
            )

            AuthSecureInputField(
                title: "Confirm Password",
                placeholder: "Re-enter password",
                symbol: "lock.shield",
                text: $confirmPassword,
                labelSize: labelSize,
                inputHorizontal: inputHorizontal,
                inputVertical: inputVertical,
                fieldCorner: controlHeight * 0.25
            )

            Button {
                createUser()
            } label: {
                HStack(spacing: 8) {
                    if isLoading && authMode == .signup {
                        ProgressView()
                            .tint(.white)
                    }

                    Text("Create Account")
                        .font(.system(size: 17, weight: .semibold, design: .default))
                }
                .frame(maxWidth: .infinity)
                .frame(height: controlHeight)
                .background(
                    LinearGradient(
                        colors: [Color(red: 0.94, green: 0.73, blue: 0.21), Color(red: 0.86, green: 0.56, blue: 0.11)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .disabled(isLoading)
            .opacity(isLoading ? 0.85 : 1)

            Text("By continuing, you agree to our Terms and Privacy Policy.")
                .font(.system(size: 12, weight: .regular, design: .default))
                .foregroundStyle(.white.opacity(0.78))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, 2)
        }
        .padding(cardPadding)
        .background(glassCardBackground(corner: cardCorner))
        .clipShape(RoundedRectangle(cornerRadius: cardCorner, style: .continuous))
        .overlay(glassCardStroke(corner: cardCorner))
        .shadow(color: .black.opacity(0.2), radius: 18, x: 0, y: 12)
    }

    private func glassCardBackground(corner: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: corner, style: .continuous)
            .fill(.ultraThinMaterial)
            .opacity(0.62)
            .overlay(
                LinearGradient(
                    colors: [Color.white.opacity(0.16), Color.white.opacity(0.02)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
            )
    }

    private func glassCardStroke(corner: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: corner, style: .continuous)
            .stroke(.white.opacity(0.22), lineWidth: 1)
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.26), Color.white.opacity(0.06)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
    }

    private func loginUser() {
        let email = loginEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        let password = loginPassword.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !email.isEmpty, !password.isEmpty else {
            setAuthMessage("Please enter your email and password.", isError: true)
            return
        }

        isLoading = true
        Auth.auth().signIn(withEmail: email, password: password) { _, error in
            isLoading = false

            if let error {
                setAuthMessage(error.localizedDescription, isError: true)
                return
            }

            setAuthMessage("Logged in successfully.", isError: false)
        }
    }

    private func createUser() {
        let email = signupEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        let password = signupPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        let confirm = confirmPassword.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !signupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            setAuthMessage("Please enter your full name.", isError: true)
            return
        }

        guard !email.isEmpty, !password.isEmpty, !confirm.isEmpty else {
            setAuthMessage("Please complete all signup fields.", isError: true)
            return
        }

        guard password.count >= 6 else {
            setAuthMessage("Password must be at least 6 characters.", isError: true)
            return
        }

        guard password == confirm else {
            setAuthMessage("Passwords do not match.", isError: true)
            return
        }

        isLoading = true
        Auth.auth().createUser(withEmail: email, password: password) { _, error in
            isLoading = false

            if let error {
                setAuthMessage(error.localizedDescription, isError: true)
                return
            }

            setAuthMessage("Account created successfully.", isError: false)
            authMode = .login
            loginEmail = email
            loginPassword = ""
        }
    }

    private func setAuthMessage(_ message: String, isError: Bool) {
        authMessage = message
        authMessageIsError = isError
    }
}

#Preview {
    AuthScreenView()
}
