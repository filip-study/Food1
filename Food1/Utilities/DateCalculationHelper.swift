//
//  DateCalculationHelper.swift
//  Food1
//
//  Safe Calendar date operations that eliminate force unwraps.
//  Provides fallback behavior instead of crashing when date calculations fail.
//
//  WHY THIS EXISTS:
//  - Calendar.date(byAdding:...) returns Optional<Date> and can fail
//  - Force unwrapping these can cause production crashes
//  - Edge cases: timezone changes, daylight saving, calendar anomalies
//  - This extension provides safe alternatives with sensible fallbacks
//

import Foundation

extension Calendar {

    // MARK: - Safe Date Addition

    /// Safely add date components, returning original date if calculation fails
    /// Use this instead of: Calendar.current.date(byAdding: .day, value: 1, to: date)!
    func safeDate(byAdding component: Calendar.Component, value: Int, to date: Date) -> Date {
        self.date(byAdding: component, value: value, to: date) ?? date
    }

    /// Safely add DateComponents, returning original date if calculation fails
    func safeDate(byAdding components: DateComponents, to date: Date) -> Date {
        self.date(byAdding: components, to: date) ?? date
    }

    // MARK: - Safe Date From Components

    /// Safely create a date from components, returning fallback date if creation fails
    /// Use this instead of: calendar.date(from: components)!
    func safeDate(from components: DateComponents, fallback: Date = Date()) -> Date {
        self.date(from: components) ?? fallback
    }

    /// Safely set hour/minute/second on a date
    /// Use this instead of: calendar.date(bySettingHour: 8, minute: 0, second: 0, of: now)!
    func safeDate(bySettingHour hour: Int, minute: Int, second: Int, of date: Date) -> Date {
        self.date(bySettingHour: hour, minute: minute, second: second, of: date) ?? date
    }

    // MARK: - Safe Date Intervals

    /// Safely get the start of a calendar interval (week, month, etc.)
    /// Use this instead of: calendar.dateInterval(of: .weekOfYear, for: date)!.start
    func safeStartOfInterval(_ component: Calendar.Component, for date: Date) -> Date {
        self.dateInterval(of: component, for: date)?.start ?? date
    }

    /// Safely get a date interval, returning a zero-length interval if calculation fails
    func safeDateInterval(of component: Calendar.Component, for date: Date) -> DateInterval {
        self.dateInterval(of: component, for: date) ?? DateInterval(start: date, duration: 0)
    }
}

// MARK: - Date Extension for Common Operations

extension Date {

    /// Add days safely using Calendar.current
    func addingDays(_ days: Int) -> Date {
        Calendar.current.safeDate(byAdding: .day, value: days, to: self)
    }

    /// Add months safely using Calendar.current
    func addingMonths(_ months: Int) -> Date {
        Calendar.current.safeDate(byAdding: .month, value: months, to: self)
    }

    /// Add years safely using Calendar.current
    func addingYears(_ years: Int) -> Date {
        Calendar.current.safeDate(byAdding: .year, value: years, to: self)
    }

    /// Add hours safely using Calendar.current
    func addingHours(_ hours: Int) -> Date {
        Calendar.current.safeDate(byAdding: .hour, value: hours, to: self)
    }

    /// Get the start of the week containing this date
    var startOfWeek: Date {
        Calendar.current.safeStartOfInterval(.weekOfYear, for: self)
    }

    /// Get the start of the month containing this date
    var startOfMonth: Date {
        Calendar.current.safeStartOfInterval(.month, for: self)
    }
}
