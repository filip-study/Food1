//
//  QuickAddMealView.swift
//  Food1
//
//  Created by Claude on 2025-11-07.
//

import SwiftUI
import SwiftData

/// Coordinator view that manages the quick add meal flow:
/// Custom camera → Photo capture → Recognition → Review → Save
/// Also handles gallery and manual entry alternatives
struct QuickAddMealView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext

    let selectedDate: Date

    @StateObject private var recognitionService = FoodRecognitionService()

    // Navigation state
    @State private var showingGallery = false
    @State private var showingManualEntry = false
    @State private var showingPredictions = false
    @State private var showingNutritionReview = false
    @State private var showingNoFoodAlert = false

    // Recognition data
    @State private var capturedImage: UIImage?
    @State private var predictions: [FoodRecognitionService.FoodPrediction] = []
    @State private var selectedPrediction: FoodRecognitionService.FoodPrediction?
    @State private var hasPackaging = false
    @State private var showingPackagingAlert = false
    @State private var showingLabelCamera = false
    @State private var nutritionLabelImage: UIImage?
    @State private var labelData: NutritionLabelData?

    var body: some View {
        ZStack {
            // Main custom camera view
            CustomCameraView(
                selectedDate: selectedDate,
                onPhotoCaptured: { image in
                    handlePhotoCaptured(image)
                },
                onGalleryTap: {
                    showingGallery = true
                },
                onManualTap: {
                    showingManualEntry = true
                }
            )

            // Loading overlay during recognition
            if recognitionService.isProcessing {
                recognitionLoadingOverlay
            }
        }
        .sheet(isPresented: $showingGallery) {
            GalleryPicker { image in
                handlePhotoCaptured(image)
            }
        }
        .sheet(isPresented: $showingManualEntry) {
            ManualEntryView(selectedDate: selectedDate)
                .onDisappear {
                    // Close the entire flow when meal is saved
                    dismiss()
                }
        }
        .sheet(isPresented: $showingPredictions) {
            if let image = capturedImage {
                PredictionsView(
                    image: image,
                    predictions: predictions,
                    onPredictionSelected: { prediction in
                        selectedPrediction = prediction
                        showingPredictions = false

                        // Check if we should prompt for label scan
                        if hasPackaging {
                            showingPackagingAlert = true
                        } else {
                            showingNutritionReview = true
                        }
                    },
                    onRetry: {
                        showingPredictions = false
                        // Camera view is still visible underneath
                    },
                    onCancel: {
                        dismiss()
                    }
                )
            }
        }
        .sheet(isPresented: $showingNutritionReview) {
            if let prediction = selectedPrediction {
                NutritionReviewView(
                    selectedDate: selectedDate,
                    foodName: prediction.displayName,
                    capturedImage: capturedImage,
                    prefilledCalories: labelData?.nutrition.calories ?? prediction.calories,
                    prefilledProtein: labelData?.nutrition.protein ?? prediction.protein,
                    prefilledCarbs: labelData?.nutrition.carbs ?? prediction.carbs,
                    prefilledFat: labelData?.nutrition.fat ?? prediction.fat,
                    prefilledServingSize: labelData?.servingSize ?? prediction.servingSize
                )
                .onDisappear {
                    // Close the entire flow when meal is saved
                    dismiss()
                }
            }
        }
        .sheet(isPresented: $showingLabelCamera) {
            CustomCameraView(
                selectedDate: selectedDate,
                onPhotoCaptured: { labelImage in
                    nutritionLabelImage = labelImage
                    showingLabelCamera = false
                    Task {
                        await analyzeNutritionLabel()
                    }
                },
                onGalleryTap: {
                    // Not needed for label scan, but keep for consistency
                },
                onManualTap: {
                    showingLabelCamera = false
                }
            )
            .onDisappear {
                // If label scanning dismissed without capture, show nutrition review anyway
                if !showingNutritionReview && selectedPrediction != nil {
                    showingNutritionReview = true
                }
            }
        }
        .alert("Packaged Food Detected", isPresented: $showingPackagingAlert) {
            Button("Skip", role: .cancel) {
                showingNutritionReview = true
            }
            Button("Scan Label") {
                showingLabelCamera = true
            }
        } message: {
            Text("This appears to be packaged food. Would you like to take a photo of the nutrition label for more accurate data?")
        }
        .alert("No Food Detected", isPresented: $showingNoFoodAlert) {
            Button("Try Again", role: .cancel) {
                capturedImage = nil
                predictions = []
            }
            Button("Enter Manually") {
                showingManualEntry = true
            }
        } message: {
            Text("We couldn't identify any food in this image. Try taking another photo with better lighting, or enter your meal manually.")
        }
    }

    // MARK: - Subviews

    private var recognitionLoadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)

                VStack(spacing: 8) {
                    Text("Recognizing food...")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)

                    Text("This may take a few seconds")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemBackground))
            )
            .shadow(color: .black.opacity(0.3), radius: 30)
        }
    }

    // MARK: - Actions

    private func handlePhotoCaptured(_ image: UIImage) {
        capturedImage = image

        Task {
            let processedImage = recognitionService.preprocessImage(image)
            let (results, hasPackaging) = await recognitionService.recognizeFood(in: processedImage)

            predictions = results
            self.hasPackaging = hasPackaging

            if results.isEmpty {
                // Show error - no predictions
                print("❌ No predictions found")
                showingNoFoodAlert = true
            } else {
                // Show predictions sheet
                showingPredictions = true
            }
        }
    }

    private func analyzeNutritionLabel() async {
        guard let labelImage = nutritionLabelImage else { return }

        let extractedData = await recognitionService.analyzeNutritionLabel(in: labelImage)

        if let data = extractedData {
            labelData = data
            print("✅ Successfully extracted label data: \(data.productName ?? "Unknown")")
        } else {
            print("❌ Failed to extract label data")
        }

        // Show nutrition review with or without label data
        showingNutritionReview = true
    }
}

