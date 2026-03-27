//
//  ContentView.swift
//  Stella
//
//  Created by prothom on 3/18/26.
//

import SwiftUI
import FirebaseAuth

struct ContentView: View {
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
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.07, green: 0.10, blue: 0.23),
                    Color(red: 0.14, green: 0.30, blue: 0.58),
                    Color(red: 0.13, green: 0.59, blue: 0.62)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(.white.opacity(0.14))
                .frame(width: 240, height: 240)
                .offset(x: 130, y: -280)
                .blur(radius: 2)

            Circle()
                .fill(.cyan.opacity(0.22))
                .frame(width: 220, height: 220)
                .offset(x: -160, y: 260)
                .blur(radius: 6)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    VStack(spacing: 8) {
                        Text("Stella")
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        Text("Welcome back. Let's get you in.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    .padding(.top, 36)

                    Picker("Auth Mode", selection: $authMode) {
                        ForEach(AuthMode.allCases, id: \.self) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 8)

                    Group {
                        if authMode == .login {
                            loginCard
                                .transition(.move(edge: .leading).combined(with: .opacity))
                        } else {
                            signupCard
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                        }
                    }
                    .animation(.spring(response: 0.35, dampingFraction: 0.86), value: authMode)

                    if !authMessage.isEmpty {
                        Text(authMessage)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(authMessageIsError ? .red : .green)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 10)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 22)
            }
        }
    }

    private var loginCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Login")
                .font(.title2.weight(.semibold))

            AuthInputField(
                title: "Email",
                placeholder: "name@email.com",
                symbol: "envelope",
                text: $loginEmail
            )

            AuthSecureInputField(
                title: "Password",
                placeholder: "Enter password",
                symbol: "lock",
                text: $loginPassword
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
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [Color(red: 0.08, green: 0.56, blue: 0.96), Color(red: 0.01, green: 0.76, blue: 0.67)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .disabled(isLoading)
            .opacity(isLoading ? 0.85 : 1)

            HStack {
                Rectangle().frame(height: 1).foregroundStyle(.secondary.opacity(0.4))
                Text("OR")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Rectangle().frame(height: 1).foregroundStyle(.secondary.opacity(0.4))
            }

            HStack(spacing: 12) {
                SocialButton(label: "Apple", symbol: "apple.logo")
                SocialButton(label: "Google", symbol: "globe")
            }

            Button("Forgot password?") {}
                .font(.footnote.weight(.medium))
                .foregroundStyle(Color(red: 0.02, green: 0.53, blue: 0.88))
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.28), lineWidth: 1)
        )
    }

    private var signupCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Create Account")
                .font(.title2.weight(.semibold))

            AuthInputField(
                title: "Full Name",
                placeholder: "Your full name",
                symbol: "person",
                text: $signupName
            )

            AuthInputField(
                title: "Email",
                placeholder: "name@email.com",
                symbol: "envelope",
                text: $signupEmail
            )

            AuthSecureInputField(
                title: "Password",
                placeholder: "Create password",
                symbol: "lock",
                text: $signupPassword
            )

            AuthSecureInputField(
                title: "Confirm Password",
                placeholder: "Re-enter password",
                symbol: "lock.shield",
                text: $confirmPassword
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
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [Color(red: 0.96, green: 0.45, blue: 0.22), Color(red: 0.97, green: 0.67, blue: 0.24)],
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
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 2)
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.28), lineWidth: 1)
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

private enum AuthMode: CaseIterable {
    case login
    case signup

    var title: String {
        switch self {
        case .login:
            return "Login"
        case .signup:
            return "Sign Up"
        }
    }
}

private struct AuthInputField: View {
    let title: String
    let placeholder: String
    let symbol: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .foregroundStyle(.secondary)
                    .frame(width: 18)

                TextField(placeholder, text: $text)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(Color.white.opacity(0.76))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

private struct AuthSecureInputField: View {
    let title: String
    let placeholder: String
    let symbol: String
    @Binding var text: String
    @State private var isRevealed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .foregroundStyle(.secondary)
                    .frame(width: 18)

                Group {
                    if isRevealed {
                        TextField(placeholder, text: $text)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    } else {
                        SecureField(placeholder, text: $text)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                }

                Button {
                    isRevealed.toggle()
                } label: {
                    Image(systemName: isRevealed ? "eye.slash" : "eye")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(Color.white.opacity(0.76))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

private struct SocialButton: View {
    let label: String
    let symbol: String

    var body: some View {
        Button {
            // Frontend-only placeholder.
        } label: {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                Text(label)
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.65))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

#Preview {
    ContentView()
}
