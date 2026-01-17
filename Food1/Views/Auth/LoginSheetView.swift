//
//  LoginSheetView.swift
//  Food1
//
//  Bottom sheet for returning users to sign in.
//  Shown when tapping "I already have an account" on WelcomeView.
//
//  DESIGN:
//  - Compact sheet with login options (Apple, Google, Email)
//  - Returning users skip personalization onboarding (assumed already done)
//  - After successful login, sheet dismisses and user goes to main app
//

import SwiftUI
import AuthenticationServices
import os.log

/// Logger for login sheet events
private let logger = Logger(subsystem: "com.prismae.food1", category: "LoginSheet")

struct LoginSheetView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.webAuthenticationSession) private var webAuthenticationSession

    @State private var email = ""
    @State private var password = ""
    @State private var showEmailAuth = false
    @State private var isGoogleLoading = false
    @FocusState private var focusedField: Field?

    enum Field {
        case email, password
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Dark background
                Color.black
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Simple header - no logo (visible behind sheet)
                        Text("Sign in")
                            .font(DesignSystem.Typography.medium(size: 17))
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.top, 16)

                        // Auth options
                        VStack(spacing: 16) {
                            if !showEmailAuth {
                                // Apple Sign In
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
                                .signInWithAppleButtonStyle(.white)

                                // Google Sign In
                                GoogleSignInButton(isLoading: isGoogleLoading) {
                                    handleGoogleSignIn()
                                }
                                .disabled(isGoogleLoading || authViewModel.isLoading)

                                // Divider
                                HStack {
                                    Rectangle()
                                        .fill(Color.white.opacity(0.2))
                                        .frame(height: 1)
                                    Text("or")
                                        .font(DesignSystem.Typography.regular(size: 14))
                                        .foregroundColor(.white.opacity(0.6))
                                    Rectangle()
                                        .fill(Color.white.opacity(0.2))
                                        .frame(height: 1)
                                }
                                .padding(.vertical, 4)

                                // Email option
                                Button {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                        showEmailAuth = true
                                    }
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: "envelope.fill")
                                            .font(.system(size: 17))
                                        Text("Continue with Email")
                                    }
                                    .font(DesignSystem.Typography.medium(size: 16))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 56)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                    )
                                }
                            } else {
                                // Email sign in form
                                emailAuthForm
                            }
                        }
                        .padding(.horizontal, 24)

                        // Error message
                        if let error = authViewModel.errorMessage {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                Text(error)
                                    .font(DesignSystem.Typography.regular(size: 14))
                                    .foregroundColor(.red)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.red.opacity(0.15))
                            )
                            .padding(.horizontal, 24)
                        }

                        Spacer(minLength: 40)
                    }
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onChange(of: authViewModel.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated {
                // Successfully logged in - dismiss sheet
                // Mark personalization as complete for returning users
                Task {
                    await authViewModel.markPersonalizationComplete()
                }
                dismiss()
            }
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
                            .font(DesignSystem.Typography.medium(size: 14))
                    }
                    .foregroundColor(.white.opacity(0.8))
                }
                Spacer()
            }

            // Email field
            VStack(alignment: .leading, spacing: 8) {
                Text("Email")
                    .font(DesignSystem.Typography.medium(size: 14))
                    .foregroundColor(.white.opacity(0.7))

                TextField("you@example.com", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .email)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.1))
                    )
                    .foregroundColor(.white)
                    .disabled(authViewModel.isLoading)
            }

            // Password field
            VStack(alignment: .leading, spacing: 8) {
                Text("Password")
                    .font(DesignSystem.Typography.medium(size: 14))
                    .foregroundColor(.white.opacity(0.7))

                SecureField("Enter password", text: $password)
                    .textContentType(.password)
                    .focused($focusedField, equals: .password)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.1))
                    )
                    .foregroundColor(.white)
                    .disabled(authViewModel.isLoading)
            }

            // Sign In button
            Button {
                handleEmailAuth()
            } label: {
                HStack {
                    if authViewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .black))
                    } else {
                        Text("Sign In")
                            .font(DesignSystem.Typography.semiBold(size: 17))
                    }
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white)
                )
            }
            .disabled(authViewModel.isLoading || !isFormValid)
            .opacity(isFormValid ? 1 : 0.6)
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
                case .failure(let error):
                    if (error as NSError).code != 1001 {
                        authViewModel.errorMessage = "Apple Sign In failed. Please try again."
                    }
                }
            } catch {
                logger.error("Apple Sign In error: \(error.localizedDescription)")
            }
        }
    }

    private func handleGoogleSignIn() {
        isGoogleLoading = true

        Task {
            do {
                let url = try await authViewModel.signInWithGoogle()
                let callbackURLScheme = "com.filipolszak.food1"

                let callbackURL = try await webAuthenticationSession.authenticate(
                    using: url,
                    callbackURLScheme: callbackURLScheme
                )

                try await authViewModel.completeGoogleSignIn(from: callbackURL)
                logger.info("Google Sign In completed successfully")

            } catch {
                if (error as NSError).domain == ASWebAuthenticationSessionError.errorDomain,
                   (error as NSError).code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                    logger.debug("Google Sign In cancelled by user")
                } else {
                    logger.error("Google Sign In error: \(error.localizedDescription)")
                    authViewModel.errorMessage = "Google Sign In failed. Please try again."
                }
            }

            isGoogleLoading = false
        }
    }

    private func handleEmailAuth() {
        Task {
            do {
                try await authViewModel.signIn(email: email, password: password)
            } catch {
                logger.error("Email auth error: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Preview

#Preview {
    LoginSheetView()
        .environmentObject(AuthViewModel())
}
