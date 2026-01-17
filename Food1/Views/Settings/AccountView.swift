//
//  AccountView.swift
//  Food1
//
//  Account management screen shown in Settings.
//  Displays sign-in methods, subscription status, sign out, and account deletion.
//
//  WHY TWO-STEP DELETE CONFIRMATION:
//  - Apple requires account deletion for apps with account creation
//  - Destructive actions should have friction to prevent accidents
//  - User must type "DELETE" to confirm (industry best practice)
//
//  MULTI-PROVIDER SUPPORT:
//  - Shows all linked authentication providers (Apple, Google, Email)
//  - Uses AuthProvider enum from UserProfile.swift
//  - linkedProviders computed property from AuthViewModel
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

    // Name editing
    @State private var showingNameEditor = false
    @State private var editedName = ""
    @State private var isSavingName = false

    /// User's email - may be hidden for Apple users with private relay
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

    /// Check if user is using Apple's private relay email
    private var isPrivateRelayEmail: Bool {
        guard let email = userEmail else { return false }
        return email.contains("privaterelay.appleid.com")
    }

    var body: some View {
        NavigationStack {
            List {
                // Account Info Section
                Section {
                    // Name (editable)
                    Button(action: {
                        editedName = authViewModel.profile?.fullName ?? ""
                        showingNameEditor = true
                    }) {
                        HStack {
                            Text("Name")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(authViewModel.profile?.fullName ?? "Not set")
                                .foregroundColor(authViewModel.profile?.fullName != nil ? .primary : .secondary)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.secondary.opacity(0.5))
                        }
                    }
                    .buttonStyle(.plain)

                    // Sign-in methods (show all linked providers)
                    HStack {
                        Text("Signed in with")
                            .foregroundColor(.secondary)
                        Spacer()
                        if authViewModel.linkedProviders.isEmpty {
                            // Fallback if no providers detected
                            Text("Unknown")
                                .foregroundColor(.secondary)
                        } else if authViewModel.linkedProviders.count == 1 {
                            // Single provider - show name and icon
                            let provider = authViewModel.primaryProvider
                            HStack(spacing: 6) {
                                Image(systemName: provider.icon)
                                    .font(.system(size: provider == .apple ? 14 : 12))
                                Text(provider.displayName)
                            }
                            .foregroundColor(.primary)
                        } else {
                            // Multiple providers - show icons only
                            HStack(spacing: 8) {
                                ForEach(authViewModel.linkedProviders) { provider in
                                    Image(systemName: provider.icon)
                                        .font(.system(size: provider == .apple ? 14 : 12))
                                        .foregroundColor(.primary)
                                }
                            }
                        }
                    }

                    // Email (only show if available)
                    if let email = userEmail {
                        HStack {
                            Text("Email")
                                .foregroundColor(.secondary)
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(email)
                                    .foregroundColor(.primary)
                                    .font(.system(size: 15))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                if isPrivateRelayEmail {
                                    Text("Private Relay")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                            }
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
                    .confirmationSheet(
                        isPresented: $showingSignOutConfirmation,
                        title: "Sign Out",
                        message: "Are you sure you want to sign out of your account?",
                        confirmTitle: "Sign Out",
                        confirmStyle: .primary,
                        cancelTitle: "Cancel",
                        icon: "rectangle.portrait.and.arrow.right"
                    ) {
                        handleSignOut()
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
                    .confirmationSheet(
                        isPresented: $showingDeleteConfirmation,
                        title: "Delete Account",
                        message: "This will permanently delete your account and all data. This action cannot be undone.",
                        confirmTitle: "Delete Account",
                        confirmStyle: .destructive,
                        cancelTitle: "Cancel",
                        icon: "trash"
                    ) {
                        showingDeleteFinalConfirmation = true
                    }
                } footer: {
                    Text("Permanently delete your account and all data.")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }
            .scrollIndicators(.hidden)
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
            .alert("Edit Name", isPresented: $showingNameEditor) {
                TextField("Your name", text: $editedName)
                    .autocapitalization(.words)
                Button("Cancel", role: .cancel) {
                    editedName = ""
                }
                Button("Save") {
                    handleSaveName()
                }
                .disabled(isSavingName)
            } message: {
                Text("Enter the name to display in the app.")
            }
        }
    }

    private func handleSaveName() {
        let nameToSave = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !nameToSave.isEmpty else { return }

        isSavingName = true

        Task {
            do {
                try await authViewModel.updateProfile(
                    fullName: nameToSave,
                    age: nil,
                    weightKg: nil,
                    heightCm: nil,
                    gender: nil,
                    activityLevel: nil
                )
                HapticManager.success()
            } catch {
                // Error handled in AuthViewModel
            }
            isSavingName = false
            editedName = ""
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
