//
//  QuickAddMealView.swift
//  Food1
//
//  Coordinator view that manages the quick add meal flow based on entry mode:
//  - Camera: Custom camera → Photo capture → Recognition → Review → Save
//  - Gallery: Photo picker → Preview/Crop → Recognition → Review → Save
//  - Text: Direct text entry → Save
//
//  WHY THIS ARCHITECTURE:
//  - Each entry mode has its own dedicated flow - no unnecessary camera loading
//  - Camera mode: Custom AVFoundation camera with integrated gallery/manual buttons
//  - Gallery mode: Direct photo picker without camera initialization
//  - Text mode: Immediate TextEntryView - simplest, fastest path
//  - Blurred photo background during recognition shows context without distraction
//  - Rotating sparkles + dynamic messages make 2-5s API wait feel shorter
//  - No artificial delays - results shown as soon as API responds
//

import SwiftUI
import SwiftData
struct QuickAddMealView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext

    let selectedDate: Date
    let initialEntryMode: MealEntryMode

    @StateObject private var recognitionService = FoodRecognitionService()

    // Navigation state for gallery flow
    @State private var showingGalleryPicker = true   // Controls gallery picker sheet (starts true for gallery mode)
    @State private var showingPhotoPreview = false   // Lightweight preview for quick submit (90% case)
    @State private var showingCropView = false       // Crop view for focused selection (10% case)
    @State private var selectedGalleryImage: UIImage?
    @State private var showingPackagingPrompt = false
    @State private var showingNoFoodAlert = false
    @State private var nutritionReviewPrediction: FoodRecognitionService.FoodPrediction? = nil

    // Recognition data
    @State private var capturedImage: UIImage?
    @State private var photoTimestamp: Date?  // EXIF timestamp from photo
    @State private var predictions: [FoodRecognitionService.FoodPrediction] = []
    @State private var hasPackaging = false
    @State private var showingLabelCamera = false
    @State private var nutritionLabelImage: UIImage?
    @State private var labelData: NutritionLabelData?
    @State private var currentMessageIndex = 0  // For rotating loading messages
    @State private var rotationAngle: Double = 0  // For custom spinner animation

    // Accessibility
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        Group {
            switch initialEntryMode {
            case .text:
                // Text mode: Direct to TextEntryView - no camera, no sheets
                TextEntryView(
                    selectedDate: selectedDate,
                    onMealCreated: { dismiss() },
                    onCancel: { dismiss() }  // Explicit cancel to ensure proper fullScreenCover dismissal
                )

            case .gallery:
                // Gallery mode: Start with photo picker, not camera
                galleryFlowView

            case .camera:
                // Camera mode: Full camera flow with recognition
                cameraFlowView

            case .fasting:
                // Fasting is handled in MainTabView before QuickAddMealView opens
                // This case should never be reached, but Swift requires exhaustive switches
                EmptyView()
                    .onAppear { dismiss() }
            }
        }
        // Shared sheets for recognition flows (camera & gallery)
        .sheet(isPresented: $showingPackagingPrompt) {
            if let image = capturedImage {
                PackagingPromptView(
                    capturedImage: image,
                    onScanLabel: {
                        showingLabelCamera = true
                    },
                    onSkipToAI: {
                        nutritionReviewPrediction = predictions.first
                    }
                )
            }
        }
        .sheet(item: $nutritionReviewPrediction) { prediction in
            NutritionReviewView(
                selectedDate: selectedDate,
                foodName: prediction.displayName,
                capturedImage: capturedImage,
                prediction: prediction,
                prefilledCalories: labelData?.nutrition.calories ?? prediction.calories,
                prefilledProtein: labelData?.nutrition.protein ?? prediction.protein,
                prefilledCarbs: labelData?.nutrition.carbs ?? prediction.carbs,
                prefilledFat: labelData?.nutrition.fat ?? prediction.fat,
                prefilledEstimatedGrams: labelData?.estimatedGrams ?? prediction.estimatedGrams,
                photoTimestamp: photoTimestamp
            )
            .onDisappear {
                dismiss()
            }
        }
        .sheet(isPresented: $showingLabelCamera) {
            CustomCameraView(
                selectedDate: selectedDate,
                onPhotoCaptured: { labelImage, _ in
                    nutritionLabelImage = labelImage
                    showingLabelCamera = false
                    Task {
                        await analyzeNutritionLabel()
                    }
                },
                onGalleryTap: { },
                onTextEntryTap: {
                    showingLabelCamera = false
                }
            )
            .onDisappear {
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
        } message: {
            Text("We couldn't identify any food in this image. Try taking another photo with better lighting.")
        }
    }

    // MARK: - Camera Flow
    private var cameraFlowView: some View {
        ZStack {
            // Show camera only if we haven't captured a photo yet
            if capturedImage == nil {
                CustomCameraView(
                    selectedDate: selectedDate,
                    onPhotoCaptured: { image, timestamp in
                        handlePhotoCaptured(image, timestamp: timestamp)
                    },
                    onGalleryTap: { },  // Not used - gallery accessed via menu
                    onTextEntryTap: { } // Not used - text accessed via menu
                )
            } else {
                // Show captured photo as static background once captured
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
    }

    // MARK: - Gallery Flow
    private var galleryFlowView: some View {
        ZStack {
            // Background color while gallery is open
            Color(.systemBackground)
                .ignoresSafeArea()

            // Show captured photo background during recognition
            if let image = capturedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
            }

            // Loading overlay during recognition
            if recognitionService.isProcessing {
                recognitionLoadingOverlay
            }
        }
        .sheet(isPresented: $showingGalleryPicker, onDismiss: {
            // If dismissed without selecting an image, close the entire flow
            if selectedGalleryImage == nil && capturedImage == nil {
                dismiss()
            } else if selectedGalleryImage != nil {
                // Image selected - show preview after brief delay
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(300))
                    showingPhotoPreview = true
                }
            }
        }) {
            GalleryPicker { image in
                selectedGalleryImage = image
                showingGalleryPicker = false
            }
        }
        .sheet(isPresented: $showingPhotoPreview) {
            if let image = selectedGalleryImage {
                PhotoPreviewSheet(
                    image: image,
                    onAnalyze: { finalImage in
                        showingPhotoPreview = false
                        handlePhotoCaptured(finalImage, timestamp: nil)
                    },
                    onRequestCrop: {
                        showingPhotoPreview = false
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
                        handlePhotoCaptured(croppedImage, timestamp: nil)
                    }
                )
                .interactiveDismissDisabled(true)
            }
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
                        .font(DesignSystem.Typography.semiBold(size: 18))
                        .foregroundColor(.primary)
                        .id(currentMessageIndex)
                        .transition(.opacity)

                    Text(loadingMessages[currentMessageIndex].subtitle)
                        .font(DesignSystem.Typography.regular(size: 15))
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

    private func handlePhotoCaptured(_ image: UIImage, timestamp: Date?) {
        capturedImage = image
        photoTimestamp = timestamp

        // Clear previous state when starting new recognition
        labelData = nil
        currentMessageIndex = 0  // Reset message rotation

        print("📸 New photo captured - cleared previous state")
        if let timestamp = timestamp {
            print("📸 Photo timestamp: \(timestamp)")
        }

        Task {
            // Start recognition immediately - show real progress, no artificial delay
            let processedImage = recognitionService.preprocessImage(image)
            let (results, hasPackaging) = await recognitionService.recognizeFood(in: processedImage)

            predictions = results
            self.hasPackaging = hasPackaging

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
//
// Uses UIImagePickerController for optimal single-photo selection UX:
// - Tap photo → immediately dismisses (no "Add" button required)
// - Built-in iCloud download progress indicator
// - Familiar, intuitive user experience
//
// PHPicker requires tap + "Add" button even for single selection,
// which feels like multi-select and adds friction.

struct GalleryPicker: UIViewControllerRepresentable {
    @Environment(\.dismiss) var dismiss
    let onImageSelected: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = context.coordinator
        picker.allowsEditing = false
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
            // Dismiss picker immediately for responsive UX
            parent.dismiss()

            // Extract the selected image
            if let image = info[.originalImage] as? UIImage {
                print("✅ Selected image from gallery: \(Int(image.size.width))x\(Int(image.size.height))")
                DispatchQueue.main.async {
                    self.parent.onImageSelected(image)
                }
            } else {
                print("❌ Failed to get image from picker")
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Predictions View

// MARK: - PredictionsView removed (merged into NutritionReviewView)
// Users now see AI prediction directly in the review screen

#Preview {
    QuickAddMealView(selectedDate: Date(), initialEntryMode: .camera)
        .modelContainer(PreviewContainer().container)
}
