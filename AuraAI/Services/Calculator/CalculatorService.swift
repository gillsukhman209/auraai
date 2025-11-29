//
//  CalculatorService.swift
//  AuraAI
//
//  Created by Claude on 11/28/25.
//

import Foundation

/// Result from calculator detection
struct CalculatorResult {
    let query: String
    let answer: String
    let formattedResponse: String
}

/// Ultra-fast local calculator and unit converter
/// No API calls - instant results
class CalculatorService {

    static let shared = CalculatorService()

    private init() {}

    // MARK: - Main Detection Entry Point

    /// Attempts to detect and calculate a math/conversion query
    /// Returns nil if input doesn't match any pattern (falls through to AI)
    func detect(_ input: String) -> CalculatorResult? {
        let normalized = input.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Try each detector in order of specificity
        if let result = detectPercentage(normalized) { return result }
        if let result = detectTip(normalized) { return result }
        if let result = detectTemperature(normalized) { return result }
        if let result = detectLength(normalized) { return result }
        if let result = detectWeight(normalized) { return result }
        if let result = detectDataSize(normalized) { return result }
        if let result = detectTime(normalized) { return result }
        if let result = detectMathExpression(normalized) { return result }

        return nil
    }

    // MARK: - Percentage Detection

    private func detectPercentage(_ input: String) -> CalculatorResult? {
        // Patterns: "15% of 200", "what's 25% of 80", "20 percent of 500"
        let patterns = [
            #"(?:what'?s?\s+)?(\d+(?:\.\d+)?)\s*%\s*(?:of)\s+(\d+(?:\.\d+)?)"#,
            #"(\d+(?:\.\d+)?)\s*percent\s+(?:of)\s+(\d+(?:\.\d+)?)"#
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: input, range: NSRange(input.startIndex..., in: input)) {

                if let percentRange = Range(match.range(at: 1), in: input),
                   let valueRange = Range(match.range(at: 2), in: input),
                   let percent = Double(input[percentRange]),
                   let value = Double(input[valueRange]) {

                    let result = (percent / 100.0) * value
                    let formatted = formatNumber(result)

                    return CalculatorResult(
                        query: input,
                        answer: formatted,
                        formattedResponse: "\(formatNumber(percent))% of \(formatNumber(value)) = \(formatted)"
                    )
                }
            }
        }
        return nil
    }

    // MARK: - Tip Detection

    private func detectTip(_ input: String) -> CalculatorResult? {
        // Patterns: "20% tip on $85", "tip on 65", "tip for $100", "15% tip on 50"
        let patterns = [
            #"(\d+(?:\.\d+)?)\s*%?\s*tip\s+(?:on|for)\s+\$?(\d+(?:\.\d+)?)"#,
            #"tip\s+(?:on|for)\s+\$?(\d+(?:\.\d+)?)"#
        ]

        // Pattern with percentage specified
        if let regex = try? NSRegularExpression(pattern: patterns[0], options: .caseInsensitive),
           let match = regex.firstMatch(in: input, range: NSRange(input.startIndex..., in: input)) {

            if let percentRange = Range(match.range(at: 1), in: input),
               let amountRange = Range(match.range(at: 2), in: input),
               let percent = Double(input[percentRange]),
               let amount = Double(input[amountRange]) {

                let tip = (percent / 100.0) * amount
                let total = amount + tip

                return CalculatorResult(
                    query: input,
                    answer: formatCurrency(tip),
                    formattedResponse: "\(formatNumber(percent))% tip on \(formatCurrency(amount))\n\nTip: \(formatCurrency(tip))\nTotal: \(formatCurrency(total))"
                )
            }
        }

        // Pattern without percentage (default 20%)
        if let regex = try? NSRegularExpression(pattern: patterns[1], options: .caseInsensitive),
           let match = regex.firstMatch(in: input, range: NSRange(input.startIndex..., in: input)) {

            if let amountRange = Range(match.range(at: 1), in: input),
               let amount = Double(input[amountRange]) {

                let tip15 = amount * 0.15
                let tip18 = amount * 0.18
                let tip20 = amount * 0.20

                return CalculatorResult(
                    query: input,
                    answer: formatCurrency(tip20),
                    formattedResponse: "Tips on \(formatCurrency(amount))\n\n15%: \(formatCurrency(tip15)) (total: \(formatCurrency(amount + tip15)))\n18%: \(formatCurrency(tip18)) (total: \(formatCurrency(amount + tip18)))\n20%: \(formatCurrency(tip20)) (total: \(formatCurrency(amount + tip20)))"
                )
            }
        }

        return nil
    }

    // MARK: - Temperature Detection

    private func detectTemperature(_ input: String) -> CalculatorResult? {
        // Patterns: "72f to c", "25 celsius in fahrenheit", "100°F to °C"
        let patterns = [
            #"(-?\d+(?:\.\d+)?)\s*°?\s*(f|fahrenheit|c|celsius)\s+(?:to|in|=)\s*°?\s*(f|fahrenheit|c|celsius)"#,
            #"(-?\d+(?:\.\d+)?)\s*°(f|c)\b"#  // Just "72°F" - convert to other
        ]

        if let regex = try? NSRegularExpression(pattern: patterns[0], options: .caseInsensitive),
           let match = regex.firstMatch(in: input, range: NSRange(input.startIndex..., in: input)) {

            if let valueRange = Range(match.range(at: 1), in: input),
               let fromRange = Range(match.range(at: 2), in: input),
               let toRange = Range(match.range(at: 3), in: input),
               let value = Double(input[valueRange]) {

                let from = String(input[fromRange]).lowercased()
                let to = String(input[toRange]).lowercased()

                return convertTemperature(value: value, from: from, to: to)
            }
        }

        return nil
    }

    private func convertTemperature(value: Double, from: String, to: String) -> CalculatorResult? {
        let isFromFahrenheit = from.hasPrefix("f")
        let isToFahrenheit = to.hasPrefix("f")

        if isFromFahrenheit == isToFahrenheit {
            return nil // Same unit
        }

        let result: Double
        let fromUnit: String
        let toUnit: String

        if isFromFahrenheit {
            result = (value - 32) * 5 / 9
            fromUnit = "°F"
            toUnit = "°C"
        } else {
            result = (value * 9 / 5) + 32
            fromUnit = "°C"
            toUnit = "°F"
        }

        return CalculatorResult(
            query: "\(formatNumber(value))\(fromUnit) to \(toUnit)",
            answer: "\(formatNumber(result))\(toUnit)",
            formattedResponse: "\(formatNumber(value))\(fromUnit) = \(formatNumber(result))\(toUnit)"
        )
    }

    // MARK: - Length Detection

    private func detectLength(_ input: String) -> CalculatorResult? {
        let units: [(pattern: String, toBase: Double, name: String, symbol: String)] = [
            ("miles?|mi", 1609.344, "miles", "mi"),
            ("kilometers?|km", 1000.0, "kilometers", "km"),
            ("meters?|m(?!i)", 1.0, "meters", "m"),
            ("centimeters?|cm", 0.01, "centimeters", "cm"),
            ("millimeters?|mm", 0.001, "millimeters", "mm"),
            ("feet|ft", 0.3048, "feet", "ft"),
            ("inch(?:es)?|in", 0.0254, "inches", "in"),
            ("yards?|yd", 0.9144, "yards", "yd")
        ]

        return detectUnitConversion(input: input, units: units, category: "length")
    }

    // MARK: - Weight Detection

    private func detectWeight(_ input: String) -> CalculatorResult? {
        let units: [(pattern: String, toBase: Double, name: String, symbol: String)] = [
            ("pounds?|lbs?", 453.592, "pounds", "lb"),
            ("kilograms?|kg", 1000.0, "kilograms", "kg"),
            ("grams?|g(?!b)", 1.0, "grams", "g"),
            ("ounces?|oz", 28.3495, "ounces", "oz"),
            ("stones?|st", 6350.29, "stone", "st")
        ]

        return detectUnitConversion(input: input, units: units, category: "weight")
    }

    // MARK: - Data Size Detection

    private func detectDataSize(_ input: String) -> CalculatorResult? {
        let units: [(pattern: String, toBase: Double, name: String, symbol: String)] = [
            ("terabytes?|tb", 1e12, "terabytes", "TB"),
            ("gigabytes?|gb", 1e9, "gigabytes", "GB"),
            ("megabytes?|mb", 1e6, "megabytes", "MB"),
            ("kilobytes?|kb", 1e3, "kilobytes", "KB"),
            ("bytes?|b(?!ytes)", 1.0, "bytes", "B")
        ]

        return detectUnitConversion(input: input, units: units, category: "data")
    }

    // MARK: - Time Detection

    private func detectTime(_ input: String) -> CalculatorResult? {
        let units: [(pattern: String, toBase: Double, name: String, symbol: String)] = [
            ("hours?|hrs?", 3600.0, "hours", "hr"),
            ("minutes?|mins?", 60.0, "minutes", "min"),
            ("seconds?|secs?", 1.0, "seconds", "sec"),
            ("days?", 86400.0, "days", "days"),
            ("weeks?", 604800.0, "weeks", "weeks")
        ]

        return detectUnitConversion(input: input, units: units, category: "time")
    }

    // MARK: - Generic Unit Conversion

    private func detectUnitConversion(
        input: String,
        units: [(pattern: String, toBase: Double, name: String, symbol: String)],
        category: String
    ) -> CalculatorResult? {

        // Build pattern to match "X unit1 to/in unit2"
        for fromUnit in units {
            for toUnit in units where fromUnit.symbol != toUnit.symbol {
                let pattern = #"(\d+(?:\.\d+)?)\s*(?:\#(fromUnit.pattern))\s+(?:to|in|=)\s*(?:\#(toUnit.pattern))"#

                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                   let match = regex.firstMatch(in: input, range: NSRange(input.startIndex..., in: input)) {

                    if let valueRange = Range(match.range(at: 1), in: input),
                       let value = Double(input[valueRange]) {

                        // Convert: value -> base unit -> target unit
                        let inBaseUnit = value * fromUnit.toBase
                        let result = inBaseUnit / toUnit.toBase

                        return CalculatorResult(
                            query: "\(formatNumber(value)) \(fromUnit.symbol) to \(toUnit.symbol)",
                            answer: "\(formatNumber(result)) \(toUnit.symbol)",
                            formattedResponse: "\(formatNumber(value)) \(fromUnit.name) = \(formatNumber(result)) \(toUnit.name)"
                        )
                    }
                }
            }
        }

        return nil
    }

    // MARK: - Math Expression Detection

    private func detectMathExpression(_ input: String) -> CalculatorResult? {
        // Clean the input for math evaluation
        let expr = input
            .replacingOccurrences(of: "x", with: "*")
            .replacingOccurrences(of: "×", with: "*")
            .replacingOccurrences(of: "÷", with: "/")
            .replacingOccurrences(of: "^", with: "**")
            .replacingOccurrences(of: "what is ", with: "")
            .replacingOccurrences(of: "what's ", with: "")
            .replacingOccurrences(of: "calculate ", with: "")
            .replacingOccurrences(of: "=", with: "")
            .replacingOccurrences(of: "?", with: "")
            .trimmingCharacters(in: .whitespaces)

        // Handle sqrt
        if let sqrtResult = handleSqrt(expr) {
            return sqrtResult
        }

        // Check if it looks like a math expression
        let mathPattern = #"^[\d\s\+\-\*\/\.\(\)]+$"#
        guard let regex = try? NSRegularExpression(pattern: mathPattern),
              regex.firstMatch(in: expr, range: NSRange(expr.startIndex..., in: expr)) != nil else {
            return nil
        }

        // Must contain at least one operator
        let hasOperator = expr.contains("+") || expr.contains("-") || expr.contains("*") || expr.contains("/")
        guard hasOperator else { return nil }

        // Must NOT end with an operator (incomplete expression)
        let trimmedExpr = expr.trimmingCharacters(in: .whitespaces)
        if let lastChar = trimmedExpr.last,
           ["+", "-", "*", "/", "("].contains(String(lastChar)) {
            return nil
        }

        // Must NOT start with an operator (except minus for negative numbers)
        if let firstChar = trimmedExpr.first,
           ["+", "*", "/", ")"].contains(String(firstChar)) {
            return nil
        }

        // Check for balanced parentheses
        let openCount = trimmedExpr.filter { $0 == "(" }.count
        let closeCount = trimmedExpr.filter { $0 == ")" }.count
        guard openCount == closeCount else { return nil }

        // Use NSExpression for safe evaluation
        let expression = NSExpression(format: expr)
        if let result = expression.expressionValue(with: nil, context: nil) as? NSNumber {
            let doubleResult = result.doubleValue
            return CalculatorResult(
                query: input,
                answer: formatNumber(doubleResult),
                formattedResponse: "\(input.trimmingCharacters(in: .whitespaces)) = \(formatNumber(doubleResult))"
            )
        }

        return nil
    }

    private func handleSqrt(_ input: String) -> CalculatorResult? {
        // Pattern: "sqrt(144)", "sqrt 144", "square root of 144"
        let patterns = [
            #"sqrt\s*\(?\s*(\d+(?:\.\d+)?)\s*\)?"#,
            #"square\s+root\s+(?:of\s+)?(\d+(?:\.\d+)?)"#
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: input, range: NSRange(input.startIndex..., in: input)) {

                if let valueRange = Range(match.range(at: 1), in: input),
                   let value = Double(input[valueRange]) {

                    let result = sqrt(value)
                    return CalculatorResult(
                        query: input,
                        answer: formatNumber(result),
                        formattedResponse: "√\(formatNumber(value)) = \(formatNumber(result))"
                    )
                }
            }
        }
        return nil
    }

    // MARK: - Formatting Helpers

    private func formatNumber(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 && abs(value) < 1e10 {
            return String(format: "%.0f", value)
        } else if abs(value) < 0.01 || abs(value) >= 1e6 {
            return String(format: "%.2e", value)
        } else {
            // Round to reasonable precision
            let formatted = String(format: "%.4f", value)
            // Remove trailing zeros
            return formatted.replacingOccurrences(of: #"\.?0+$"#, with: "", options: .regularExpression)
        }
    }

    private func formatCurrency(_ value: Double) -> String {
        return String(format: "$%.2f", value)
    }
}
