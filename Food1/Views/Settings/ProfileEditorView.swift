//
//  ProfileEditorView.swift
//  Food1
//
//  Created by Claude on 2025-11-03.
//

import SwiftUI

struct ProfileEditorView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var age: Int
    @Binding var weight: Double
    @Binding var height: Double
    @Binding var gender: Gender
    @Binding var activityLevel: ActivityLevel
    @Binding var weightUnit: WeightUnit
    @Binding var heightUnit: HeightUnit

    @State private var ageText: String
    @State private var weightText: String
    @State private var heightText: String

    init(age: Binding<Int>, weight: Binding<Double>, height: Binding<Double>, gender: Binding<Gender>, activityLevel: Binding<ActivityLevel>, weightUnit: Binding<WeightUnit>, heightUnit: Binding<HeightUnit>) {
        self._age = age
        self._weight = weight
        self._height = height
        self._gender = gender
        self._activityLevel = activityLevel
        self._weightUnit = weightUnit
        self._heightUnit = heightUnit

        // Initialize state with current values
        self._ageText = State(initialValue: age.wrappedValue > 0 ? "\(age.wrappedValue)" : "")
        self._weightText = State(initialValue: weight.wrappedValue > 0 ? String(format: "%.1f", weight.wrappedValue) : "")
        self._heightText = State(initialValue: height.wrappedValue > 0 ? String(format: "%.0f", height.wrappedValue) : "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Age")
                            .frame(width: 80, alignment: .leading)
                        TextField("25", text: $ageText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                        Text("years")
                            .foregroundColor(.secondary)
                    }

                    Picker("Gender", selection: $gender) {
                        ForEach(Gender.allCases) { g in
                            HStack {
                                Image(systemName: g.icon)
                                Text(g.rawValue)
                            }
                            .tag(g)
                        }
                    }
                } header: {
                    Text("Basic Info")
                }

                Section {
                    HStack {
                        Text("Weight")
                            .frame(width: 80, alignment: .leading)
                        TextField("70", text: $weightText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Picker("", selection: $weightUnit) {
                            ForEach(WeightUnit.allCases) { unit in
                                Text(unit.rawValue).tag(unit)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 70)
                    }

                    HStack {
                        Text("Height")
                            .frame(width: 80, alignment: .leading)
                        TextField("170", text: $heightText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Picker("", selection: $heightUnit) {
                            ForEach(HeightUnit.allCases) { unit in
                                Text(unit.rawValue).tag(unit)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 70)
                    }
                } header: {
                    Text("Measurements")
                }

                Section {
                    Picker("Activity Level", selection: $activityLevel) {
                        ForEach(ActivityLevel.allCases) { level in
                            VStack(alignment: .leading) {
                                Text(level.rawValue)
                                Text(level.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .tag(level)
                        }
                    }
                    .pickerStyle(.navigationLink)

                    HStack {
                        Image(systemName: activityLevel.icon)
                            .foregroundColor(.purple)
                            .frame(width: 24)
                        Text(activityLevel.description)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Activity")
                } footer: {
                    Text("Your activity level helps calculate your daily calorie needs.")
                }
            }
            .navigationTitle("Your Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveProfile()
                        dismiss()
                    }
                    .bold()
                }
            }
        }
    }

    private func saveProfile() {
        // Save age
        if let ageValue = Int(ageText), ageValue > 0 {
            age = ageValue
        }

        // Save weight
        if let weightValue = Double(weightText), weightValue > 0 {
            weight = weightValue
        }

        // Save height
        if let heightValue = Double(heightText), heightValue > 0 {
            height = heightValue
        }
    }
}
