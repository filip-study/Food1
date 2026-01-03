//
//  EmailConfirmationPendingView.swift
//  Food1
//
//  Shown after sign up when email confirmation is required.
//  Provides clear instructions and resend option.
//

import SwiftUI

struct EmailConfirmationPendingView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss

    let email: String
    @State private var resendCooldown = 0
    @State private var timer: Timer?

    var body: some View {
        ZStack {
            // Brand gradient background
            BrandGradientBackground()

            ScrollView {
                VStack(spacing: 32) {
                    Spacer()
                        .frame(height: 60)

                    // Email icon
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.2))
                            .frame(width: 100, height: 100)

                        Image(systemName: "envelope.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.blue)
                    }
                    .padding(.bottom, 8)

                    // Title and instructions
                    VStack(spacing: 16) {
                        Text("Check your email")
                            .font(.system(size: 32, weight: .bold))
                            .multilineTextAlignment(.center)

                        Text("We sent a confirmation link to:")
                            .font(.system(size: 17))
                            .foregroundColor(.secondary)

                        Text(email)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.primary)

                        Text("Click the link in the email to complete your registration.")
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                            .padding(.top, 8)
                    }

                    // Resend button
                    GlassmorphicCard {
                        VStack(spacing: 16) {
                            if resendCooldown > 0 {
                                Text("You can resend the email in \(resendCooldown)s")
                                    .font(.system(size: 15))
                                    .foregroundColor(.secondary)
                            } else {
                                Button {
                                    resendConfirmation()
                                } label: {
                                    HStack {
                                        if authViewModel.isLoading {
                                            ProgressView()
                                        } else {
                                            Image(systemName: "arrow.clockwise")
                                            Text("Resend confirmation email")
                                        }
                                    }
                                }
                                .primaryAuthStyle()
                                .disabled(authViewModel.isLoading)
                            }

                            // Help text
                            VStack(spacing: 8) {
                                Text("Didn't receive the email?")
                                    .font(.system(size: 14, weight: .medium))

                                Text("Check your spam folder or try resending")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.top, 8)
                        }
                    }
                    .padding(.horizontal, 24)

                    // Back to sign in button
                    Button {
                        dismiss()
                    } label: {
                        Text("Back to sign in")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.blue)
                    }
                    .padding(.top, 16)

                    Spacer()
                }
            }
            .scrollIndicators(.hidden)
        }
        .onDisappear {
            timer?.invalidate()
        }
    }

    private func resendConfirmation() {
        Task {
            do {
                try await authViewModel.resendConfirmation(email: email)

                // Start cooldown timer
                resendCooldown = 60
                timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                    if resendCooldown > 0 {
                        resendCooldown -= 1
                    } else {
                        timer?.invalidate()
                    }
                }

            } catch {
                print("Resend confirmation error: \(error)")
            }
        }
    }
}

#Preview {
    EmailConfirmationPendingView(email: "test@example.com")
        .environmentObject(AuthViewModel())
}
