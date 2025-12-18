//
//  AccountView.swift
//  Food1
//
//  Account management screen shown in Settings.
//  Displays user email, subscription status, sign out, and account deletion.
//
//  WHY TWO-STEP DELETE CONFIRMATION:
//  - Apple requires account deletion for apps with account creation
//  - Destructive actions should have friction to prevent accidents
//  - User must type "DELETE" to confirm (industry best practice)
//

import SwiftUI
import Auth

struct AccountView: View {

    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss

    @State private var showingSignOutConfirmation = false
    @State private var isSigningOut = false
    @State private var showingPaywall = false

    // Account deletion states
    @State private var showingDeleteConfirmation = false
    @State private var showingDeleteFinalConfirmation = false
    @State private var deleteConfirmationText = ""
    @State private var isDeleting = false
    @State private var showDeleteError = false
    @State private var deleteErrorMessage = ""

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
                        // Premium active (paid subscription)
                        if authViewModel.hasPaidSubscription {
                            HStack {
                                Image(systemName: "crown.fill")
                                    .foregroundColor(.yellow)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Premium Active")
                                        .font(.system(size: 16, weight: .semibold))
                                    if let expiresAt = subscription.subscriptionExpiresAt {
                                        Text("Renews \(expiresAt.formatted(date: .abbreviated, time: .omitted))")
                                            .font(.system(size: 14))
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        // Trial status
                        else if subscription.isInTrial {
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

                            // Trial expiration warning
                            if authViewModel.shouldShowTrialWarning {
                                Text("Your trial expires soon. Subscribe to keep access.")
                                    .font(.system(size: 13))
                                    .foregroundColor(.orange)
                                    .padding(.top, 4)
                            }

                            // Upgrade button during trial
                            Button(action: { showingPaywall = true }) {
                                HStack {
                                    Image(systemName: "sparkles")
                                    Text("Upgrade to Premium")
                                }
                                .foregroundColor(.blue)
                            }
                        }
                        // Expired/cancelled - no access
                        else {
                            HStack {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Subscription Expired")
                                        .font(.system(size: 16, weight: .semibold))
                                    Text("Subscribe to continue logging meals")
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                }
                            }

                            // Resubscribe button
                            Button(action: { showingPaywall = true }) {
                                HStack {
                                    Image(systemName: "sparkles")
                                    Text("Subscribe to Premium")
                                }
                                .foregroundColor(.blue)
                            }
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

                // Delete Account Section
                Section {
                    Button(action: {
                        showingDeleteConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "trash.fill")
                                .foregroundColor(.red)
                            Text("Delete Account")
                                .foregroundColor(.red)
                        }
                    }
                    .disabled(isDeleting)
                    .opacity(isDeleting ? 0.6 : 1.0)
                } header: {
                    Text("Danger Zone")
                } footer: {
                    Text("Permanently delete your account and all associated data. This action cannot be undone.")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
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
            // Step 1: Initial delete confirmation
            .confirmationDialog("Delete Account", isPresented: $showingDeleteConfirmation) {
                Button("Delete Account", role: .destructive) {
                    showingDeleteFinalConfirmation = true
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete your account and all your data including:\n\n• Your profile\n• All logged meals\n• Subscription status\n\nThis action cannot be undone.")
            }
            // Step 2: Final confirmation with text input
            .alert("Confirm Deletion", isPresented: $showingDeleteFinalConfirmation) {
                TextField("Type DELETE to confirm", text: $deleteConfirmationText)
                    .autocapitalization(.allCharacters)
                Button("Cancel", role: .cancel) {
                    deleteConfirmationText = ""
                }
                Button("Delete Forever", role: .destructive) {
                    handleDeleteAccount()
                }
                .disabled(deleteConfirmationText != "DELETE")
            } message: {
                Text("To confirm deletion, type DELETE in the field below.")
            }
            // Error alert
            .alert("Deletion Failed", isPresented: $showDeleteError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(deleteErrorMessage)
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
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
                // Error logged in AuthViewModel
            }
            isSigningOut = false
        }
    }

    private func handleDeleteAccount() {
        guard deleteConfirmationText == "DELETE" else { return }

        isDeleting = true
        deleteConfirmationText = ""

        Task {
            do {
                try await authViewModel.deleteAccount()
                // Success - user will be signed out and returned to onboarding
                dismiss()
            } catch {
                deleteErrorMessage = authViewModel.errorMessage ?? "An unexpected error occurred. Please try again."
                showDeleteError = true
            }
            isDeleting = false
        }
    }
}

#Preview {
    AccountView()
        .environmentObject(AuthViewModel())
}
