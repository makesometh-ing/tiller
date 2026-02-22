//
//  ConfigValidation.swift
//  Tiller
//

import Foundation

enum ConfigValidationError: Error, Equatable, Sendable {
    case marginOutOfRange(Int)
    case paddingOutOfRange(Int)
    case accordionOffsetOutOfRange(Int)
    case leaderTimeoutOutOfRange(Double)

    var description: String {
        switch self {
        case .marginOutOfRange(let value):
            return "Margin value \(value) is out of range (0-20)"
        case .paddingOutOfRange(let value):
            return "Padding value \(value) is out of range (0-20)"
        case .accordionOffsetOutOfRange(let value):
            return "Accordion offset value \(value) is out of range (4-24)"
        case .leaderTimeoutOutOfRange(let value):
            return "Leader timeout value \(value) is out of range (0-30)"
        }
    }
}

struct ConfigValidator {
    static func validate(_ config: TillerConfig) -> [ConfigValidationError] {
        var errors: [ConfigValidationError] = []

        if !TillerConfig.ValidationRange.margin.contains(config.margin) {
            errors.append(.marginOutOfRange(config.margin))
        }

        if !TillerConfig.ValidationRange.padding.contains(config.padding) {
            errors.append(.paddingOutOfRange(config.padding))
        }

        if !TillerConfig.ValidationRange.accordionOffset.contains(config.accordionOffset) {
            errors.append(.accordionOffsetOutOfRange(config.accordionOffset))
        }

        if !TillerConfig.ValidationRange.leaderTimeout.contains(config.leaderTimeout) {
            errors.append(.leaderTimeoutOutOfRange(config.leaderTimeout))
        }

        return errors
    }

    static func isValid(_ config: TillerConfig) -> Bool {
        return validate(config).isEmpty
    }
}
