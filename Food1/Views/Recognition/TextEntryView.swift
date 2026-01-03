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
    @Environment(\.colorScheme) private var colorScheme

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
        ("Reading your description", "Understanding ingredients and portions"),
        ("Calculating nutrition", "Estimating calories and macros"),
        ("Almost ready", "Finalizing your meal breakdown")
    ]

    // Example meals with concise tips
    private let exampleMeals: [(text: String, tip: String)] = [
        ("2 large eggs scrambled with butter and 2 strips of crispy bacon", "Include quantities"),
        ("6oz grilled chicken breast with 1 cup steamed rice", "Specify weights"),
        ("Large bowl of oatmeal with banana, honey, and almonds", "Describe portions"),
        ("Turkey sandwich on whole wheat with lettuce, tomato, and cheese", "List ingredients"),
        ("Greek yogurt with mixed berries and granola", "Be specific"),
        ("Salmon filet pan-seared with olive oil and quinoa", "Add cooking method"),
        ("Protein shake with banana, peanut butter, and almond milk", "Mention additions"),
        ("Bowl of spaghetti with meat sauce and parmesan", "Estimate amounts")
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                backgroundGradient

                // Main content
                ScrollView {
                    VStack(spacing: 24) {
                        // Text input area
                        textInputSection
                            .padding(.horizontal, 20)
                            .padding(.top, 16)

                        // Example hint
                        if showExamples {
                            exampleHint
                                .padding(.horizontal, 20)
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }

                        Spacer(minLength: 120)
                    }
                }

                // CTA Button (fixed at bottom)
                VStack {
                    Spacer()
                    analyzeButton
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)
                }

                // Loading overlay
                if isAnalyzing {
                    loadingOverlay
                        .transition(.opacity)
                }

                // Error alert
                if showError, let error = errorMessage {
                    errorBanner(message: error)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .navigationTitle("Describe Meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if let onCancel = onCancel {
                            onCancel()
                        } else {
                            dismiss()
                        }
                    }
                    .foregroundColor(.secondary)
                }
            }
            .onAppear {
                // Focus the text field automatically
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(400))
                    textFieldFocused = true
                }

                // Show examples after a delay
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(2))
                    withAnimation(.easeOut(duration: 0.4)) {
                        showExamples = true
                    }
                    startExampleRotation()
                }

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
                        userPrompt: mealDescription
                    )
                    .onDisappear {
                        dismiss()
                        onMealCreated()
                    }
                }
            }
        }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        LinearGradient(
            colors: colorScheme == .light
                ? [Color(.systemBackground), Color.blue.opacity(0.03)]
                : [Color(.systemBackground), Color.blue.opacity(0.05)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: - Text Input Section

    private var textInputSection: some View {
        VStack(spacing: 12) {
            // Main input container
            HStack(alignment: .top, spacing: 0) {
                // Text field
                TextField("What did you eat?", text: $mealDescription, axis: .vertical)
                    .font(.system(size: 18, weight: .regular))
                    .focused($textFieldFocused)
                    .lineLimit(3...6)
                    .padding(.leading, 20)
                    .padding(.trailing, 8)
                    .padding(.vertical, 18)
                    .onChange(of: mealDescription) { oldValue, newValue in
                        if newValue.count > maxCharacterLimit {
                            mealDescription = String(newValue.prefix(maxCharacterLimit))
                            HapticManager.light()
                        }
                    }

                // Mic button
                micButton
                    .padding(.trailing, 12)
                    .padding(.top, 12)
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        textFieldFocused
                            ? LinearGradient(
                                colors: [ColorPalette.accentPrimary.opacity(0.5), ColorPalette.accentSecondary.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                              )
                            : LinearGradient(colors: [Color.clear], startPoint: .top, endPoint: .bottom),
                        lineWidth: 1.5
                    )
            )
            .shadow(
                color: textFieldFocused ? ColorPalette.accentPrimary.opacity(0.08) : .clear,
                radius: 12,
                y: 4
            )

            // Character count
            if showCharacterCount {
                HStack {
                    Spacer()
                    Text("\(characterCount)/\(maxCharacterLimit)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(characterCount >= maxCharacterLimit ? .red : .secondary)
                }
                .padding(.horizontal, 4)
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.2), value: textFieldFocused)
        .animation(.easeOut(duration: 0.2), value: showCharacterCount)
    }

    // MARK: - Mic Button

    private var micButton: some View {
        Button(action: {
            if isRecording {
                stopRecording()
            } else {
                startVoiceInput()
            }
        }) {
            ZStack {
                // Background circle
                Circle()
                    .fill(
                        isRecording
                            ? Color.red.opacity(0.15)
                            : (colorScheme == .light ? Color(.systemGray6) : Color(.systemGray5))
                    )
                    .frame(width: 44, height: 44)

                // Pulsing ring when recording
                if isRecording {
                    Circle()
                        .stroke(Color.red.opacity(0.3), lineWidth: 2)
                        .frame(width: 44, height: 44)
                        .scaleEffect(isRecording ? 1.3 : 1.0)
                        .opacity(isRecording ? 0 : 1)
                        .animation(
                            .easeOut(duration: 1.0).repeatForever(autoreverses: false),
                            value: isRecording
                        )
                }

                Image(systemName: isRecording ? "waveform" : "mic.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(isRecording ? .red : ColorPalette.accentPrimary)
                    .symbolEffect(.variableColor.iterative, options: .repeating, value: isRecording)
            }
        }
        .opacity(hasMicrophonePermission ? 1.0 : 0.4)
        .disabled(!hasMicrophonePermission)
        .buttonStyle(.plain)
    }

    // MARK: - Example Hint

    private var exampleHint: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Tip label
            HStack(spacing: 6) {
                Image(systemName: "sparkle")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(ColorPalette.accentSecondary)

                Text(exampleMeals[currentExampleIndex].tip)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
            }

            // Example text
            Text(exampleMeals[currentExampleIndex].text)
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(.secondary.opacity(0.8))
                .lineLimit(2)
                .id("example-\(currentExampleIndex)")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(colorScheme == .light
                    ? Color(.systemGray6).opacity(0.7)
                    : Color(.systemGray6).opacity(0.3)
                )
        )
    }

    // MARK: - Analyze Button

    private var analyzeButton: some View {
        Button(action: analyzeMeal) {
            HStack(spacing: 10) {
                Text("Analyze")
                    .font(.system(size: 17, weight: .semibold))

                Image(systemName: "sparkles")
                    .font(.system(size: 15, weight: .medium))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                Group {
                    if isInputValid {
                        LinearGradient(
                            colors: [ColorPalette.accentPrimary, ColorPalette.accentSecondary],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    } else {
                        Color(.systemGray4)
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(
                color: isInputValid ? ColorPalette.accentPrimary.opacity(0.3) : .clear,
                radius: 12,
                y: 6
            )
        }
        .disabled(!isInputValid)
        .animation(.easeOut(duration: 0.2), value: isInputValid)
    }

    // MARK: - Loading Overlay

    private var loadingOverlay: some View {
        ZStack {
            // Blurred background
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .background(.ultraThinMaterial)

            // Loading card
            VStack(spacing: 28) {
                // Animated sparkles
                Image(systemName: "sparkles")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [ColorPalette.accentPrimary, ColorPalette.accentSecondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .symbolEffect(.pulse.byLayer, options: .repeating, value: isAnalyzing)

                VStack(spacing: 6) {
                    Text(loadingMessages[currentLoadingMessageIndex].title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)

                    Text(loadingMessages[currentLoadingMessageIndex].subtitle)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .id(currentLoadingMessageIndex)
                .transition(.opacity)
            }
            .padding(.horizontal, 36)
            .padding(.vertical, 32)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThickMaterial)
            )
            .shadow(color: .black.opacity(0.2), radius: 30, y: 10)
        }
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { _ in
                guard isAnalyzing else { return }
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentLoadingMessageIndex = (currentLoadingMessageIndex + 1) % loadingMessages.count
                }
            }
        }
    }

    // MARK: - Error Banner

    private func errorBanner(message: String) -> some View {
        VStack {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Couldn't analyze meal")
                        .font(.system(size: 15, weight: .semibold))

                    Text(message)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: { withAnimation { showError = false } }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color(.systemGray5)))
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.1), radius: 12, y: 4)
            .padding(.horizontal, 16)
            .padding(.top, 8)

            Spacer()
        }
    }

    // MARK: - Example Rotation

    private func startExampleRotation() {
        exampleTimer?.invalidate()
        exampleTimer = Timer.scheduledTimer(withTimeInterval: 12.0, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.4)) {
                currentExampleIndex = (currentExampleIndex + 1) % exampleMeals.count
            }
        }
    }

    private func stopExampleRotation() {
        exampleTimer?.invalidate()
        exampleTimer = nil
    }

    // MARK: - Actions

    private func analyzeMeal() {
        guard isInputValid else { return }

        HapticManager.medium()
        textFieldFocused = false

        Task {
            isAnalyzing = true
            currentLoadingMessageIndex = 0

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

        recognitionTask?.cancel()
        recognitionTask = nil

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
