//
//  UserProfile.swift
//  Food1
//
//  Created by Claude on 2025-11-03.
//

import SwiftUI

enum Gender: String, CaseIterable, Identifiable {
    case male = "Male"
    case female = "Female"
    case other = "Other"
    case preferNotToSay = "Prefer not to say"

    var id: String { self.rawValue }

    var icon: String {
        switch self {
        case .male:
            return "figure.stand"
        case .female:
            return "figure.stand.dress"
        case .other:
            return "figure.stand"
        case .preferNotToSay:
            return "questionmark.circle"
        }
    }
}

enum ActivityLevel: String, CaseIterable, Identifiable {
    case sedentary = "Sedentary"
    case lightlyActive = "Lightly Active"
    case moderatelyActive = "Moderately Active"
    case veryActive = "Very Active"
    case extremelyActive = "Extremely Active"

    var id: String { self.rawValue }

    var description: String {
        switch self {
        case .sedentary:
            return "Little to no exercise"
        case .lightlyActive:
            return "Light exercise 1-3 days/week"
        case .moderatelyActive:
            return "Moderate exercise 3-5 days/week"
        case .veryActive:
            return "Hard exercise 6-7 days/week"
        case .extremelyActive:
            return "Very hard exercise & physical job"
        }
    }

    var icon: String {
        switch self {
        case .sedentary:
            return "figure.seated.side"
        case .lightlyActive:
            return "figure.walk"
        case .moderatelyActive:
            return "figure.hiking"
        case .veryActive:
            return "figure.run"
        case .extremelyActive:
            return "figure.strengthtraining.traditional"
        }
    }
}

enum WeightUnit: String, CaseIterable, Identifiable {
    case kg = "kg"
    case lbs = "lbs"

    var id: String { self.rawValue }
}

enum HeightUnit: String, CaseIterable, Identifiable {
    case cm = "cm"
    case ft = "ft"

    var id: String { self.rawValue }
}
