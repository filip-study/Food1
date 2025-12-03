//
//  AccountView.swift
//  Food1
//
//  Account management screen shown in Settings.
//  Display user email, subscription status, and sign out option.
//

import SwiftUI
import Auth

struct AccountView: View {

    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss

    @State private var showingSignOutConfirmation = false
    @State private var isSigningOut = false

    var body: some View {
        NavigationStack {
            List {
                // Account Info Section
                Section {
                    HStack {
                        Text("Email")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(authViewModel.profile?.email ?? "No email")
                            .foregroundColor(.primary)
                    }

                    if let userId = authViewModel.currentUser?.id {
                        HStack {
                            Text("User ID")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(userId.uuidString.prefix(8) + "...")
                                .foregroundColor(.secondary)
                                .font(.system(size: 13, design: .monospaced))
                        }
                    }
                } header: {
                    Text("Account")
                }

                // Subscription Section
                Section {
                    if let subscription = authViewModel.subscription {
                        // Trial status
                        if subscription.isInTrial {
                            HStack {
                                Image(systemName: "gift.fill")
                                    .foregroundColor(.green)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Free Trial Active")
                                        .font(.system(size: 16, weight: .semibold))
                                    Text("\(subscription.trialDaysRemaining) days remaining")
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                }
                            }
                        } else {
                            HStack {
                                Image(systemName: subscription.isActive ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(subscription.isActive ? .green : .red)
                                Text(subscription.subscriptionType.rawValue.capitalized)
                            }
                        }

                        // Trial expiration warning
                        if authViewModel.shouldShowTrialWarning {
                            Text("Your trial expires soon. Consider subscribing to keep access.")
                                .font(.system(size: 13))
                                .foregroundColor(.orange)
                                .padding(.top, 4)
                        }
                    }
                } header: {
                    Text("Subscription")
                }

                // Sign Out Section
                Section {
                    Button(action: {
                        showingSignOutConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "arrow.right.square")
                                .foregroundColor(.red)
                            Text("Sign Out")
                                .foregroundColor(.red)
                        }
                    }
                    .disabled(isSigningOut)
                    .opacity(isSigningOut ? 0.6 : 1.0)
                } footer: {
                    Text("Your meals and data are securely stored in the cloud and will be available when you sign in again.")
                        .font(.system(size: 13))
                }
            }
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .confirmationDialog("Sign Out", isPresented: $showingSignOutConfirmation) {
                Button("Sign Out", role: .destructive) {
                    handleSignOut()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to sign out?")
            }
        }
    }

    private func handleSignOut() {
        isSigningOut = true

        Task {
            do {
                try await authViewModel.signOut()
                dismiss()
            } catch {
                print("Sign out error: \(error)")
            }
            isSigningOut = false
        }
    }
}

#Preview {
    AccountView()
        .environmentObject(AuthViewModel())
}
