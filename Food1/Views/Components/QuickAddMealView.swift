//
//  QuickAddMealView.swift
//  Food1
//
//  Coordinator view that manages the quick add meal flow:
//  Custom camera → Photo capture → Recognition → Review → Save
//  Also handles gallery and manual entry alternatives.
//
//  WHY THIS ARCHITECTURE:
//  - Custom AVFoundation camera (not UIImagePickerController) provides better UX with integrated gallery/manual buttons
//  - Blurred photo background during recognition (not camera viewfinder) shows context without distraction
//  - Rotating sparkles + dynamic messages make 2-5s API wait feel shorter and more engaging
//  - 800ms minimum display prevents jarring flash on quick responses (<1s)
//  - Photo thumbnail in loading state reinforces what's being analyzed
//

import SwiftUI
import SwiftData
import PhotosUI
struct QuickAddMealView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext

    let selectedDate: Date

    @StateObject private var recognitionService = FoodRecognitionService()

    // Navigation state
    @State private var showingGallery = false
    @State private var showingPhotoPreview = false  // Lightweight preview for quick submit (90% case)
    @State private var showingCropView = false  // Crop view for focused selection (10% case)
    @State private var selectedGalleryImage: UIImage?
    @State private var showingTextEntry = false
    @State private var showingPackagingPrompt = false
    @State private var showingNoFoodAlert = false
    @State private var nutritionReviewPrediction: FoodRecognitionService.FoodPrediction? = nil
    @State private var isLoadingGalleryImage = false  // Loading indicator for iCloud photos

    // Recognition data
    @State private var capturedImage: UIImage?
    @State private var predictions: [FoodRecognitionService.FoodPrediction] = []
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
                    onTextEntryTap: {
                        showingTextEntry = true
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

            // Loading overlay for gallery photo (iCloud downloads)
            if isLoadingGalleryImage {
                ZStack {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()

                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)

                        Text("Loading photo...")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .padding(32)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemBackground).opacity(0.95))
                    )
                }
                .transition(.opacity)
            }
        }
        .sheet(isPresented: $showingGallery) {
            GalleryPicker(
                onImageSelected: { image in
                    selectedGalleryImage = image
                    isLoadingGalleryImage = false
                },
                onLoadingStarted: {
                    isLoadingGalleryImage = true
                }
            )
        }
        .onChange(of: selectedGalleryImage) { _, newImage in
            // When image is loaded, wait for gallery sheet to dismiss then show preview
            if newImage != nil && !showingGallery {
                // Gallery already dismissed, show preview immediately
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(300))
                    showingPhotoPreview = true
                }
            }
        }
        .onChange(of: showingGallery) { _, isShowing in
            // If gallery dismisses while we have an image waiting, show preview
            if !isShowing && selectedGalleryImage != nil && !showingPhotoPreview {
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(300))
                    showingPhotoPreview = true
                }
            }
        }
        .sheet(isPresented: $showingPhotoPreview) {
            if let image = selectedGalleryImage {
                PhotoPreviewSheet(
                    image: image,
                    onAnalyze: { finalImage in
                        showingPhotoPreview = false
                        handlePhotoCaptured(finalImage)
                    },
                    onRequestCrop: {
                        showingPhotoPreview = false
                        // Small delay for smooth transition
                        Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(300))
                            showingCropView = true
                        }
                    }
                )
            }
        }
        .sheet(isPresented: $showingCropView) {
            if let image = selectedGalleryImage {
                SmartCropView(
                    originalImage: image,
                    onCropComplete: { croppedImage in
                        showingCropView = false
                        handlePhotoCaptured(croppedImage)
                    }
                )
                .interactiveDismissDisabled(true)  // Prevent accidental dismissal while panning
            }
        }
        .sheet(isPresented: $showingTextEntry) {
            TextEntryView(selectedDate: selectedDate, onMealCreated: {
                // Close the entire flow when meal is saved
                dismiss()
            })
        }
        .sheet(isPresented: $showingPackagingPrompt) {
            if let image = capturedImage {
                PackagingPromptView(
                    capturedImage: image,
                    onScanLabel: {
                        showingLabelCamera = true
                    },
                    onSkipToAI: {
                        // Go directly to NutritionReviewView with first prediction
                        nutritionReviewPrediction = predictions.first
                    }
                )
            }
        }
        // PredictionsView removed - now go directly to NutritionReviewView
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
                onTextEntryTap: {
                    showingLabelCamera = false
                }
            )
            .onDisappear {
                // If label scanning dismissed without capture, show nutrition review
                if nutritionLabelImage == nil && !predictions.isEmpty && nutritionReviewPrediction == nil {
                    nutritionReviewPrediction = predictions.first
                }
            }
        }
        .alert("No Food Detected", isPresented: $showingNoFoodAlert) {
            Button("Try Again", role: .cancel) {
                capturedImage = nil
                predictions = []
            }
            Button("Describe with Text") {
                showingTextEntry = true
            }
        } message: {
            Text("We couldn't identify any food in this image. Try taking another photo with better lighting, or describe your meal with text.")
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
                // No packaging, go straight to nutrition review
                nutritionReviewPrediction = predictions.first
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

        // After label scan, go directly to nutrition review with first prediction
        nutritionReviewPrediction = predictions.first
    }
}

// MARK: - Gallery Picker

struct GalleryPicker: UIViewControllerRepresentable {
    @Environment(\.dismiss) var dismiss
    let onImageSelected: (UIImage) -> Void
    let onLoadingStarted: () -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        config.preferredAssetRepresentationMode = .current // Ensures full-quality image from iCloud
        config.selection = .default // Single-select appearance (not ordered)
        config.mode = .default // Compact UI for single selection

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: GalleryPicker

        init(_ parent: GalleryPicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let provider = results.first?.itemProvider else {
                parent.dismiss()
                return
            }

            // Show loading indicator immediately before dismissing
            DispatchQueue.main.async {
                self.parent.onLoadingStarted()
            }

            // Dismiss picker
            parent.dismiss()

            // Load full-quality image (waits for iCloud download if needed)
            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { image, error in
                    if let error = error {
                        print("❌ Error loading image from picker: \(error.localizedDescription)")
                        DispatchQueue.main.async {
                            // Reset loading state on error
                            self.parent.onImageSelected(UIImage()) // This will trigger cleanup
                        }
                        return
                    }

                    if let image = image as? UIImage {
                        DispatchQueue.main.async {
                            print("✅ Loaded full-quality image from gallery: \(Int(image.size.width))x\(Int(image.size.height))")
                            self.parent.onImageSelected(image)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Predictions View

// MARK: - PredictionsView removed (merged into NutritionReviewView)
// Users now see AI prediction directly in the review screen

#Preview {
    QuickAddMealView(selectedDate: Date())
        .modelContainer(PreviewContainer().container)
}