// MARK: - Gallery Picker

struct GalleryPicker: UIViewControllerRepresentable {
    @Environment(\.dismiss) var dismiss
    let onImageSelected: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = context.coordinator
        picker.allowsEditing = true
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: GalleryPicker

        init(_ parent: GalleryPicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage {
                parent.onImageSelected(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Predictions View

struct PredictionsView: View {
    @Environment(\.dismiss) var dismiss

    let image: UIImage
    let predictions: [FoodRecognitionService.FoodPrediction]
    let onPredictionSelected: (FoodRecognitionService.FoodPrediction) -> Void
    let onRetry: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Captured image
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 250)
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                        .padding(.horizontal)
                        .padding(.top)

                    // Predictions list
                    VStack(alignment: .leading, spacing: 12) {
                        Text("What did we find?")
                            .font(.system(size: 20, weight: .bold))
                            .padding(.horizontal)

                        Text("Select the food that matches your meal")
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                            .padding(.horizontal)

                        VStack(spacing: 8) {
                            ForEach(predictions) { prediction in
                                PredictionRow(prediction: prediction) {
                                    onPredictionSelected(prediction)
                                    dismiss()
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Retry option
                    Button(action: {
                        dismiss()
                        onRetry()
                    }) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Try different photo")
                        }
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.secondary)
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Select Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                        onCancel()
                    }
                }
            }
        }
    }
}

// MARK: - Prediction Row Component
struct PredictionRow: View {
    let prediction: FoodRecognitionService.FoodPrediction
    let onTap: () -> Void

    private var confidenceColor: Color {
        switch prediction.confidencePercentage {
        case 90...100:
            return .green
        case 70..<90:
            return .blue
        case 50..<70:
            return .orange
        default:
            return .red
        }
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(prediction.displayName)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.primary)

                            Spacer()

                            // Confidence badge
                            Text("\(prediction.confidencePercentage)%")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(confidenceColor)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule()
                                        .fill(confidenceColor.opacity(0.15))
                                )
                        }

                        // Show 1-sentence description if available
                        if let description = prediction.description {
                            Text(description)
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                        } else if prediction.hasNutritionData {
                            // Show nutrition summary if no description
                            Text("\(Int(prediction.calories ?? 0)) cal • \(Int(prediction.protein ?? 0))g protein")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    Image(systemName: "arrow.forward.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.blue)
                }

            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    QuickAddMealView(selectedDate: Date())
        .modelContainer(PreviewContainer().container)
}
