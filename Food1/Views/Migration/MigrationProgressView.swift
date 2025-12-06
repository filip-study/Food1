//
//  MigrationProgressView.swift
//  Food1
//
//  Shows migration progress overlay when syncing existing local meals to cloud.
//

import SwiftUI

struct MigrationProgressView: View {

    @ObservedObject var migrationService = MigrationService.shared

    var body: some View {
        ZStack {
            // Background blur
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            // Progress card
            VStack(spacing: 24) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 80, height: 80)

                    Image(systemName: "icloud.and.arrow.up")
                        .font(.system(size: 32))
                        .foregroundStyle(.blue)
                }

                // Title
                Text("Syncing Your Meals")
                    .font(.title2.bold())

                // Status
                VStack(spacing: 8) {
                    if migrationService.totalCount > 0 {
                        Text("\(migrationService.migratedCount) of \(migrationService.totalCount) meals")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        ProgressView(value: migrationService.migrationProgress)
                            .tint(.blue)
                            .frame(width: 200)
                    } else {
                        ProgressView()
                            .tint(.blue)
                    }
                }

                // Helper text
                Text("This may take a moment...")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                // Error message (if any)
                if let error = migrationService.migrationError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.regularMaterial)
            )
            .shadow(color: .black.opacity(0.2), radius: 20)
            .padding(40)
        }
    }
}

#Preview {
    MigrationProgressView()
}
