//
//  AddMealTabView.swift
//  Food1
//
//  Created by Claude on 2025-11-04.
//

import SwiftUI
import SwiftData

/// Tabbed interface for adding meals: Photo recognition or Manual entry
struct AddMealTabView: View {
    @Environment(\.dismiss) var dismiss

    let selectedDate: Date
    let editingMeal: Meal?

    @State private var selectedTab: Tab = .photo

    enum Tab: String, CaseIterable {
        case photo = "Photo"
        case manual = "Manual"
    }

    init(selectedDate: Date, editingMeal: Meal? = nil) {
        self.selectedDate = selectedDate
        self.editingMeal = editingMeal

        // If editing, default to manual tab
        _selectedTab = State(initialValue: editingMeal != nil ? .manual : .photo)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab picker
                Picker("Input Method", selection: $selectedTab) {
                    ForEach(Tab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                // Tab content
                TabView(selection: $selectedTab) {
                    PhotoRecognitionTab(selectedDate: selectedDate)
                        .tag(Tab.photo)

                    ManualEntryTab(selectedDate: selectedDate, editingMeal: editingMeal)
                        .tag(Tab.manual)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .navigationTitle(editingMeal != nil ? "Edit Meal" : "Add Meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Photo Recognition Tab
struct PhotoRecognitionTab: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext

    let selectedDate: Date

    @StateObject private var recognitionService = FoodRecognitionService()

    @State private var showingSourcePicker = false
    @State private var showingCamera = false
    @State private var selectedSourceType: UIImagePickerController.SourceType = .camera

    @State private var capturedImage: UIImage?
    @State private var predictions: [FoodRecognitionService.FoodPrediction] = []
    @State private var selectedPrediction: FoodRecognitionService.FoodPrediction?
    @State private var hasPackaging = false

    @State private var showingNutritionReview = false
    @State private var showingPackagingAlert = false
    @State private var showingLabelCamera = false
    @State private var nutritionLabelImage: UIImage?
    @State private var labelData: NutritionLabelData?

    var body: some View {
        ZStack {
            if capturedImage == nil {
                // Initial state - prompt to take photo
                capturePromptView
            } else if predictions.isEmpty && !recognitionService.isProcessing {
                // No predictions found
                noPredictionsView
            } else {
                // Show predictions
                predictionsView
            }

            // Loading overlay
            if recognitionService.isProcessing {
                loadingOverlay
            }
        }
        .sheet(isPresented: $showingSourcePicker) {
            PhotoSourcePicker { sourceType in
                selectedSourceType = sourceType
                showingCamera = true
            }
        }
        .sheet(isPresented: $showingCamera) {
            CameraPicker(sourceType: selectedSourceType) { image in
                capturedImage = image
                Task {
                    await recognizeFood()
                }
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
            }
        }
        .sheet(isPresented: $showingLabelCamera) {
            CameraPicker(sourceType: .camera) { image in
                nutritionLabelImage = image
                Task {
                    await analyzeNutritionLabel()
                }
            }
        }
        .alert("Packaged Food Detected", isPresented: $showingPackagingAlert) {
            Button("Skip", role: .cancel) {
                // User chooses not to scan label
                showingPackagingAlert = false
            }
            Button("Scan Label") {
                // User wants to scan nutrition label
                showingLabelCamera = true
            }
        } message: {
            Text("This appears to be packaged food. Would you like to take a photo of the nutrition label for more accurate data?")
        }
        .onAppear {
            if capturedImage == nil {
                showingSourcePicker = true
            }
        }
    }

    // MARK: - Subviews
    private var capturePromptView: some View {
        VStack(spacing: 24) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 80))
                .foregroundStyle(.gray.opacity(0.5))

            VStack(spacing: 8) {
                Text("Take a Photo")
                    .font(.system(size: 24, weight: .bold))

                Text("Capture your meal to automatically recognize it")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: {
                showingSourcePicker = true
            }) {
                HStack {
                    Image(systemName: "camera.fill")
                    Text("Add Photo")
                }
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.blue)
                .cornerRadius(12)
            }
            .padding(.horizontal, 40)
        }
    }

    private var noPredictionsView: some View {
        VStack(spacing: 24) {
            if let image = capturedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 200)
                    .cornerRadius(12)
            }

            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundStyle(.orange.opacity(0.7))

            VStack(spacing: 8) {
                Text("No Food Detected")
                    .font(.system(size: 20, weight: .bold))

                Text(recognitionService.errorMessage ?? "We couldn't recognize any food in this image. Try taking another photo with better lighting.")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button(action: {
                capturedImage = nil
                predictions = []
                showingSourcePicker = true
            }) {
                Text("Try Again")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 24)
        }
    }

