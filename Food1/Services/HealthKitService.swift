//
//  HealthKitService.swift
//  Food1
//
//  Service for reading user health data from Apple HealthKit.
//  Used during onboarding to pre-populate profile data.
//
//  CAPABILITIES:
//  - Read weight, height, biological sex, date of birth
//  - Calculate average daily steps for activity level estimation
//  - No write access - this app only reads from HealthKit
//
//  PRIVACY:
//  - User must explicitly grant permission
//  - All data stays on-device, not sent to servers
//  - Used only for personalization calculations
//

import Foundation
import HealthKit
import Combine
import os.log

private let logger = Logger(subsystem: "com.prismae.food1", category: "HealthKit")

@MainActor
class HealthKitService: ObservableObject {

    // MARK: - Singleton

    static let shared = HealthKitService()

    // MARK: - Health Store

    private let healthStore = HKHealthStore()

    // MARK: - Published State

    @Published private(set) var isAuthorized = false
    @Published private(set) var isLoading = false
    @Published private(set) var weight: Double?        // kg
    @Published private(set) var height: Double?        // cm
    @Published private(set) var biologicalSex: HKBiologicalSex?
    @Published private(set) var dateOfBirth: Date?
    @Published private(set) var averageSteps: Int?     // Last 7 days average

    // MARK: - Computed Properties

    /// Whether HealthKit is available on this device
    var isHealthKitAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    /// Calculate age from date of birth
    var calculatedAge: Int? {
        guard let dob = dateOfBirth else { return nil }
        return Calendar.current.dateComponents([.year], from: dob, to: Date()).year
    }

    /// Convert HKBiologicalSex to our BiologicalSex enum
    var biologicalSexEnum: BiologicalSex? {
        guard let sex = biologicalSex else { return nil }
        switch sex {
        case .male: return .male
        case .female: return .female
        default: return nil  // notSet or other
        }
    }

    /// Estimate activity level from average steps
    var estimatedActivityLevel: SimpleActivityLevel? {
        guard let steps = averageSteps else { return nil }
        return SimpleActivityLevel.fromSteps(steps)
    }

    // MARK: - Initialization

    private init() {}

    // MARK: - Authorization

    /// Types we want to read from HealthKit
    private var typesToRead: Set<HKObjectType> {
        var types = Set<HKObjectType>()

        // Quantity types
        if let bodyMass = HKQuantityType.quantityType(forIdentifier: .bodyMass) {
            types.insert(bodyMass)
        }
        if let height = HKQuantityType.quantityType(forIdentifier: .height) {
            types.insert(height)
        }
        if let stepCount = HKQuantityType.quantityType(forIdentifier: .stepCount) {
            types.insert(stepCount)
        }

        // Characteristic types
        if let biologicalSex = HKCharacteristicType.characteristicType(forIdentifier: .biologicalSex) {
            types.insert(biologicalSex)
        }
        if let dateOfBirth = HKCharacteristicType.characteristicType(forIdentifier: .dateOfBirth) {
            types.insert(dateOfBirth)
        }

        return types
    }

