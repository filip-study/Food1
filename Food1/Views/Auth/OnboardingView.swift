//
//  OnboardingView.swift
//  Prismae (Food1)
//
//  Authentication screen with Apple Sign In and email options.
//  Users arrive here after tapping "Get Started" on WelcomeView.
//  Features glassmorphic design, animated logo, and production-ready UX.
//
//  WHY THIS ARCHITECTURE:
//  - Apple Sign In as primary (App Store requirement + best UX)
//  - Email as secondary option (progressive disclosure)
//  - Animated brand logo for premium first impression
//  - Glassmorphic cards for modern iOS aesthetic
//  - Proper keyboard handling with scroll dismiss
//

import SwiftUI
import AuthenticationServices
import os.log

/// Logger for onboarding auth events (filtered in Console.app by subsystem)
private let logger = Logger(subsystem: "com.prismae.food1", category: "Onboarding")

struct OnboardingView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @FocusState private var focusedField: Field?

    @State private var email = ""
    @State private var password = ""
    @State private var showEmailAuth = false
    @State private var isSignUpMode = false

    enum Field {
        case email, password
    }

    var body: some View {
        ZStack {
            // Brand gradient background
            BrandGradientBackground()

            ScrollView {
                VStack(spacing: 32) {
                    Spacer()
                        .frame(height: 80)

                    // Animated MacroRings logo
                    AnimatedLogoView()
                        .padding(.bottom, 8)

                    // App title and tagline
                    VStack(spacing: 8) {
                        Text("Prismae")
                            .font(.system(size: 36, weight: .bold))
                            .tracking(-0.5)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.primary, Color.primary.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )

                        Text("Sign in to continue")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .padding(.bottom, 24)

                    // Auth card
                    GlassmorphicCard {
                        VStack(spacing: 20) {
                            if !showEmailAuth {
                                // Apple Sign In (Primary)
                                SignInWithAppleButton(
                                    .signIn,
                                    onRequest: { request in
                                        request.requestedScopes = [.email, .fullName]
                                    },
                                    onCompletion: { result in
                                        handleAppleSignIn(result)
                                    }
                                )
                                .frame(height: 56)
                                .cornerRadius(16)
                                .signInWithAppleButtonStyle(.black)

                                // Divider
                                HStack {
                                    Rectangle()
                                        .fill(Color.secondary.opacity(0.3))
                                        .frame(height: 1)
                                    Text("or")
                                        .font(.system(size: 15))
                                        .foregroundColor(.secondary)
                                    Rectangle()
                                        .fill(Color.secondary.opacity(0.3))
                                        .frame(height: 1)
                                }
                                .padding(.vertical, 8)

                                // Email option (Secondary)
                                Button {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                        showEmailAuth = true
                                    }
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: "envelope.fill")
                                            .font(.system(size: 18))
                                        Text("Continue with Email")
                                    }
                                }
                                .secondaryAuthStyle()

                            } else {
                                // Email authentication form
                                emailAuthForm
                            }
                        }
                    }
                    .padding(.horizontal, 24)

                    // Trust indicators
                    if !showEmailAuth {
                        VStack(spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("7-day free trial")
                                    .font(.system(size: 15, weight: .medium))
                            }

                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                                Text("No credit card required")
                                    .font(.system(size: 15, weight: .medium))
                            }
                        }
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                    }

                    Spacer()
                        .frame(height: 40)
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    // MARK: - Email Auth Form

    @ViewBuilder
    private var emailAuthForm: some View {
        VStack(spacing: 20) {
            // Back button
            HStack {
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showEmailAuth = false
                        email = ""
                        password = ""
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Back")
                            .font(.system(size: 16))
                    }
                }
                Spacer()
            }

            // Mode toggle
            Picker("Mode", selection: $isSignUpMode) {
                Text("Sign In").tag(false)
                Text("Sign Up").tag(true)
            }
            .pickerStyle(.segmented)

            // Email field
            VStack(alignment: .leading, spacing: 8) {
                Text("Email")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)

                TextField("you@example.com", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .email)
                    .padding(16)
                    .background {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(UIColor.secondarySystemBackground))
                    }
                    .overlay {
                        if isValidEmail(email) && !email.isEmpty {
                            HStack {
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .padding(.trailing, 12)
                            }
                        }
                    }
                    .disabled(authViewModel.isLoading)
                    .accessibilityIdentifier("emailTextField")
            }

            // Password field
            VStack(alignment: .leading, spacing: 8) {
                Text("Password")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)

                SecureField("At least 8 characters", text: $password)
                    .textContentType(isSignUpMode ? .newPassword : .password)
                    .focused($focusedField, equals: .password)
                    .padding(16)
                    .background {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(UIColor.secondarySystemBackground))
                    }
                    .overlay {
                        if password.count >= 8 {
                            HStack {
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .padding(.trailing, 12)
                            }
                        }
                    }
                    .disabled(authViewModel.isLoading)
                    .accessibilityIdentifier("passwordSecureField")
            }

            // Error message
            if let error = authViewModel.errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(error)
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.red.opacity(0.1))
                }
            }

            // Submit button
            Button {
                handleEmailAuth()
            } label: {
                HStack {
                    if authViewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text(isSignUpMode ? "Create Account" : "Sign In")
                            .font(.system(size: 17, weight: .semibold))
                    }
                }
            }
            .primaryAuthStyle()
            .disabled(authViewModel.isLoading || !isFormValid)
            .accessibilityIdentifier("submitAuthButton")

            // Help text
            if isSignUpMode {
                Text("By creating an account, you agree to our Terms of Service and Privacy Policy")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
        }
    }

    // MARK: - Validation

    private var isFormValid: Bool {
        !email.isEmpty &&
        !password.isEmpty &&
        isValidEmail(email) &&
        password.count >= 8
    }

    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }

    // MARK: - Actions

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        Task {
            do {
                switch result {
                case .success(let authorization):
                    try await authViewModel.signInWithApple(authorization: authorization)
                    // Success - authViewModel handles navigation

                case .failure(let error):
                    // User cancelled or error occurred
                    if (error as NSError).code != 1001 { // 1001 = user cancelled
                        authViewModel.errorMessage = "Apple Sign In failed. Please try again."
                    }
                }
            } catch {
                print("Apple Sign In error: \(error)")
            }
        }
    }

    private func handleEmailAuth() {
        // Debug: Use error level for CI log capture (info level not captured by default)
        logger.error("📍 [DEBUG] handleEmailAuth() called, password.count=\(self.password.count)")
        logger.error("   isSignUpMode=\(self.isSignUpMode), isFormValid=\(self.isFormValid)")

        Task {
            do {
                logger.error("📍 [DEBUG] Task started, calling signIn...")
                if isSignUpMode {
                    try await authViewModel.signUp(email: email, password: password)
                } else {
                    try await authViewModel.signIn(email: email, password: password)
                }
                logger.error("📍 [DEBUG] signIn completed, isAuthenticated=\(self.authViewModel.isAuthenticated)")
            } catch {
                // Error already set in authViewModel
                logger.error("❌ Email auth error: \(error.localizedDescription)")
            }
        }
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AuthViewModel())
}