    private var predictionsView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Captured image
                if let image = capturedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 250)
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                        .padding(.horizontal)
                }

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
                                selectedPrediction = prediction
                                showingNutritionReview = true
                            }
                        }
                    }
                    .padding(.horizontal)
                }

                // Retry option
                Button(action: {
                    capturedImage = nil
                    predictions = []
                    showingSourcePicker = true
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
            .padding(.top)
        }
    }

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)

                Text("Recognizing food...")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.white)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
            )
            .shadow(color: .black.opacity(0.3), radius: 20)
        }
    }

    // MARK: - Actions
    private func recognizeFood() async {
        guard let image = capturedImage else { return }

        let processedImage = recognitionService.preprocessImage(image)
        let (results, hasPackaging) = await recognitionService.recognizeFood(in: processedImage)

        predictions = results
        self.hasPackaging = hasPackaging

        // Show packaging alert if packaging detected and we have predictions
        if hasPackaging && !predictions.isEmpty {
            showingPackagingAlert = true
        }
    }

    private func analyzeNutritionLabel() async {
        guard let labelImage = nutritionLabelImage else { return }

        let extractedData = await recognitionService.analyzeNutritionLabel(in: labelImage)

        if let data = extractedData {
            labelData = data
            print("✅ Successfully extracted label data: \(data.productName ?? "Unknown")")

            // Update predictions with more accurate nutrition from label
            // For now, the NutritionReviewView will use labelData if available
        } else {
            print("❌ Failed to extract label data")
        }
    }
}

// MARK: - Manual Entry Tab
struct ManualEntryTab: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext

    let selectedDate: Date
    let editingMeal: Meal?

    @State private var mealName = ""
    @State private var selectedEmoji = "🍽️"
    @State private var calories = ""
    @State private var protein = ""
    @State private var carbs = ""
    @State private var fat = ""
    @State private var notes = ""

    private let emojiOptions = ["🥗", "🍎", "🥣", "🍳", "🥪", "🍕", "🍔", "🌮", "🍜", "🍱", "🐟", "🥤", "☕", "🍰", "🥐", "🍽️"]

    private var isEditMode: Bool {
        editingMeal != nil
    }

    init(selectedDate: Date, editingMeal: Meal? = nil) {
        self.selectedDate = selectedDate
        self.editingMeal = editingMeal

        // Initialize state with existing meal values if editing
        if let meal = editingMeal {
            _mealName = State(initialValue: meal.name)
            _selectedEmoji = State(initialValue: meal.emoji)
            _calories = State(initialValue: String(format: "%.0f", meal.calories))
            _protein = State(initialValue: String(format: "%.0f", meal.protein))
            _carbs = State(initialValue: String(format: "%.0f", meal.carbs))
            _fat = State(initialValue: String(format: "%.0f", meal.fat))
            _notes = State(initialValue: meal.notes ?? "")
        }
    }

    var body: some View {
        Form {
            Section("Meal Details") {
                TextField("Meal name", text: $mealName)

                // Emoji picker
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(emojiOptions, id: \.self) { emoji in
                            Button(action: {
                                selectedEmoji = emoji
                            }) {
                                Text(emoji)
                                    .font(.system(size: 32))
                                    .frame(width: 50, height: 50)
                                    .background(
                                        Circle()
                                            .fill(selectedEmoji == emoji ? Color.purple.opacity(0.2) : Color.gray.opacity(0.1))
                                    )
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }

            Section("Nutrition") {
                HStack {
                    Text("Calories")
                    Spacer()
                    TextField("0", text: $calories)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                }

                HStack {
                    Text("Protein (g)")
                    Spacer()
                    TextField("0", text: $protein)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }

                HStack {
                    Text("Carbs (g)")
                    Spacer()
                    TextField("0", text: $carbs)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }

                HStack {
                    Text("Fat (g)")
                    Spacer()
                    TextField("0", text: $fat)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
            }

            Section("Notes (Optional)") {
                TextField("Add any notes...", text: $notes, axis: .vertical)
                    .lineLimit(3...6)
            }

            Section {
                Button(action: {
                    saveMeal()
                }) {
                    Text(isEditMode ? "Save Changes" : "Add Meal")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .disabled(mealName.isEmpty || calories.isEmpty)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
        }
    }

    private func saveMeal() {
        if let existingMeal = editingMeal {
            // Update existing meal
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                existingMeal.name = mealName
                existingMeal.emoji = selectedEmoji
                existingMeal.calories = Double(calories) ?? 0
                existingMeal.protein = Double(protein) ?? 0
                existingMeal.carbs = Double(carbs) ?? 0
                existingMeal.fat = Double(fat) ?? 0
                existingMeal.notes = notes.isEmpty ? nil : notes
            }
        } else {
            // Create new meal
            let newMeal = Meal(
                name: mealName,
                emoji: selectedEmoji,
                timestamp: selectedDate,
                calories: Double(calories) ?? 0,
                protein: Double(protein) ?? 0,
                carbs: Double(carbs) ?? 0,
                fat: Double(fat) ?? 0,
                notes: notes.isEmpty ? nil : notes
            )

            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                modelContext.insert(newMeal)
            }
        }

        dismiss()
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

                        // Show 1-sentence description if available (FastVLM)
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

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
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
    AddMealTabView(selectedDate: Date())
        .modelContainer(PreviewContainer().container)
}
