//
//  TextEntryView.swift
//  Food1
//
//  AI-powered natural language meal entry view.
//  Users type or speak meal descriptions like "3 eggs with mayo and bacon"
//  which are then processed by GPT-4o to extract ingredients and nutrition.
//
//  Flow: Text/Voice Input → AI Processing → NutritionReviewView → Save
//  Reuses the same review screen and data flow as photo-based logging.
//

import SwiftUI
import SwiftData
import Speech

/// Natural language meal entry with AI parsing and optional voice input
struct TextEntryView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext

    let selectedDate: Date
    let onMealCreated: () -> Void
    var onCancel: (() -> Void)? = nil  // Optional cancel callback for embedded usage

    // Text input state
    @State private var mealDescription = ""
    @FocusState private var textFieldFocused: Bool

    // Voice input state
    @State private var isRecording = false
    @State private var speechRecognizer = SFSpeechRecognizer()
    @State private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    @State private var recognitionTask: SFSpeechRecognitionTask?
    @State private var audioEngine = AVAudioEngine()
    @State private var hasMicrophonePermission = false

    // UI state
    @State private var showExamples = false
    @State private var isAnalyzing = false
    @State private var currentLoadingMessageIndex = 0
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var currentExampleIndex = 0
    @State private var exampleTimer: Timer?

    // Navigation state
    @State private var predictions: [FoodRecognitionService.FoodPrediction] = []
    @State private var showingReview = false

    private let maxCharacterLimit = 200

    private var isInputValid: Bool {
        let trimmed = mealDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count >= 5 && trimmed.count <= maxCharacterLimit
    }

    private var characterCount: Int {
        mealDescription.count
    }

    private var showCharacterCount: Bool {
        characterCount >= 160
    }

    private let loadingMessages: [(title: String, subtitle: String)] = [
        ("Analyzing your meal", "Identifying ingredients and portions"),
        ("Understanding quantities", "Interpreting serving sizes and units"),
        ("Calculating nutrition", "Estimating calories, protein, carbs, and fat"),
        ("Almost ready", "Finalizing your meal breakdown")
    ]

    // Verbose examples that demonstrate effective description patterns for better AI accuracy
    // Each example shows: quantities, cooking methods, and specific ingredients
    private let exampleMeals: [(text: String, tip: String)] = [
        ("2 large eggs scrambled with butter and 2 strips of crispy bacon", "Include quantities and cooking style"),
        ("6oz grilled chicken breast with 1 cup steamed rice and roasted broccoli", "Specify weights and portions"),
        ("Large bowl of oatmeal with sliced banana, 2 tbsp honey, and almonds", "Describe size and toppings"),
        ("Turkey sandwich on whole wheat with lettuce, tomato, mayo, and swiss cheese", "List all ingredients"),
        ("Greek yogurt parfait with mixed berries, granola, and a drizzle of honey", "Be specific about components"),
        ("Salmon filet about 5oz pan-seared with olive oil, side of quinoa", "Include cooking method and fats used"),
        ("Protein shake with 1 scoop whey, banana, peanut butter, and almond milk", "Mention all additions"),
        ("Bowl of spaghetti with meat sauce, about 2 cups pasta with parmesan", "Estimate portion sizes")
    ]

    private var accentGradient: LinearGradient {
        LinearGradient(
            colors: [.blue, .cyan],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var clearGradient: LinearGradient {
        LinearGradient(
            colors: [.clear],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                mainContent

                // CTA Button (fixed at bottom)
                VStack {
                    Spacer()

                    Button(action: analyzeMeal) {
                        HStack(spacing: 8) {
                            Text("Analyze with AI")
                                .font(.system(size: 17, weight: .semibold))

                            Image(systemName: "sparkles")
                                .font(.system(size: 14))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            LinearGradient(
                                colors: isInputValid ? [.blue, .cyan] : [.gray, .gray],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(16)
                        .shadow(color: isInputValid ? .blue.opacity(0.3) : .clear, radius: 8, y: 4)
                    }
                    .disabled(!isInputValid)
                    .padding(.horizontal)
                    .padding(.bottom, 16)
                }

                // Loading overlay
                if isAnalyzing {
                    loadingOverlay
                }

                // Error alert
                if showError, let error = errorMessage {
                    errorBanner(message: error)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .navigationTitle("Log Meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        // Use explicit callback if provided (for embedded usage)
                        // Otherwise fall back to environment dismiss
                        if let onCancel = onCancel {
                            onCancel()
                        } else {
                            dismiss()
                        }
                    }
                }
            }
            .onAppear {
                // Show examples after a short delay and start rotation
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(1.5))
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showExamples = true
                    }
                    startExampleRotation()
                }

                // Request microphone permission
                requestMicrophonePermission()
            }
            .onDisappear {
                stopExampleRotation()
            }
            .sheet(isPresented: $showingReview) {
                if let prediction = predictions.first {
                    NutritionReviewView(
                        selectedDate: selectedDate,
                        foodName: prediction.label,
                        capturedImage: nil,
                        prediction: prediction,
                        prefilledCalories: prediction.calories,
                        prefilledProtein: prediction.protein,
                        prefilledCarbs: prediction.carbs,
                        prefilledFat: prediction.fat,
                        prefilledEstimatedGrams: prediction.estimatedGrams,
                        userPrompt: mealDescription  // Store original user input
                    )
                    .onDisappear {
                        dismiss()
                        onMealCreated()
                    }
                }
            }
        }
    }

    // MARK: - Loading Overlay

    private var loadingOverlay: some View {
        ZStack {
            // Blurred background
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            // Loading card
            VStack(spacing: 24) {
                // Rotating sparkles
                Image(systemName: "sparkles")
                    .font(.system(size: 48))
                    .foregroundStyle(.linearGradient(
                        colors: [.blue, .cyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .rotationEffect(.degrees(Double(currentLoadingMessageIndex) * 90))
                    .animation(.linear(duration: 2).repeatForever(autoreverses: false), value: currentLoadingMessageIndex)

                VStack(spacing: 8) {
                    Text(loadingMessages[currentLoadingMessageIndex].title)
                        .font(.system(size: 20, weight: .semibold))

                    Text(loadingMessages[currentLoadingMessageIndex].subtitle)
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(32)
            .background(.ultraThinMaterial)
            .cornerRadius(20)
            .shadow(radius: 20)
        }
        .onAppear {
            // Rotate messages every 2 seconds
            Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
                guard isAnalyzing else { return }
                withAnimation {
                    currentLoadingMessageIndex = (currentLoadingMessageIndex + 1) % loadingMessages.count
                }
            }
        }
    }

    // MARK: - Error Banner

    private func errorBanner(message: String) -> some View {
        VStack {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Couldn't understand meal")
                        .font(.system(size: 15, weight: .semibold))

                    Text(message)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: { withAnimation { showError = false } }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(12)
            .shadow(radius: 8)
            .padding()

            Spacer()
        }
    }

    // MARK: - Subviews

    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header section
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 10) {
                        Image(systemName: "pencil.line")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(accentGradient)

                        Text("Describe your meal")
                            .font(.system(size: 20, weight: .semibold))

                        Spacer()
                    }

                    Text("Include quantities and ingredients for accurate nutrition")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.top, 12)

                // Text input field
                textInputField
                    .padding(.horizontal)

                examplesSection

                Spacer(minLength: 100)
            }
            .padding(.vertical)
        }
    }

    @ViewBuilder
    private var examplesSection: some View {
        if showExamples {
            VStack(alignment: .leading, spacing: 10) {
                // Example text with tip
                HStack(spacing: 6) {
                    Image(systemName: "lightbulb.min.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.orange)

                    Text("Tip: \(exampleMeals[currentExampleIndex].tip.lowercased())")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                }

                Text("\"\(exampleMeals[currentExampleIndex].text)\"")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .italic()
                    .lineLimit(2)
                    .id("example-\(currentExampleIndex)")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            .padding(.horizontal)
            .transition(.opacity)
        }
    }

    private func startExampleRotation() {
        exampleTimer?.invalidate()
        exampleTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                currentExampleIndex = (currentExampleIndex + 1) % exampleMeals.count
            }
        }
    }

    private func stopExampleRotation() {
        exampleTimer?.invalidate()
        exampleTimer = nil
    }

    private var textInputField: some View {
        VStack(spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                TextField("What did you eat?", text: $mealDescription, axis: .vertical)
                    .font(.system(size: 17))
                    .focused($textFieldFocused)
                    .lineLimit(2...5)
                    .padding(.vertical, 2)
                    .onChange(of: mealDescription) { oldValue, newValue in
                        // Enforce character limit
                        if newValue.count > maxCharacterLimit {
                            mealDescription = String(newValue.prefix(maxCharacterLimit))
                            HapticManager.light()
                        }
                    }

                // Voice input button
                Button(action: {
                    if isRecording {
                        stopRecording()
                    } else {
                        startVoiceInput()
                    }
                }) {
                    Image(systemName: isRecording ? "mic.fill" : "mic")
                        .font(.system(size: 20))
                        .foregroundColor(isRecording ? .red : .blue)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .opacity(hasMicrophonePermission ? 1.0 : 0.5)
                .disabled(!hasMicrophonePermission)
            }
            .padding(16)
            .background(Color(.secondarySystemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(textFieldFocused ? accentGradient : clearGradient, lineWidth: 2)
            )
            .cornerRadius(12)

            // Character counter (shown when approaching limit)
            if showCharacterCount {
                HStack {
                    Spacer()
                    Text("\(characterCount)/\(maxCharacterLimit)")
                        .font(.system(size: 13))
                        .foregroundColor(characterCount >= maxCharacterLimit ? .red : .secondary)
                }
                .padding(.horizontal, 4)
            }
        }
    }

    // MARK: - Actions

    private func analyzeMeal() {
        guard isInputValid else { return }

        HapticManager.medium()
        textFieldFocused = false

        Task {
            isAnalyzing = true
            currentLoadingMessageIndex = 0

            // Minimum display time for loading overlay
            let startTime = Date()

            do {
                predictions = try await OpenAIVisionService().analyzeMealText(mealDescription)

                // Ensure minimum 800ms loading time
                let elapsed = Date().timeIntervalSince(startTime)
                if elapsed < 0.8 {
                    try await Task.sleep(nanoseconds: UInt64((0.8 - elapsed) * 1_000_000_000))
                }

                isAnalyzing = false

                if predictions.isEmpty {
                    showErrorMessage("Try adding quantities like '2 eggs' or '100g chicken'")
                } else {
                    HapticManager.success()
                    showingReview = true
                }

            } catch {
                isAnalyzing = false
                showErrorMessage("Please check your internet connection and try again")
            }
        }
    }

    private func showErrorMessage(_ message: String) {
        errorMessage = message
        withAnimation {
            showError = true
        }

        // Auto-dismiss after 6 seconds
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(6))
            withAnimation {
                showError = false
            }
        }
    }

    // MARK: - Voice Input

    private func requestMicrophonePermission() {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                hasMicrophonePermission = (status == .authorized)
            }
        }
    }

    private func startVoiceInput() {
        guard hasMicrophonePermission else {
            requestMicrophonePermission()
            return
        }

        // Cancel any ongoing recognition
        recognitionTask?.cancel()
        recognitionTask = nil

        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try? audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()

        guard let recognitionRequest = recognitionRequest else { return }
        recognitionRequest.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode

        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { result, error in
            if let result = result {
                DispatchQueue.main.async {
                    mealDescription = result.bestTranscription.formattedString
                }
            }

            if error != nil || result?.isFinal == true {
                DispatchQueue.main.async {
                    stopRecording()
                }
            }
        }

        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }

        audioEngine.prepare()
        try? audioEngine.start()

        isRecording = true
        HapticManager.light()
    }

    private func stopRecording() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)

        recognitionRequest?.endAudio()
        recognitionRequest = nil

        recognitionTask?.cancel()
        recognitionTask = nil

        isRecording = false
        HapticManager.light()
    }
}

#Preview {
    TextEntryView(selectedDate: Date(), onMealCreated: {})
        .modelContainer(PreviewContainer().container)
}
