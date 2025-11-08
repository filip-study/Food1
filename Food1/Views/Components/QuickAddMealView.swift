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
    @State private var showingPackagingPrompt = false
    @State private var showingPredictions = false
    @State private var showingNoFoodAlert = false
    @State private var nutritionReviewPrediction: FoodRecognitionService.FoodPrediction? = nil

    // Recognition data
    @State private var capturedImage: UIImage?
    @State private var predictions: [FoodRecognitionService.FoodPrediction] = []
    @State private var selectedPrediction: FoodRecognitionService.FoodPrediction?
    @State private var hasPackaging = false
    @State private var showingLabelCamera = false
    @State private var nutritionLabelImage: UIImage?
    @State private var labelData: NutritionLabelData?
    @State private var minimumLoadingDisplayed = false  // Prevents flash on quick API responses
    @State private var currentMessageIndex = 0  // For rotating loading messages
    @State private var rotationAngle: Double = 0  // For custom spinner animation

    // Accessibility
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        ZStack {
            // Show camera only if we haven't captured a photo yet
            if capturedImage == nil {
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
            } else {
                // Show captured photo as static background once captured
                // This prevents camera from showing during sheet dismissals
                Image(uiImage: capturedImage!)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
            }

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
        .sheet(isPresented: $showingPackagingPrompt) {
            if let image = capturedImage {
                PackagingPromptView(
                    capturedImage: image,
                    onScanLabel: {
                        showingLabelCamera = true
                    },
                    onSkipToAI: {
                        showingPredictions = true
                    }
                )
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
                        // Set the prediction for sheet presentation
                        nutritionReviewPrediction = prediction
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
        .sheet(item: $nutritionReviewPrediction) { prediction in
            let _ = {
                print("🍽️ Opening NutritionReviewView for: \(prediction.displayName)")
                print("   Prediction nutrition: cals=\(prediction.calories?.description ?? "nil"), prot=\(prediction.protein?.description ?? "nil"), carbs=\(prediction.carbs?.description ?? "nil"), fat=\(prediction.fat?.description ?? "nil"), grams=\(prediction.estimatedGrams)")
                if let label = labelData {
                    print("   Label data nutrition: cals=\(label.nutrition.calories), prot=\(label.nutrition.protein), carbs=\(label.nutrition.carbs), fat=\(label.nutrition.fat), grams=\(label.estimatedGrams?.description ?? "nil")")
                }
                let prefillCals = labelData?.nutrition.calories ?? prediction.calories
                let prefillProt = labelData?.nutrition.protein ?? prediction.protein
                let prefillCarbs = labelData?.nutrition.carbs ?? prediction.carbs
                let prefillFat = labelData?.nutrition.fat ?? prediction.fat
                let prefillGrams = labelData?.estimatedGrams ?? prediction.estimatedGrams
                print("   Passing to NutritionReviewView: cals=\(prefillCals?.description ?? "nil"), prot=\(prefillProt?.description ?? "nil"), carbs=\(prefillCarbs?.description ?? "nil"), fat=\(prefillFat?.description ?? "nil"), grams=\(prefillGrams)")
            }()

            NutritionReviewView(
                selectedDate: selectedDate,
                foodName: prediction.displayName,
                capturedImage: capturedImage,
                prediction: prediction,
                prefilledCalories: labelData?.nutrition.calories ?? prediction.calories,
                prefilledProtein: labelData?.nutrition.protein ?? prediction.protein,
                prefilledCarbs: labelData?.nutrition.carbs ?? prediction.carbs,
                prefilledFat: labelData?.nutrition.fat ?? prediction.fat,
                prefilledEstimatedGrams: labelData?.estimatedGrams ?? prediction.estimatedGrams
            )
            .onDisappear {
                // Close the entire flow when meal is saved
                dismiss()
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
                // If label scanning dismissed without capture, show predictions list
                if nutritionLabelImage == nil && !predictions.isEmpty && !showingPredictions && nutritionReviewPrediction == nil {
                    showingPredictions = true
                }
            }
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
            // Blurred captured photo background (instead of camera view)
            if let image = capturedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .blur(radius: 40, opaque: true)
                    .overlay(Color.black.opacity(0.4))
            } else {
                // Fallback to solid color if no image
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
            }

            // Photo thumbnail in top-right corner
            if let image = capturedImage {
                VStack {
                    HStack {
                        Spacer()
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 2)
                            )
                            .shadow(color: .black.opacity(0.3), radius: 10)
                            .padding(.top, 60)
                            .padding(.trailing, 20)
                    }
                    Spacer()
                }
            }

            // Loading indicator card
            VStack(spacing: 24) {
                // Custom rotating sparkles indicator
                ZStack {
                    Image(systemName: "sparkles")
                        .font(.system(size: 50))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .cyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .rotationEffect(.degrees(reduceMotion ? 0 : rotationAngle))
                        .onAppear {
                            if !reduceMotion {
                                withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                                    rotationAngle = 360
                                }
                            }
                        }
                }
                .frame(height: 60)

                VStack(spacing: 12) {
                    Text(loadingMessages[currentMessageIndex].title)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                        .id(currentMessageIndex)
                        .transition(.opacity)

                    Text(loadingMessages[currentMessageIndex].subtitle)
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .id("subtitle-\(currentMessageIndex)")
                        .transition(.opacity)
                }
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemBackground).opacity(0.95))
            )
            .shadow(color: .black.opacity(0.3), radius: 30)
            .onAppear {
                startMessageRotation()
            }
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.3), value: recognitionService.isProcessing)
    }

    // Loading messages that rotate every 2 seconds
    private let loadingMessages: [(title: String, subtitle: String)] = [
        ("Analyzing nutrition", "Identifying ingredients and portions"),
        ("Reading the image", "Detecting food items and preparation"),
        ("Calculating macros", "Estimating calories, protein, carbs, and fat"),
        ("Almost there", "Finalizing nutrition breakdown")
    ]

    // MARK: - Actions

    /// Cycles through loading messages every 2 seconds for engaging UX
    private func startMessageRotation() {
        currentMessageIndex = 0

        Task {
            while recognitionService.isProcessing {
                try? await Task.sleep(nanoseconds: 2_000_000_000)  // 2 seconds

                if recognitionService.isProcessing {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentMessageIndex = (currentMessageIndex + 1) % loadingMessages.count
                    }
                }
            }
        }
    }

    private func handlePhotoCaptured(_ image: UIImage) {
        capturedImage = image

        // Clear previous state when starting new recognition
        labelData = nil
        selectedPrediction = nil
        minimumLoadingDisplayed = false
        currentMessageIndex = 0  // Reset message rotation

        print("📸 New photo captured - cleared previous state")

        Task {
            // Start minimum display timer (prevents flash on quick responses)
            Task {
                try? await Task.sleep(nanoseconds: 800_000_000)  // 800ms
                minimumLoadingDisplayed = true
            }

            // Start recognition
            let processedImage = recognitionService.preprocessImage(image)
            let (results, hasPackaging) = await recognitionService.recognizeFood(in: processedImage)

            predictions = results
            self.hasPackaging = hasPackaging

            // Wait for minimum loading time before showing results
            while !minimumLoadingDisplayed {
                try? await Task.sleep(nanoseconds: 50_000_000)  // Check every 50ms
            }

            if results.isEmpty {
                // Show error - no predictions
                print("❌ No predictions found")
                showingNoFoodAlert = true
            } else if hasPackaging {
                // Show packaging prompt IMMEDIATELY before predictions
                print("📦 Package detected - showing prompt")
                showingPackagingPrompt = true
            } else {
                // No packaging, go straight to predictions
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
            HapticManager.success()
        } else {
            print("❌ Failed to extract label data")
            HapticManager.error()
        }

        // After label scan, show predictions list so user can select food
        // NutritionReviewView requires selectedPrediction to be set first
        showingPredictions = true
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
        Button(action: {
            HapticManager.medium()
            onTap()
        }) {
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
