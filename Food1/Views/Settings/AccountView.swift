//
//  AccountView.swift
//  Food1
//
//  Account management screen shown in Settings.
//  Displays sign-in method, subscription status, sign out, and account deletion.
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
    @State private var copiedUserId = false

    // Account deletion states
    @State private var showingDeleteConfirmation = false
    @State private var showingDeleteFinalConfirmation = false
    @State private var deleteConfirmationText = ""
    @State private var isDeleting = false
    @State private var showDeleteError = false
    @State private var deleteErrorMessage = ""

    /// Detect if user signed in with Apple (check identities array)
    private var isAppleUser: Bool {
        guard let user = authViewModel.currentUser else { return false }
        // Check identities array for apple provider
        if let identities = user.identities {
            return identities.contains(where: { $0.provider == "apple" })
        }
        return false
    }

    /// User's email - may be hidden for Apple users
    private var userEmail: String? {
        // Try profile email first
        if let email = authViewModel.profile?.email, !email.isEmpty {
            return email
        }
        // Try user email from auth
        if let email = authViewModel.currentUser?.email, !email.isEmpty {
            return email
        }
        return nil
    }

    var body: some View {
        NavigationStack {
            List {
                // Account Info Section
                Section {
                    // Sign-in method
                    HStack {
                        Text("Signed in with")
                            .foregroundColor(.secondary)
                        Spacer()
                        if isAppleUser {
                            HStack(spacing: 6) {
                                Image(systemName: "apple.logo")
                                    .font(.system(size: 14))
                                Text("Apple")
                            }
                            .foregroundColor(.primary)
                        } else {
                            HStack(spacing: 6) {
                                Image(systemName: "envelope.fill")
                                    .font(.system(size: 12))
                                Text("Email")
                            }
                            .foregroundColor(.primary)
                        }
                    }

                    // Email (only show if available)
                    if let email = userEmail {
                        HStack {
                            Text("Email")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(email)
                                .foregroundColor(.primary)
                                .font(.system(size: 15))
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }

                    // User ID (tappable to copy)
                    if let userId = authViewModel.currentUser?.id {
                        Button(action: {
                            UIPasteboard.general.string = userId.uuidString
                            HapticManager.success()
                            copiedUserId = true
                            // Reset after delay
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                copiedUserId = false
                            }
                        }) {
                            HStack {
                                Text("User ID")
                                    .foregroundColor(.secondary)
                                Spacer()
                                if copiedUserId {
                                    Text("Copied!")
                                        .foregroundColor(.green)
                                        .font(.system(size: 13))
                                } else {
                                    Text(userId.uuidString)
                                        .foregroundColor(.primary)
                                        .font(.system(size: 11, design: .monospaced))
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("Account")
                }

                // Subscription Section
                Section {
                    HStack {
                        Text("Status")
                            .foregroundColor(.secondary)
                        Spacer()
                        if authViewModel.storeKitIsPremium {
                            Text("Active")
                                .foregroundColor(.green)
                        } else {
                            Text("Inactive")
                                .foregroundColor(.secondary)
                        }
                    }

                    if !authViewModel.storeKitIsPremium {
                        Button(action: { showingPaywall = true }) {
                            HStack {
                                Text("Subscribe")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
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
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .foregroundColor(.primary)
                            Text("Sign Out")
                                .foregroundColor(.primary)
                        }
                    }
                    .disabled(isSigningOut)
                    .opacity(isSigningOut ? 0.6 : 1.0)
                    .confirmationDialog("Sign Out", isPresented: $showingSignOutConfirmation) {
                        Button("Sign Out", role: .destructive) {
                            handleSignOut()
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("Are you sure you want to sign out?")
                    }
                }

                // Delete Account Section
                Section {
                    Button(action: {
                        showingDeleteConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                            Text("Delete Account")
                                .foregroundColor(.red)
                        }
                    }
                    .accessibilityIdentifier("deleteAccountButton")
                    .disabled(isDeleting)
                    .opacity(isDeleting ? 0.6 : 1.0)
                    .confirmationDialog("Delete Account", isPresented: $showingDeleteConfirmation) {
                        Button("Delete Account", role: .destructive) {
                            showingDeleteFinalConfirmation = true
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("This will permanently delete your account and all data. This cannot be undone.")
                    }
                } footer: {
                    Text("Permanently delete your account and all data.")
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
                Text("Type DELETE to confirm.")
            }
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