    /// Request authorization to read HealthKit data
    /// Returns true if authorization was granted (or was already granted)
    func requestAuthorization() async throws -> Bool {
        guard isHealthKitAvailable else {
            logger.warning("HealthKit not available on this device")
            return false
        }

        isLoading = true
        defer { isLoading = false }

        do {
            // Request read-only authorization (we don't write to HealthKit)
            try await healthStore.requestAuthorization(toShare: [], read: typesToRead)

            // Note: requestAuthorization doesn't tell us if user granted permission,
            // it just opens the permission dialog. We determine success by trying to read data.
            logger.info("HealthKit authorization request completed")

            // Try to fetch data to confirm we have access
            await fetchAllData()

            // If we got any data, consider it authorized
            isAuthorized = weight != nil || height != nil || biologicalSex != nil || dateOfBirth != nil

            return isAuthorized

        } catch {
            logger.error("HealthKit authorization failed: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Fetch Data

    /// Fetch all available health data
    func fetchAllData() async {
        isLoading = true
        defer { isLoading = false }

        // Fetch characteristic data (synchronous)
        fetchBiologicalSex()
        fetchDateOfBirth()

        // Fetch quantity data (async)
        await fetchWeight()
        await fetchHeight()
        await fetchAverageSteps()

        logger.info("HealthKit data fetch complete - weight: \(self.weight ?? 0), height: \(self.height ?? 0), age: \(self.calculatedAge ?? 0)")
    }

    // MARK: - Fetch Individual Data Types

    /// Fetch biological sex (synchronous, characteristic type)
    private func fetchBiologicalSex() {
        do {
            let sexObject = try healthStore.biologicalSex()
            biologicalSex = sexObject.biologicalSex
        } catch {
            logger.debug("Could not fetch biological sex: \(error.localizedDescription)")
        }
    }

    /// Fetch date of birth (synchronous, characteristic type)
    private func fetchDateOfBirth() {
        do {
            let dobComponents = try healthStore.dateOfBirthComponents()
            if let date = Calendar.current.date(from: dobComponents) {
                dateOfBirth = date
            }
        } catch {
            logger.debug("Could not fetch date of birth: \(error.localizedDescription)")
        }
    }

    /// Fetch most recent weight
    private func fetchWeight() async {
        guard let weightType = HKQuantityType.quantityType(forIdentifier: .bodyMass) else { return }

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(
            sampleType: weightType,
            predicate: nil,
            limit: 1,
            sortDescriptors: [sortDescriptor]
        ) { [weak self] _, samples, error in
            if let error = error {
                logger.debug("Could not fetch weight: \(error.localizedDescription)")
                return
            }

            guard let sample = samples?.first as? HKQuantitySample else { return }

            let weightKg = sample.quantity.doubleValue(for: .gramUnit(with: .kilo))

            Task { @MainActor in
                self?.weight = weightKg
            }
        }

        healthStore.execute(query)

        // Wait a moment for the query to complete
        try? await Task.sleep(for: .milliseconds(500))
    }

    /// Fetch most recent height
    private func fetchHeight() async {
        guard let heightType = HKQuantityType.quantityType(forIdentifier: .height) else { return }

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(
            sampleType: heightType,
            predicate: nil,
            limit: 1,
            sortDescriptors: [sortDescriptor]
        ) { [weak self] _, samples, error in
            if let error = error {
                logger.debug("Could not fetch height: \(error.localizedDescription)")
                return
            }

            guard let sample = samples?.first as? HKQuantitySample else { return }

            let heightCm = sample.quantity.doubleValue(for: .meterUnit(with: .centi))

            Task { @MainActor in
                self?.height = heightCm
            }
        }

        healthStore.execute(query)

        // Wait a moment for the query to complete
        try? await Task.sleep(for: .milliseconds(500))
    }

    /// Fetch average daily steps for the last 7 days
    private func fetchAverageSteps() async {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }

        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        guard let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: startOfToday) else { return }

        let predicate = HKQuery.predicateForSamples(
            withStart: sevenDaysAgo,
            end: now,
            options: .strictStartDate
        )

        // Use statistics query to get the sum, then divide by 7
        let query = HKStatisticsQuery(
            quantityType: stepType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { [weak self] _, statistics, error in
            if let error = error {
                logger.debug("Could not fetch steps: \(error.localizedDescription)")
                return
            }

            guard let sum = statistics?.sumQuantity() else { return }

            let totalSteps = sum.doubleValue(for: .count())
            let averageSteps = Int(totalSteps / 7.0)

            Task { @MainActor in
                self?.averageSteps = averageSteps
            }
        }

        healthStore.execute(query)

        // Wait a moment for the query to complete
        try? await Task.sleep(for: .milliseconds(500))
    }

    // MARK: - Populate Onboarding Data

    /// Populate OnboardingData with fetched HealthKit values
    func populateOnboardingData(_ data: OnboardingData) {
        if let weight = weight {
            data.weightKg = weight
        }
        if let height = height {
            data.heightCm = height
        }
        if let sex = biologicalSexEnum {
            data.biologicalSex = sex
        }
        if let age = calculatedAge {
            data.age = age
        }
        if let activity = estimatedActivityLevel {
            data.activityLevel = activity
            data.useHealthKitActivity = true
        }
    }

    // MARK: - Reset

    /// Clear all fetched data (for testing)
    func reset() {
        isAuthorized = false
        weight = nil
        height = nil
        biologicalSex = nil
        dateOfBirth = nil
        averageSteps = nil
    }
}
